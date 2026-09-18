import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'database.dart';
import 'local_store.dart';

/// SQLite 实现。界面层只通过这个类读写本地数据，不直接接触网络。
class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  static const _keyDeviceId = 'device_id';
  static const _keyLastPulledAt = 'last_pulled_at';

  final AppDatabase _db;
  String? _cachedDeviceId;

  @override
  Stream<List<LocalNote>> watchVisibleNotes() {
    final query = _db.select(_db.notes)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toLocal).toList());
  }

  @override
  Future<LocalNote?> findById(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toLocal(row);
  }

  @override
  Future<List<LocalNote>> pendingNotes() async {
    final query = _db.select(_db.notes)
      ..where((t) => t.dirty.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_toLocal).toList();
  }

  @override
  Future<int> pendingCount() async {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([count])
      ..where(_db.notes.dirty.equals(true));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<DateTime?> getLastPulledAt() async {
    final value = await _getMeta(_keyLastPulledAt);
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  @override
  Future<void> setLastPulledAt(DateTime value) =>
      _setMeta(_keyLastPulledAt, value.toUtc().toIso8601String());

  @override
  Future<String> deviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) return cached;
    var value = await _getMeta(_keyDeviceId);
    if (value == null) {
      value = const Uuid().v4();
      await _setMeta(_keyDeviceId, value);
    }
    return _cachedDeviceId = value;
  }

  @override
  Future<void> createNote(LocalNote note) async {
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: note.id,
            body: Value(note.body),
            version: Value(note.version),
            baseVersion: Value(note.baseVersion),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            serverUpdatedAt: Value(note.serverUpdatedAt),
            deletedAt: Value(note.deletedAt),
            dirty: Value(note.dirty),
            isNew: Value(note.isNew),
            lastDeviceId: Value(note.lastDeviceId),
          ),
        );
  }

  @override
  Future<void> updateBody({
    required String id,
    required String body,
    required DateTime now,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        body: Value(body),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> softDelete({required String id, required DateTime now}) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> applyRemote(RemoteNote note) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.notes,
      )..where((t) => t.id.equals(note.id))).getSingleOrNull();
      // 实时通道可能乱序投递，收到的是过期快照就丢掉，别把本地回退。
      if (existing != null && note.version <= existing.baseVersion) return;

      await _db
          .into(_db.notes)
          .insertOnConflictUpdate(
            NotesCompanion(
              id: Value(note.id),
              body: Value(note.body),
              version: Value(note.version),
              baseVersion: Value(note.version),
              createdAt: Value(note.createdAt),
              updatedAt: Value(note.updatedAt),
              serverUpdatedAt: Value(note.updatedAt),
              deletedAt: Value(note.deletedAt),
              dirty: const Value(false),
              isNew: const Value(false),
              lastDeviceId: Value(note.lastDeviceId),
            ),
          );
    });
  }

  @override
  Future<void> hardDelete(String id) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  Future<String?> _getMeta(String key) async {
    final row = await (_db.select(
      _db.syncMetaEntries,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) async {
    await _db
        .into(_db.syncMetaEntries)
        .insertOnConflictUpdate(
          SyncMetaEntriesCompanion(
            key: Value(key),
            value: Value(value),
          ),
        );
  }

  LocalNote _toLocal(Note row) => LocalNote(
    id: row.id,
    body: row.body,
    version: row.version,
    baseVersion: row.baseVersion,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    serverUpdatedAt: row.serverUpdatedAt,
    deletedAt: row.deletedAt,
    dirty: row.dirty,
    isNew: row.isNew,
    lastDeviceId: row.lastDeviceId,
  );
}
