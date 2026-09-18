import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/models.dart';
import 'package:sync_notes/data/remote/remote_api.dart';

/// 纯内存的本地库，行为和 SQLite 实现保持一致，用来跑同步引擎的分支测试。
class FakeLocalStore implements LocalStore {
  final Map<String, LocalNote> notes = {};
  DateTime? lastPulledAt;
  String device = 'test-device';

  @override
  Stream<List<LocalNote>> watchVisibleNotes() async* {
    yield _visible();
  }

  List<LocalNote> _visible() {
    final list = notes.values.where((n) => !n.isDeleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<LocalNote?> findById(String id) async => notes[id];

  @override
  Future<List<LocalNote>> pendingNotes() async {
    final list = notes.values.where((n) => n.dirty).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<int> pendingCount() async =>
      notes.values.where((n) => n.dirty).length;

  @override
  Future<DateTime?> getLastPulledAt() async => lastPulledAt;

  @override
  Future<void> setLastPulledAt(DateTime value) async => lastPulledAt = value;

  @override
  Future<String> deviceId() async => device;

  @override
  Future<void> createNote(LocalNote note) async => notes[note.id] = note;

  @override
  Future<void> updateBody({
    required String id,
    required String body,
    required DateTime now,
  }) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(body: body, updatedAt: now, dirty: true);
  }

  @override
  Future<void> softDelete({
    required String id,
    required DateTime now,
  }) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(
      deletedAt: now,
      updatedAt: now,
      dirty: true,
    );
  }

  @override
  Future<void> applyRemote(RemoteNote note) async {
    final existing = notes[note.id];
    // 与 drift 实现一致：过期快照直接丢弃。
    if (existing != null && note.version <= existing.baseVersion) return;

    notes[note.id] = LocalNote(
      id: note.id,
      body: note.body,
      version: note.version,
      baseVersion: note.version,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      serverUpdatedAt: note.updatedAt,
      deletedAt: note.deletedAt,
      dirty: false,
      isNew: false,
      lastDeviceId: note.lastDeviceId,
    );
  }

  @override
  Future<void> hardDelete(String id) async => notes.remove(id);
}

/// 内存版远端。时间戳用单调递增的假时钟，避免测试依赖真实时间。
class FakeRemoteApi implements RemoteApi {
  final Map<String, RemoteNote> notes = {};
  final List<String> updateAttempts = [];
  bool offline = false;

  DateTime _clock = DateTime.utc(2026, 1, 1, 0, 0, 0);

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  void seed(RemoteNote note) => notes[note.id] = note;

  void _guard() {
    if (offline) throw const RemoteApiException('模拟断网');
  }

  @override
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since) async {
    _guard();
    final list = notes.values
        .where(
          (n) =>
              since == null ||
              n.updatedAt.isAfter(since) ||
              n.updatedAt.isAtSameMomentAs(since),
        )
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<RemoteNote?> fetchById(String id) async {
    _guard();
    return notes[id];
  }

  @override
  Future<RemoteNote> insert({
    required String id,
    required String body,
    String? lastDeviceId,
  }) async {
    _guard();
    final existing = notes[id];
    final note = RemoteNote(
      id: id,
      body: body,
      version: existing?.version ?? 1,
      createdAt: existing?.createdAt ?? _tick(),
      updatedAt: _tick(),
      deletedAt: existing?.deletedAt,
      lastDeviceId: lastDeviceId,
    );
    notes[id] = note;
    return note;
  }

  @override
  Future<RemoteNote?> updateIfVersion({
    required String id,
    required String body,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    _guard();
    updateAttempts.add(id);
    final existing = notes[id];
    if (existing == null) return null;
    if (existing.version != expectedVersion) return null;

    final note = RemoteNote(
      id: id,
      body: body,
      version: expectedVersion + 1,
      createdAt: existing.createdAt,
      updatedAt: _tick(),
      deletedAt: deletedAt,
      lastDeviceId: lastDeviceId,
    );
    notes[id] = note;
    return note;
  }

  @override
  Stream<RemoteNote> watchChanges() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

RemoteNote remoteNote({
  required String id,
  required String body,
  int version = 1,
  DateTime? updatedAt,
  DateTime? deletedAt,
  String? lastDeviceId,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return RemoteNote(
    id: id,
    body: body,
    version: version,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    lastDeviceId: lastDeviceId,
  );
}

LocalNote localNote({
  required String id,
  required String body,
  int version = 1,
  int baseVersion = 0,
  DateTime? updatedAt,
  DateTime? deletedAt,
  bool dirty = true,
  bool isNew = false,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return LocalNote(
    id: id,
    body: body,
    version: version,
    baseVersion: baseVersion,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    dirty: dirty,
    isNew: isNew,
  );
}
