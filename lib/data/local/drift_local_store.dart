import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'database.dart';
import 'local_store.dart';

/// SQLite 实现。界面层只通过这个类读写本地数据，不直接接触网络。
class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  static const _keyDeviceId = 'device_id';
  static const _keyNotesPulledAt = 'last_pulled_at';
  static const _keyFoldersPulledAt = 'last_pulled_folders_at';
  static const _keyImagesPulledAt = 'last_pulled_images_at';
  static const _keyInksPulledAt = 'last_pulled_inks_at';

  final AppDatabase _db;
  String? _cachedDeviceId;
  Future<Directory>? _imageDir;

  // ---------------------------------------------------------------------
  // 笔记读取
  // ---------------------------------------------------------------------

  @override
  Stream<List<LocalNote>> watchVisibleNotes() {
    final query = _db.select(_db.notes)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toLocal).toList());
  }

  @override
  Future<List<LocalNote>> allVisibleNotes() async {
    final query = _db.select(_db.notes)..where((t) => t.deletedAt.isNull());
    final rows = await query.get();
    return rows.map(_toLocal).toList();
  }

  @override
  Future<LocalNote?> findById(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toLocal(row);
  }

  // ---------------------------------------------------------------------
  // 目录读取
  // ---------------------------------------------------------------------

  @override
  Stream<List<LocalFolder>> watchVisibleFolders() {
    final query = _db.select(_db.folders)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toLocalFolder).toList());
  }

  @override
  Future<LocalFolder?> findFolderById(String id) async {
    final row = await (_db.select(
      _db.folders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toLocalFolder(row);
  }

  // ---------------------------------------------------------------------
  // 本地编辑
  // ---------------------------------------------------------------------

  @override
  Future<void> createNote(LocalNote note) async {
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: note.id,
            body: Value(note.body),
            folderId: Value(note.folderId),
            pinned: Value(note.pinned),
            locked: Value(note.locked),
            passphraseHash: Value(note.passphraseHash),
            passphraseSalt: Value(note.passphraseSalt),
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
  Future<void> restore({required String id, required DateTime now}) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> setNoteFolder({
    required String id,
    required String? folderId,
    required DateTime now,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        folderId: Value(folderId),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> setNotePinned({
    required String id,
    required bool pinned,
  }) async {
    // 只写这一列：置顶是本机偏好，改了不该让笔记显得"更新过"，
    // 更不该被推到服务端。
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(pinned: Value(pinned)),
    );
  }

  @override
  Future<void> setNoteLock({
    required String id,
    required bool locked,
    required String? hash,
    required String? salt,
    required DateTime now,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        locked: Value(locked),
        passphraseHash: Value(hash),
        passphraseSalt: Value(salt),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> createFolder(LocalFolder folder) async {
    await _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(
            id: folder.id,
            name: Value(folder.name),
            version: Value(folder.version),
            baseVersion: Value(folder.baseVersion),
            createdAt: folder.createdAt,
            updatedAt: folder.updatedAt,
            serverUpdatedAt: Value(folder.serverUpdatedAt),
            deletedAt: Value(folder.deletedAt),
            dirty: Value(folder.dirty),
            isNew: Value(folder.isNew),
            lastDeviceId: Value(folder.lastDeviceId),
          ),
        );
  }

  @override
  Future<void> renameFolder({
    required String id,
    required String name,
    required DateTime now,
  }) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        name: Value(name),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> softDeleteFolder({
    required String id,
    required DateTime now,
  }) async {
    await _db.transaction(() async {
      // 目录删掉之后里面的笔记回到「未分类」，并且要标脏让另一端也同步到。
      await (_db.update(_db.notes)..where((t) => t.folderId.equals(id))).write(
        NotesCompanion(
          folderId: const Value(null),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
        FoldersCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  @override
  Future<void> createImage(LocalImage image) async {
    await _db
        .into(_db.noteImages)
        .insert(
          NoteImagesCompanion.insert(
            id: image.id,
            storagePath: image.storagePath,
            byteSize: Value(image.byteSize),
            width: Value(image.width),
            height: Value(image.height),
            createdAt: image.createdAt,
            updatedAt: image.updatedAt,
            deletedAt: Value(image.deletedAt),
            dirty: Value(image.dirty),
          ),
        );
  }

  @override
  Future<void> softDeleteImage({
    required String id,
    required DateTime now,
  }) async {
    await (_db.update(_db.noteImages)..where((t) => t.id.equals(id))).write(
      NoteImagesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 手写画布
  // ---------------------------------------------------------------------

  @override
  Future<LocalInk?> findInkById(String id) async {
    final row = await (_db.select(
      _db.noteInks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toLocalInk(row);
  }

  @override
  Future<List<LocalInk>> pendingInks() async {
    final query = _db.select(_db.noteInks)
      ..where((t) => t.dirty.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_toLocalInk).toList();
  }

  @override
  Future<List<LocalInk>> allInks() async {
    final query = _db.select(_db.noteInks)..where((t) => t.deletedAt.isNull());
    final rows = await query.get();
    return rows.map(_toLocalInk).toList();
  }

  @override
  Future<List<LocalInk>> deletedInks() async {
    final query = _db.select(_db.noteInks)
      ..where((t) => t.deletedAt.isNotNull());
    final rows = await query.get();
    return rows.map(_toLocalInk).toList();
  }

  @override
  Future<void> createInk(LocalInk ink) async {
    await _db
        .into(_db.noteInks)
        .insert(
          NoteInksCompanion.insert(
            id: ink.id,
            strokes: Value(ink.strokes),
            canvasWidth: Value(ink.canvasWidth),
            canvasHeight: Value(ink.canvasHeight),
            version: Value(ink.version),
            baseVersion: Value(ink.baseVersion),
            createdAt: ink.createdAt,
            updatedAt: ink.updatedAt,
            serverUpdatedAt: Value(ink.serverUpdatedAt),
            deletedAt: Value(ink.deletedAt),
            dirty: Value(ink.dirty),
            isNew: Value(ink.isNew),
            lastDeviceId: Value(ink.lastDeviceId),
          ),
        );
  }

  @override
  Future<void> updateInk({
    required String id,
    required String strokes,
    required int canvasWidth,
    required int canvasHeight,
    required DateTime now,
  }) async {
    await (_db.update(_db.noteInks)..where((t) => t.id.equals(id))).write(
      NoteInksCompanion(
        strokes: Value(strokes),
        canvasWidth: Value(canvasWidth),
        canvasHeight: Value(canvasHeight),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> softDeleteInk({
    required String id,
    required DateTime now,
  }) async {
    await (_db.update(_db.noteInks)..where((t) => t.id.equals(id))).write(
      NoteInksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  @override
  Future<DateTime?> getInksPulledAt() => _getTime(_keyInksPulledAt);

  @override
  Future<void> setInksPulledAt(DateTime value) =>
      _setTime(_keyInksPulledAt, value);

  @override
  Future<void> applyRemoteInk(RemoteInk ink) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.noteInks,
      )..where((t) => t.id.equals(ink.id))).getSingleOrNull();
      if (existing != null && ink.version <= existing.baseVersion) return;

      await _db
          .into(_db.noteInks)
          .insertOnConflictUpdate(
            NoteInksCompanion(
              id: Value(ink.id),
              strokes: Value(ink.strokes),
              canvasWidth: Value(ink.canvasWidth),
              canvasHeight: Value(ink.canvasHeight),
              version: Value(ink.version),
              baseVersion: Value(ink.version),
              createdAt: Value(ink.createdAt),
              updatedAt: Value(ink.updatedAt),
              serverUpdatedAt: Value(ink.updatedAt),
              deletedAt: Value(ink.deletedAt),
              dirty: const Value(false),
              isNew: const Value(false),
              lastDeviceId: Value(ink.lastDeviceId),
            ),
          );
    });
  }

  @override
  Future<void> hardDeleteInk(String id) async {
    await (_db.delete(_db.noteInks)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------
  // 待推送
  // ---------------------------------------------------------------------

  @override
  Future<List<LocalNote>> pendingNotes() async {
    final query = _db.select(_db.notes)
      ..where((t) => t.dirty.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_toLocal).toList();
  }

  @override
  Future<List<LocalFolder>> pendingFolders() async {
    final query = _db.select(_db.folders)
      ..where((t) => t.dirty.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_toLocalFolder).toList();
  }

  @override
  Future<List<LocalImage>> pendingImages() async {
    final query = _db.select(_db.noteImages)
      ..where((t) => t.dirty.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toLocalImage).toList();
  }

  @override
  Future<List<LocalImage>> allImages() async {
    final query = _db.select(_db.noteImages)
      ..where((t) => t.deletedAt.isNull());
    final rows = await query.get();
    return rows.map(_toLocalImage).toList();
  }

  @override
  Future<List<LocalImage>> deletedImages() async {
    final query = _db.select(_db.noteImages)
      ..where((t) => t.deletedAt.isNotNull());
    final rows = await query.get();
    return rows.map(_toLocalImage).toList();
  }

  @override
  Future<LocalImage?> findImageById(String id) async {
    final row = await (_db.select(
      _db.noteImages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toLocalImage(row);
  }

  // ---------------------------------------------------------------------
  // 图片文件本体
  // ---------------------------------------------------------------------

  Future<Directory> _imagesDirectory() {
    return _imageDir ??= () async {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'images'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }();
  }

  @override
  Future<String> imageFilePath(String id) async {
    final dir = await _imagesDirectory();
    return p.join(dir.path, '$id.jpg');
  }

  @override
  Future<bool> imageFileExists(String id) async {
    return File(await imageFilePath(id)).existsSync();
  }

  @override
  Future<void> writeImageFile(String id, List<int> bytes) async {
    final file = File(await imageFilePath(id));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> readImageFile(String id) async {
    final file = File(await imageFilePath(id));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> deleteImageFile(String id) async {
    final file = File(await imageFilePath(id));
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<int> pendingCount() async {
    Future<int> countDirty(TableInfo table, Column<bool> flag) async {
      final counter = table.$columns.first.count();
      final query = _db.selectOnly(table)
        ..addColumns([counter])
        ..where(flag.equals(true));
      final row = await query.getSingle();
      return row.read(counter) ?? 0;
    }

    return await countDirty(_db.notes, _db.notes.dirty) +
        await countDirty(_db.folders, _db.folders.dirty) +
        await countDirty(_db.noteImages, _db.noteImages.dirty) +
        await countDirty(_db.noteInks, _db.noteInks.dirty);
  }

  // ---------------------------------------------------------------------
  // 水位
  // ---------------------------------------------------------------------

  @override
  Future<DateTime?> getLastPulledAt() => _getTime(_keyNotesPulledAt);

  @override
  Future<void> setLastPulledAt(DateTime value) =>
      _setTime(_keyNotesPulledAt, value);

  @override
  Future<DateTime?> getFoldersPulledAt() => _getTime(_keyFoldersPulledAt);

  @override
  Future<void> setFoldersPulledAt(DateTime value) =>
      _setTime(_keyFoldersPulledAt, value);

  @override
  Future<DateTime?> getImagesPulledAt() => _getTime(_keyImagesPulledAt);

  @override
  Future<void> setImagesPulledAt(DateTime value) =>
      _setTime(_keyImagesPulledAt, value);

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

  // ---------------------------------------------------------------------
  // 同步回写
  // ---------------------------------------------------------------------

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
              folderId: Value(note.folderId),
              locked: Value(note.locked),
              passphraseHash: Value(note.passphraseHash),
              passphraseSalt: Value(note.passphraseSalt),
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
  Future<void> applyRemoteFolder(RemoteFolder folder) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.folders,
      )..where((t) => t.id.equals(folder.id))).getSingleOrNull();
      if (existing != null && folder.version <= existing.baseVersion) return;

      await _db
          .into(_db.folders)
          .insertOnConflictUpdate(
            FoldersCompanion(
              id: Value(folder.id),
              name: Value(folder.name),
              version: Value(folder.version),
              baseVersion: Value(folder.version),
              createdAt: Value(folder.createdAt),
              updatedAt: Value(folder.updatedAt),
              serverUpdatedAt: Value(folder.updatedAt),
              deletedAt: Value(folder.deletedAt),
              dirty: const Value(false),
              isNew: const Value(false),
              lastDeviceId: Value(folder.lastDeviceId),
            ),
          );
    });
  }

  @override
  Future<void> applyRemoteImage(RemoteImage image) async {
    await _db
        .into(_db.noteImages)
        .insertOnConflictUpdate(
          NoteImagesCompanion(
            id: Value(image.id),
            storagePath: Value(image.storagePath),
            byteSize: Value(image.byteSize),
            width: Value(image.width),
            height: Value(image.height),
            createdAt: Value(image.createdAt),
            updatedAt: Value(image.updatedAt),
            deletedAt: Value(image.deletedAt),
            dirty: const Value(false),
          ),
        );
  }

  @override
  Future<void> hardDelete(String id) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> hardDeleteFolder(String id) async {
    await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> hardDeleteImage(String id) async {
    await (_db.delete(_db.noteImages)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------

  Future<DateTime?> _getTime(String key) async {
    final value = await _getMeta(key);
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  Future<void> _setTime(String key, DateTime value) =>
      _setMeta(key, value.toUtc().toIso8601String());

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
          SyncMetaEntriesCompanion(key: Value(key), value: Value(value)),
        );
  }

  LocalNote _toLocal(Note row) => LocalNote(
    id: row.id,
    body: row.body,
    folderId: row.folderId,
    pinned: row.pinned,
    locked: row.locked,
    passphraseHash: row.passphraseHash,
    passphraseSalt: row.passphraseSalt,
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

  LocalFolder _toLocalFolder(Folder row) => LocalFolder(
    id: row.id,
    name: row.name,
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

  LocalImage _toLocalImage(NoteImage row) => LocalImage(
    id: row.id,
    storagePath: row.storagePath,
    byteSize: row.byteSize,
    width: row.width,
    height: row.height,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    dirty: row.dirty,
  );

  LocalInk _toLocalInk(NoteInk row) => LocalInk(
    id: row.id,
    strokes: row.strokes,
    canvasWidth: row.canvasWidth,
    canvasHeight: row.canvasHeight,
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
