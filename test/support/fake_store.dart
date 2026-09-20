import 'dart:async';

import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/models.dart';
import 'package:sync_notes/data/remote/remote_api.dart';

/// 纯内存的本地库，行为和 SQLite 实现保持一致，用来跑同步引擎的分支测试。
class FakeLocalStore implements LocalStore {
  final Map<String, LocalNote> notes = {};
  final Map<String, LocalFolder> folders = {};
  final Map<String, LocalImage> images = {};
  final Map<String, LocalInk> inks = {};

  /// 图片文件本体，键是图片 id。
  final Map<String, List<int>> files = {};

  /// 指向本机真实图片文件的路径，截图工具用它渲染真图。
  final Map<String, String> imageRealPaths = {};

  DateTime? notesPulledAt;
  DateTime? foldersPulledAt;
  DateTime? imagesPulledAt;
  DateTime? inksPulledAt;
  String device = 'test-device';

  // drift 的 watch() 会在数据变化时重新推送，这里用两个广播流模拟同样的行为，
  // 否则界面测试里改了数据界面不会跟着更新。
  final StreamController<void> _noteChanges =
      StreamController<void>.broadcast();
  final StreamController<void> _folderChanges =
      StreamController<void>.broadcast();

  void _touchNotes() {
    if (!_noteChanges.isClosed) _noteChanges.add(null);
  }

  void _touchFolders() {
    if (!_folderChanges.isClosed) _folderChanges.add(null);
  }

  @override
  Stream<List<LocalNote>> watchVisibleNotes() async* {
    yield await allVisibleNotes();
    await for (final _ in _noteChanges.stream) {
      yield await allVisibleNotes();
    }
  }

  @override
  Future<List<LocalNote>> allVisibleNotes() async {
    final list = notes.values.where((n) => !n.isDeleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<LocalNote?> findById(String id) async => notes[id];

  @override
  Stream<List<LocalFolder>> watchVisibleFolders() async* {
    yield _visibleFolders();
    await for (final _ in _folderChanges.stream) {
      yield _visibleFolders();
    }
  }

  List<LocalFolder> _visibleFolders() =>
      folders.values.where((f) => !f.isDeleted).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<LocalFolder?> findFolderById(String id) async => folders[id];

  @override
  Future<List<LocalNote>> pendingNotes() async {
    final list = notes.values.where((n) => n.dirty).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<List<LocalFolder>> pendingFolders() async {
    final list = folders.values.where((f) => f.dirty).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<List<LocalImage>> pendingImages() async {
    final list = images.values.where((i) => i.dirty).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<LocalImage>> allImages() async =>
      images.values.where((i) => !i.isDeleted).toList();

  @override
  Future<List<LocalImage>> deletedImages() async =>
      images.values.where((i) => i.isDeleted).toList();

  @override
  Future<LocalImage?> findImageById(String id) async => images[id];

  @override
  Future<LocalInk?> findInkById(String id) async => inks[id];

  @override
  Future<List<LocalInk>> pendingInks() async {
    final list = inks.values.where((i) => i.dirty).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<List<LocalInk>> allInks() async =>
      inks.values.where((i) => !i.isDeleted).toList();

  @override
  Future<List<LocalInk>> deletedInks() async =>
      inks.values.where((i) => i.isDeleted).toList();

  @override
  Future<void> createInk(LocalInk ink) async => inks[ink.id] = ink;

  @override
  Future<void> updateInk({
    required String id,
    required String strokes,
    required int canvasWidth,
    required int canvasHeight,
    required DateTime now,
  }) async {
    final ink = inks[id]!;
    inks[id] = LocalInk(
      id: ink.id,
      strokes: strokes,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      version: ink.version,
      baseVersion: ink.baseVersion,
      createdAt: ink.createdAt,
      updatedAt: now,
      serverUpdatedAt: ink.serverUpdatedAt,
      deletedAt: ink.deletedAt,
      dirty: true,
      isNew: ink.isNew,
      lastDeviceId: ink.lastDeviceId,
    );
  }

  @override
  Future<void> softDeleteInk({
    required String id,
    required DateTime now,
  }) async {
    final ink = inks[id]!;
    inks[id] = ink.copyWith(deletedAt: now, updatedAt: now, dirty: true);
  }

  @override
  Future<DateTime?> getInksPulledAt() async => inksPulledAt;

  @override
  Future<void> setInksPulledAt(DateTime value) async => inksPulledAt = value;

  @override
  Future<void> applyRemoteInk(RemoteInk ink) async {
    final existing = inks[ink.id];
    if (existing != null && ink.version <= existing.baseVersion) return;

    inks[ink.id] = LocalInk(
      id: ink.id,
      strokes: ink.strokes,
      canvasWidth: ink.canvasWidth,
      canvasHeight: ink.canvasHeight,
      version: ink.version,
      baseVersion: ink.version,
      createdAt: ink.createdAt,
      updatedAt: ink.updatedAt,
      serverUpdatedAt: ink.updatedAt,
      deletedAt: ink.deletedAt,
      dirty: false,
      isNew: false,
      lastDeviceId: ink.lastDeviceId,
    );
  }

  @override
  Future<void> hardDeleteInk(String id) async => inks.remove(id);

  @override
  Future<int> pendingCount() async =>
      notes.values.where((n) => n.dirty).length +
      folders.values.where((f) => f.dirty).length +
      images.values.where((i) => i.dirty).length +
      inks.values.where((i) => i.dirty).length;

  @override
  Future<DateTime?> getLastPulledAt() async => notesPulledAt;

  @override
  Future<void> setLastPulledAt(DateTime value) async => notesPulledAt = value;

  @override
  Future<DateTime?> getFoldersPulledAt() async => foldersPulledAt;

  @override
  Future<void> setFoldersPulledAt(DateTime value) async =>
      foldersPulledAt = value;

  @override
  Future<DateTime?> getImagesPulledAt() async => imagesPulledAt;

  @override
  Future<void> setImagesPulledAt(DateTime value) async =>
      imagesPulledAt = value;

  @override
  Future<String> deviceId() async => device;

  @override
  Future<void> createNote(LocalNote note) async {
    notes[note.id] = note;
    _touchNotes();
  }

  @override
  Future<void> updateBody({
    required String id,
    required String body,
    required DateTime now,
  }) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(body: body, updatedAt: now, dirty: true);
    _touchNotes();
  }

  @override
  Future<void> softDelete({required String id, required DateTime now}) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(deletedAt: now, updatedAt: now, dirty: true);
    _touchNotes();
  }

  @override
  Future<void> restore({required String id, required DateTime now}) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(
      clearDeletedAt: true,
      updatedAt: now,
      dirty: true,
    );
    _touchNotes();
  }

  @override
  Future<void> setNoteFolder({
    required String id,
    required String? folderId,
    required DateTime now,
  }) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(
      folderId: folderId,
      clearFolderId: folderId == null,
      updatedAt: now,
      dirty: true,
    );
    _touchNotes();
  }

  @override
  Future<void> setNoteLock({
    required String id,
    required bool locked,
    required String? hash,
    required String? salt,
    required DateTime now,
  }) async {
    final note = notes[id]!;
    notes[id] = note.copyWith(
      locked: locked,
      passphraseHash: hash,
      passphraseSalt: salt,
      clearPassphrase: !locked,
      updatedAt: now,
      dirty: true,
    );
    _touchNotes();
  }

  @override
  Future<void> createFolder(LocalFolder folder) async {
    folders[folder.id] = folder;
    _touchFolders();
  }

  @override
  Future<void> renameFolder({
    required String id,
    required String name,
    required DateTime now,
  }) async {
    final folder = folders[id]!;
    folders[id] = folder.copyWith(name: name, updatedAt: now, dirty: true);
    _touchFolders();
  }

  @override
  Future<void> softDeleteFolder({
    required String id,
    required DateTime now,
  }) async {
    // 与 SQLite 实现一致：目录里的笔记先回到未分类。
    for (final note in notes.values.where((n) => n.folderId == id).toList()) {
      notes[note.id] = note.copyWith(
        clearFolderId: true,
        updatedAt: now,
        dirty: true,
      );
    }
    final folder = folders[id]!;
    folders[id] = folder.copyWith(deletedAt: now, updatedAt: now, dirty: true);
    _touchNotes();
    _touchFolders();
  }

  @override
  Future<void> createImage(LocalImage image) async => images[image.id] = image;

  @override
  Future<void> softDeleteImage({
    required String id,
    required DateTime now,
  }) async {
    final image = images[id]!;
    images[id] = image.copyWith(deletedAt: now, updatedAt: now, dirty: true);
  }

  @override
  Future<String> imageFilePath(String id) async =>
      imageRealPaths[id] ?? '/fake/images/$id.jpg';

  @override
  Future<bool> imageFileExists(String id) async =>
      files.containsKey(id) || imageRealPaths.containsKey(id);

  @override
  Future<void> writeImageFile(String id, List<int> bytes) async =>
      files[id] = List<int>.from(bytes);

  @override
  Future<List<int>?> readImageFile(String id) async => files[id];

  @override
  Future<void> deleteImageFile(String id) async => files.remove(id);

  @override
  Future<void> applyRemote(RemoteNote note) async {
    final existing = notes[note.id];
    // 与 drift 实现一致：过期快照直接丢弃。
    if (existing != null && note.version <= existing.baseVersion) return;

    notes[note.id] = LocalNote(
      id: note.id,
      body: note.body,
      folderId: note.folderId,
      locked: note.locked,
      passphraseHash: note.passphraseHash,
      passphraseSalt: note.passphraseSalt,
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
    _touchNotes();
  }

  @override
  Future<void> applyRemoteFolder(RemoteFolder folder) async {
    final existing = folders[folder.id];
    if (existing != null && folder.version <= existing.baseVersion) return;

    folders[folder.id] = LocalFolder(
      id: folder.id,
      name: folder.name,
      version: folder.version,
      baseVersion: folder.version,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      serverUpdatedAt: folder.updatedAt,
      deletedAt: folder.deletedAt,
      dirty: false,
      isNew: false,
      lastDeviceId: folder.lastDeviceId,
    );
    _touchFolders();
  }

  @override
  Future<void> applyRemoteImage(RemoteImage image) async {
    images[image.id] = LocalImage(
      id: image.id,
      storagePath: image.storagePath,
      byteSize: image.byteSize,
      width: image.width,
      height: image.height,
      createdAt: image.createdAt,
      updatedAt: image.updatedAt,
      deletedAt: image.deletedAt,
      dirty: false,
    );
  }

  @override
  Future<void> hardDelete(String id) async {
    notes.remove(id);
    _touchNotes();
  }

  @override
  Future<void> hardDeleteFolder(String id) async {
    folders.remove(id);
    _touchFolders();
  }

  @override
  Future<void> hardDeleteImage(String id) async => images.remove(id);
}

/// 内存版远端。时间戳用单调递增的假时钟，避免测试依赖真实时间。
class FakeRemoteApi implements RemoteApi {
  final Map<String, RemoteNote> notes = {};
  final Map<String, RemoteFolder> folders = {};
  final Map<String, RemoteImage> images = {};
  final Map<String, RemoteInk> inks = {};

  /// 存储桶里的对象，键是 storage_path。
  final Map<String, List<int>> storage = {};

  final List<String> updateAttempts = [];
  bool offline = false;

  DateTime _clock = DateTime.utc(2026, 1, 1, 0, 0, 0);

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  void seed(RemoteNote note) => notes[note.id] = note;

  void seedFolder(RemoteFolder folder) => folders[folder.id] = folder;

  void seedInk(RemoteInk ink) => inks[ink.id] = ink;

  void _guard() {
    if (offline) throw const RemoteApiException('模拟断网');
  }

  bool _changed(DateTime updatedAt, DateTime? since) =>
      since == null ||
      updatedAt.isAfter(since) ||
      updatedAt.isAtSameMomentAs(since);

  @override
  Future<List<RemoteNote>> fetchChangedSince(DateTime? since) async {
    _guard();
    final list =
        notes.values.where((n) => _changed(n.updatedAt, since)).toList()
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
    required NotePayload payload,
    String? lastDeviceId,
  }) async {
    _guard();
    final existing = notes[id];
    final note = RemoteNote(
      id: id,
      body: payload.body,
      version: existing?.version ?? 1,
      createdAt: existing?.createdAt ?? _tick(),
      updatedAt: _tick(),
      folderId: payload.folderId,
      locked: payload.locked,
      passphraseHash: payload.passphraseHash,
      passphraseSalt: payload.passphraseSalt,
      deletedAt: existing?.deletedAt,
      lastDeviceId: lastDeviceId,
    );
    notes[id] = note;
    return note;
  }

  @override
  Future<RemoteNote?> updateIfVersion({
    required String id,
    required NotePayload payload,
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
      body: payload.body,
      version: expectedVersion + 1,
      createdAt: existing.createdAt,
      updatedAt: _tick(),
      folderId: payload.folderId,
      locked: payload.locked,
      passphraseHash: payload.passphraseHash,
      passphraseSalt: payload.passphraseSalt,
      deletedAt: deletedAt,
      lastDeviceId: lastDeviceId,
    );
    notes[id] = note;
    return note;
  }

  @override
  Future<List<RemoteFolder>> fetchFoldersChangedSince(DateTime? since) async {
    _guard();
    final list =
        folders.values.where((f) => _changed(f.updatedAt, since)).toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<RemoteFolder?> fetchFolderById(String id) async {
    _guard();
    return folders[id];
  }

  @override
  Future<RemoteFolder> insertFolder({
    required String id,
    required String name,
    String? lastDeviceId,
  }) async {
    _guard();
    final existing = folders[id];
    final folder = RemoteFolder(
      id: id,
      name: name,
      version: existing?.version ?? 1,
      createdAt: existing?.createdAt ?? _tick(),
      updatedAt: _tick(),
      deletedAt: existing?.deletedAt,
      lastDeviceId: lastDeviceId,
    );
    folders[id] = folder;
    return folder;
  }

  @override
  Future<RemoteFolder?> updateFolderIfVersion({
    required String id,
    required String name,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    _guard();
    final existing = folders[id];
    if (existing == null) return null;
    if (existing.version != expectedVersion) return null;

    final folder = RemoteFolder(
      id: id,
      name: name,
      version: expectedVersion + 1,
      createdAt: existing.createdAt,
      updatedAt: _tick(),
      deletedAt: deletedAt,
      lastDeviceId: lastDeviceId,
    );
    folders[id] = folder;
    return folder;
  }

  @override
  Future<List<RemoteImage>> fetchImagesChangedSince(DateTime? since) async {
    _guard();
    final list =
        images.values.where((i) => _changed(i.updatedAt, since)).toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<RemoteImage> upsertImage({
    required String id,
    required String storagePath,
    required int byteSize,
    int? width,
    int? height,
    DateTime? deletedAt,
  }) async {
    _guard();
    final existing = images[id];
    final image = RemoteImage(
      id: id,
      storagePath: storagePath,
      byteSize: byteSize,
      width: width ?? existing?.width,
      height: height ?? existing?.height,
      createdAt: existing?.createdAt ?? _tick(),
      updatedAt: _tick(),
      deletedAt: deletedAt,
    );
    images[id] = image;
    return image;
  }

  @override
  Future<void> uploadImage(String storagePath, List<int> bytes) async {
    _guard();
    storage[storagePath] = List<int>.from(bytes);
  }

  @override
  Future<List<int>> downloadImage(String storagePath) async {
    _guard();
    final bytes = storage[storagePath];
    if (bytes == null) {
      throw RemoteApiException('存储桶里没有 $storagePath');
    }
    return bytes;
  }

  @override
  Future<void> deleteImageObject(String storagePath) async {
    _guard();
    storage.remove(storagePath);
  }

  @override
  Future<List<RemoteInk>> fetchInksChangedSince(DateTime? since) async {
    _guard();
    final list = inks.values.where((i) => _changed(i.updatedAt, since)).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  @override
  Future<RemoteInk?> fetchInkById(String id) async {
    _guard();
    return inks[id];
  }

  @override
  Future<RemoteInk> insertInk({
    required String id,
    required String strokes,
    required int canvasWidth,
    required int canvasHeight,
    String? lastDeviceId,
  }) async {
    _guard();
    final existing = inks[id];
    final ink = RemoteInk(
      id: id,
      strokes: strokes,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      version: existing?.version ?? 1,
      createdAt: existing?.createdAt ?? _tick(),
      updatedAt: _tick(),
      deletedAt: existing?.deletedAt,
      lastDeviceId: lastDeviceId,
    );
    inks[id] = ink;
    return ink;
  }

  @override
  Future<RemoteInk?> updateInkIfVersion({
    required String id,
    required String strokes,
    required int canvasWidth,
    required int canvasHeight,
    required int expectedVersion,
    required String lastDeviceId,
    DateTime? deletedAt,
  }) async {
    _guard();
    final existing = inks[id];
    if (existing == null) return null;
    if (existing.version != expectedVersion) return null;

    final ink = RemoteInk(
      id: id,
      strokes: strokes,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      version: expectedVersion + 1,
      createdAt: existing.createdAt,
      updatedAt: _tick(),
      deletedAt: deletedAt,
      lastDeviceId: lastDeviceId,
    );
    inks[id] = ink;
    return ink;
  }

  @override
  Stream<RemoteNote> watchChanges() => const Stream.empty();

  @override
  Stream<RemoteFolder> watchFolderChanges() => const Stream.empty();

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
  String? folderId,
  bool locked = false,
  String? passphraseHash,
  String? passphraseSalt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return RemoteNote(
    id: id,
    body: body,
    version: version,
    createdAt: at,
    updatedAt: at,
    folderId: folderId,
    locked: locked,
    passphraseHash: passphraseHash,
    passphraseSalt: passphraseSalt,
    deletedAt: deletedAt,
    lastDeviceId: lastDeviceId,
  );
}

RemoteFolder remoteFolder({
  required String id,
  required String name,
  int version = 1,
  DateTime? updatedAt,
  DateTime? deletedAt,
  String? lastDeviceId,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return RemoteFolder(
    id: id,
    name: name,
    version: version,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    lastDeviceId: lastDeviceId,
  );
}

RemoteImage remoteImageRecord({
  required String id,
  required String storagePath,
  int byteSize = 0,
  int? width,
  int? height,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return RemoteImage(
    id: id,
    storagePath: storagePath,
    byteSize: byteSize,
    width: width,
    height: height,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
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
  String? folderId,
  bool locked = false,
  String? passphraseHash,
  String? passphraseSalt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return LocalNote(
    id: id,
    body: body,
    version: version,
    baseVersion: baseVersion,
    createdAt: at,
    updatedAt: at,
    folderId: folderId,
    locked: locked,
    passphraseHash: passphraseHash,
    passphraseSalt: passphraseSalt,
    deletedAt: deletedAt,
    dirty: dirty,
    isNew: isNew,
  );
}

LocalFolder localFolder({
  required String id,
  required String name,
  int version = 1,
  int baseVersion = 0,
  DateTime? updatedAt,
  DateTime? deletedAt,
  bool dirty = true,
  bool isNew = false,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return LocalFolder(
    id: id,
    name: name,
    version: version,
    baseVersion: baseVersion,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    dirty: dirty,
    isNew: isNew,
  );
}

LocalImage localImage({
  required String id,
  String? storagePath,
  int byteSize = 1024,
  DateTime? createdAt,
  DateTime? deletedAt,
  bool dirty = true,
}) {
  final at = createdAt ?? DateTime.utc(2026, 1, 1);
  return LocalImage(
    id: id,
    storagePath: storagePath ?? 'user/$id.jpg',
    byteSize: byteSize,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

RemoteInk remoteInk({
  required String id,
  String strokes = '[]',
  int version = 1,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return RemoteInk(
    id: id,
    strokes: strokes,
    canvasWidth: 1000,
    canvasHeight: 1400,
    version: version,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
  );
}

LocalInk localInk({
  required String id,
  String strokes = '[]',
  int version = 1,
  int baseVersion = 0,
  DateTime? createdAt,
  DateTime? deletedAt,
  bool dirty = true,
  bool isNew = false,
}) {
  final at = createdAt ?? DateTime.utc(2026, 1, 1);
  return LocalInk(
    id: id,
    strokes: strokes,
    version: version,
    baseVersion: baseVersion,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    dirty: dirty,
    isNew: isNew,
  );
}
