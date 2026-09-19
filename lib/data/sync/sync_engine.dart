import 'package:uuid/uuid.dart';

import '../../util/note_text.dart';
import '../local/local_store.dart';
import '../models.dart';
import '../remote/remote_api.dart';

/// 一次同步的结果。各计数为 0 且 [offline] 为 false，表示本来就没有变化。
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.offline = false,
    this.error,
  });

  /// 成功上传的条数（含删除）。
  final int pushed;

  /// 从服务端写入本地的条数。
  final int pulled;

  /// 检测到版本冲突并生成冲突副本的次数。
  final int conflicts;

  /// 网络不可达，本轮同步中断。未推送的改动会保留到下一轮。
  final bool offline;
  final String? error;

  bool get hasChanges => pushed > 0 || pulled > 0 || conflicts > 0;

  @override
  String toString() =>
      'SyncReport(pushed=$pushed, pulled=$pulled, conflicts=$conflicts, '
      'offline=$offline${error == null ? '' : ', error=$error'})';
}

/// 同步引擎：把本地改动推上去，再把远端改动拉下来。
///
/// 顺序固定为「先推后拉」。推送时先目录再笔记：笔记带着 folder_id，
/// 目录得先在服务端存在。
///
/// 并发控制用乐观锁：记录带上「上次同步成功时的版本号」作为更新条件，
/// 服务端匹配不到行就说明期间被别的设备改过。笔记会生成冲突副本保住两份内容；
/// 目录没有正文可丢，直接以本地这次改动为准重试一次。
class SyncEngine {
  SyncEngine({
    required this.local,
    required this.remote,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final LocalStore local;
  final RemoteApi remote;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// 增量拉取时向前重叠的窗口。服务端可能在同一微秒附近写入多条，
  /// 留一点重叠区间可以避免边界上的记录被漏掉；重复拉到同一条是无害的。
  static const Duration pullOverlap = Duration(seconds: 5);

  /// 图片失去引用后，先挂起多久才真正标记删除。
  /// 留这段时间是为了躲开同步时序：一端刚删掉标记，另一端还没拉到。
  static const Duration orphanGrace = Duration(hours: 24);

  /// 已标记删除的图片，再过多久才去动存储桶里的文件。
  static const Duration objectGrace = Duration(days: 7);

  Future<SyncReport>? _inFlight;
  String? _cachedDeviceId;

  /// 同一时刻只允许一轮同步，重复调用共享同一个 Future。
  Future<SyncReport> syncNow() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() {
      _inFlight = null;
    });
  }

  Future<SyncReport> _run() async {
    final device = await _deviceId();

    var pushed = 0;
    var conflicts = 0;
    try {
      pushed += await _pushFolders(device);
      final notes = await _pushNotes(device);
      pushed += notes.uploaded;
      conflicts += notes.conflicts;
      pushed += await _pushImages();
      pushed += await _pushInks(device);
    } on RemoteApiException catch (error) {
      return SyncReport(
        pushed: pushed,
        conflicts: conflicts,
        offline: true,
        error: error.message,
      );
    }

    var pulled = 0;
    try {
      pulled += await _pullFolders();
      pulled += await _pullNotes();
      pulled += await _pullImages();
      pulled += await _pullInks();
      await _collectOrphanEmbeds();
    } on RemoteApiException catch (error) {
      return SyncReport(
        pushed: pushed,
        pulled: pulled,
        conflicts: conflicts,
        offline: true,
        error: error.message,
      );
    }

    return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts);
  }

  // ---------------------------------------------------------------------
  // 推送：目录
  // ---------------------------------------------------------------------

  Future<int> _pushFolders(String device) async {
    var pushed = 0;
    for (final folder in await local.pendingFolders()) {
      if (folder.isNew) {
        if (folder.isDeleted) {
          // 建完还没上传就删了，服务端本来就没有，本地丢掉即可。
          await local.hardDeleteFolder(folder.id);
          continue;
        }
        final created = await remote.insertFolder(
          id: folder.id,
          name: folder.name,
          lastDeviceId: device,
        );
        await local.applyRemoteFolder(created);
        pushed++;
        continue;
      }

      final updated = await remote.updateFolderIfVersion(
        id: folder.id,
        name: folder.name,
        expectedVersion: folder.baseVersion,
        lastDeviceId: device,
        deletedAt: folder.deletedAt,
      );
      if (updated != null) {
        await local.applyRemoteFolder(updated);
        pushed++;
        continue;
      }

      // 目录撞车：正文没什么可保留的，以本地这次改动为准重试一次。
      final current = await remote.fetchFolderById(folder.id);
      if (current == null) {
        await local.hardDeleteFolder(folder.id);
        continue;
      }
      final retried = await remote.updateFolderIfVersion(
        id: folder.id,
        name: folder.name,
        expectedVersion: current.version,
        lastDeviceId: device,
        deletedAt: folder.deletedAt,
      );
      await local.applyRemoteFolder(retried ?? current);
      if (retried != null) pushed++;
    }
    return pushed;
  }

  // ---------------------------------------------------------------------
  // 推送：笔记
  // ---------------------------------------------------------------------

  Future<_PushResult> _pushNotes(String device) async {
    var pushed = 0;
    var conflicts = 0;
    for (final note in await local.pendingNotes()) {
      final result = await _pushOneNote(note, device);
      if (result.uploaded) pushed++;
      if (result.conflict) conflicts++;
    }
    return _PushResult(uploaded: pushed, conflicts: conflicts);
  }

  Future<_NotePushOutcome> _pushOneNote(LocalNote note, String device) async {
    if (note.isNew) {
      if (note.isDeleted) {
        await local.hardDelete(note.id);
        return const _NotePushOutcome();
      }
      // insert 实现为「按 id upsert」，所以上一次插到一半失败也能安全重试。
      final created = await remote.insert(
        id: note.id,
        payload: _payloadOf(note),
        lastDeviceId: device,
      );
      await local.applyRemote(created);
      return const _NotePushOutcome(uploaded: true);
    }

    final updated = await remote.updateIfVersion(
      id: note.id,
      payload: _payloadOf(note),
      expectedVersion: note.baseVersion,
      lastDeviceId: device,
      deletedAt: note.deletedAt,
    );
    if (updated != null) {
      await local.applyRemote(updated);
      return const _NotePushOutcome(uploaded: true);
    }

    await _resolveConflict(note, device);
    return const _NotePushOutcome(conflict: true);
  }

  NotePayload _payloadOf(LocalNote note) => NotePayload(
    body: note.body,
    folderId: note.folderId,
    locked: note.locked,
    passphraseHash: note.passphraseHash,
    passphraseSalt: note.passphraseSalt,
  );

  NotePayload _payloadOfRemote(RemoteNote note) => NotePayload(
    body: note.body,
    folderId: note.folderId,
    locked: note.locked,
    passphraseHash: note.passphraseHash,
    passphraseSalt: note.passphraseSalt,
  );

  /// 版本对不上，说明这条笔记在本地编辑期间被其他设备改过。
  ///
  /// 处理原则是两边内容都留下：一份存成带时间戳的「冲突副本」，
  /// 另一份留在原笔记上，由用户自己合并。副本继承目录归属和加锁状态，
  /// 否则一篇加密笔记的副本会突然变成明文可见。
  Future<void> _resolveConflict(LocalNote note, String device) async {
    final current = await remote.fetchById(note.id);
    if (current == null) {
      // 服务端查不到这条（被其他设备硬删过），把本地内容重新建上去。
      final recreated = await remote.insert(
        id: note.id,
        payload: _payloadOf(note),
        lastDeviceId: device,
      );
      await local.applyRemote(recreated);
      return;
    }

    if (note.isDeleted) {
      // 本地删、远端改：先把远端那一版留成副本，再让删除生效。
      await _insertCopy(device, _payloadOfRemote(current), current.body);
      final deleted = await remote.updateIfVersion(
        id: note.id,
        payload: _payloadOfRemote(current),
        expectedVersion: current.version,
        lastDeviceId: device,
        deletedAt: _clock().toUtc(),
      );
      await local.applyRemote(deleted ?? current);
      return;
    }

    // 本地改、远端也改：本地这份存成副本，原笔记接受远端最新版本。
    await _insertCopy(device, _payloadOf(note), note.body);
    await local.applyRemote(current);
  }

  /// 建一份冲突副本。目录归属和加锁字段跟着原笔记走。
  Future<void> _insertCopy(
    String device,
    NotePayload source,
    String body,
  ) async {
    await remote.insert(
      id: _uuid.v4(),
      payload: NotePayload(
        body: buildConflictCopyBody(body, _clock()),
        folderId: source.folderId,
        locked: source.locked,
        passphraseHash: source.passphraseHash,
        passphraseSalt: source.passphraseSalt,
      ),
      lastDeviceId: device,
    );
  }

  // ---------------------------------------------------------------------
  // 推送：图片
  // ---------------------------------------------------------------------

  Future<int> _pushImages() async {
    var pushed = 0;
    for (final image in await local.pendingImages()) {
      if (image.isDeleted) {
        final row = await remote.upsertImage(
          id: image.id,
          storagePath: image.storagePath,
          byteSize: image.byteSize,
          width: image.width,
          height: image.height,
          deletedAt: image.deletedAt,
        );
        await local.applyRemoteImage(row);
        pushed++;
        continue;
      }

      final bytes = await local.readImageFile(image.id);
      if (bytes == null) {
        // 本地文件不见了（被清理或写入失败），这条记录没法传，标记删掉。
        await local.softDeleteImage(id: image.id, now: _clock());
        continue;
      }
      await remote.uploadImage(image.storagePath, bytes);
      final row = await remote.upsertImage(
        id: image.id,
        storagePath: image.storagePath,
        byteSize: bytes.length,
        width: image.width,
        height: image.height,
      );
      await local.applyRemoteImage(row);
      pushed++;
    }
    return pushed;
  }

  // ---------------------------------------------------------------------
  // 推送：手写画布
  // ---------------------------------------------------------------------

  /// 推送手写画布。
  ///
  /// 笔迹可以反复修改，所以带版本号走乐观锁。撞车时不像笔记那样生成副本：
  /// 一幅画没法自动合并，留两份手写也没人愿意去对，直接以本地这次改动为准重试。
  Future<int> _pushInks(String device) async {
    var pushed = 0;
    for (final ink in await local.pendingInks()) {
      if (ink.isNew) {
        if (ink.isDeleted) {
          await local.hardDeleteInk(ink.id);
          continue;
        }
        final created = await remote.insertInk(
          id: ink.id,
          strokes: ink.strokes,
          canvasWidth: ink.canvasWidth,
          canvasHeight: ink.canvasHeight,
          lastDeviceId: device,
        );
        await local.applyRemoteInk(created);
        pushed++;
        continue;
      }

      final updated = await remote.updateInkIfVersion(
        id: ink.id,
        strokes: ink.strokes,
        expectedVersion: ink.baseVersion,
        lastDeviceId: device,
        deletedAt: ink.deletedAt,
      );
      if (updated != null) {
        await local.applyRemoteInk(updated);
        pushed++;
        continue;
      }

      final current = await remote.fetchInkById(ink.id);
      if (current == null) {
        if (ink.baseVersion == 0) {
          // 本地这条从来没跟服务端对上过号，服务端没有它不等于「被别人删了」。
          // 这里补一次插入，免得把刚画好的画当成垃圾清掉。
          final created = await remote.insertInk(
            id: ink.id,
            strokes: ink.strokes,
            canvasWidth: ink.canvasWidth,
            canvasHeight: ink.canvasHeight,
            lastDeviceId: device,
          );
          await local.applyRemoteInk(created);
          pushed++;
        } else {
          await local.hardDeleteInk(ink.id);
        }
        continue;
      }
      final retried = await remote.updateInkIfVersion(
        id: ink.id,
        strokes: ink.strokes,
        expectedVersion: current.version,
        lastDeviceId: device,
        deletedAt: ink.deletedAt,
      );
      await local.applyRemoteInk(retried ?? current);
      if (retried != null) pushed++;
    }
    return pushed;
  }

  // ---------------------------------------------------------------------
  // 拉取
  // ---------------------------------------------------------------------

  Future<int> _pullFolders() async {
    final last = await local.getFoldersPulledAt();
    final since = last?.subtract(pullOverlap);
    final rows = await remote.fetchFoldersChangedSince(since);

    var applied = 0;
    var highWater = last;
    for (final row in rows) {
      if (highWater == null || row.updatedAt.isAfter(highWater)) {
        highWater = row.updatedAt;
      }
      final existing = await local.findFolderById(row.id);
      if (existing != null) {
        if (existing.dirty) continue;
        if (row.version <= existing.baseVersion) continue;
      }
      await local.applyRemoteFolder(row);
      applied++;
    }

    if (highWater != null && (last == null || highWater.isAfter(last))) {
      await local.setFoldersPulledAt(highWater);
    }
    return applied;
  }

  Future<int> _pullNotes() async {
    final last = await local.getLastPulledAt();
    final since = last?.subtract(pullOverlap);
    final rows = await remote.fetchChangedSince(since);

    var applied = 0;
    var highWater = last;
    for (final row in rows) {
      if (highWater == null || row.updatedAt.isAfter(highWater)) {
        highWater = row.updatedAt;
      }
      final existing = await local.findById(row.id);
      if (existing != null) {
        // 本地还有没推上去的改动，跳过，交给下一轮的推送处理，
        // 免得把用户刚写的内容盖掉。
        if (existing.dirty) continue;
        if (row.version <= existing.baseVersion) continue;
      }
      await local.applyRemote(row);
      applied++;
    }

    if (highWater != null && (last == null || highWater.isAfter(last))) {
      await local.setLastPulledAt(highWater);
    }
    return applied;
  }

  Future<int> _pullImages() async {
    final last = await local.getImagesPulledAt();
    final since = last?.subtract(pullOverlap);
    final rows = await remote.fetchImagesChangedSince(since);

    var applied = 0;
    var highWater = last;
    for (final row in rows) {
      if (highWater == null || row.updatedAt.isAfter(highWater)) {
        highWater = row.updatedAt;
      }
      await local.applyRemoteImage(row);
      if (!row.isDeleted) await _ensureImageLocally(row.id);
      applied++;
    }

    if (highWater != null && (last == null || highWater.isAfter(last))) {
      await local.setImagesPulledAt(highWater);
    }
    return applied;
  }

  /// 本地没有这张图的字节就下回来。单张失败只跳过它，不打断整轮同步。
  Future<void> _ensureImageLocally(String imageId) async {
    if (await local.imageFileExists(imageId)) return;
    final image = await local.findImageById(imageId);
    if (image == null || image.isDeleted) return;
    try {
      final bytes = await remote.downloadImage(image.storagePath);
      await local.writeImageFile(imageId, bytes);
    } on RemoteApiException {
      // 下一轮再试
    }
  }

  /// 回收没人引用的图片和手写画布。
  Future<int> _pullInks() async {
    final last = await local.getInksPulledAt();
    final since = last?.subtract(pullOverlap);
    final rows = await remote.fetchInksChangedSince(since);

    var applied = 0;
    var highWater = last;
    for (final row in rows) {
      if (highWater == null || row.updatedAt.isAfter(highWater)) {
        highWater = row.updatedAt;
      }
      final existing = await local.findInkById(row.id);
      if (existing != null) {
        // 本地还没推上去的改动优先，留给下一轮推送处理。
        if (existing.dirty) continue;
        if (row.version <= existing.baseVersion) continue;
      }
      await local.applyRemoteInk(row);
      applied++;
    }

    if (highWater != null && (last == null || highWater.isAfter(last))) {
      await local.setInksPulledAt(highWater);
    }
    return applied;
  }

  /// 回收没人引用的图片和手写画布。
  ///
  /// 分两步走：先挂起一段时间再标记删除，标记删除之后再过一段时间才去动
  /// 存储桶里的文件。中间的等待是为了躲开同步时序——某个设备刚删掉图片标记，
  /// 另一个设备还没拉到那次修改，这时就把文件删了会让人家的图片变成裂图。
  /// 手写画布没有文件本体，只删记录，但同样要走这两步。
  Future<void> _collectOrphanEmbeds() async {
    final notes = await local.allVisibleNotes();
    final referencedImages = <String>{};
    final referencedInks = <String>{};
    for (final note in notes) {
      referencedImages.addAll(imageIdsIn(note.body));
      referencedInks.addAll(inkIdsIn(note.body));
    }

    final now = _clock();

    // 第一步：失去引用超过宽限期的，先标记删除，把墓碑同步给其他设备。
    for (final image in await local.allImages()) {
      if (image.dirty || referencedImages.contains(image.id)) continue;
      if (now.difference(image.createdAt) < orphanGrace) continue;
      await local.softDeleteImage(id: image.id, now: now);
    }
    for (final ink in await local.allInks()) {
      if (ink.dirty || referencedInks.contains(ink.id)) continue;
      if (now.difference(ink.createdAt) < orphanGrace) continue;
      await local.softDeleteInk(id: ink.id, now: now);
    }

    // 第二步：墓碑同步出去之后又等够久的，才真正删掉文件本体和记录。
    for (final image in await local.deletedImages()) {
      final deletedAt = image.deletedAt;
      if (deletedAt == null || image.dirty) continue;
      if (now.difference(deletedAt) < objectGrace) continue;
      try {
        await remote.deleteImageObject(image.storagePath);
      } on RemoteApiException {
        continue; // 下一轮再试
      }
      await local.deleteImageFile(image.id);
      await local.hardDeleteImage(image.id);
    }
    for (final ink in await local.deletedInks()) {
      final deletedAt = ink.deletedAt;
      if (deletedAt == null || ink.dirty) continue;
      if (now.difference(deletedAt) < objectGrace) continue;
      await local.hardDeleteInk(ink.id);
    }
  }

  // ---------------------------------------------------------------------
  // 实时
  // ---------------------------------------------------------------------

  /// 处理服务端实时推来的一条笔记变更。返回是否真的写进了本地。
  Future<bool> applyRealtime(RemoteNote note) async {
    final existing = await local.findById(note.id);
    if (existing != null) {
      // 本地有待推送的改动，等推送时按冲突流程处理，这里不动。
      if (existing.dirty) return false;
      if (note.version <= existing.baseVersion) return false;
    }
    // 自己刚推上去的记录会被实时通道回显一遍，跳过避免多余写库。
    if (note.lastDeviceId != null && note.lastDeviceId == _cachedDeviceId) {
      return false;
    }
    await local.applyRemote(note);
    return true;
  }

  /// 处理服务端实时推来的目录变更。
  Future<bool> applyFolderRealtime(RemoteFolder folder) async {
    final existing = await local.findFolderById(folder.id);
    if (existing != null) {
      if (existing.dirty) return false;
      if (folder.version <= existing.baseVersion) return false;
    }
    if (folder.lastDeviceId != null && folder.lastDeviceId == _cachedDeviceId) {
      return false;
    }
    await local.applyRemoteFolder(folder);
    // 目录被别的设备删掉时，本地还挂着的笔记要回到未分类。
    if (folder.isDeleted) await _detachNotesFrom(folder.id);
    return true;
  }

  Future<void> _detachNotesFrom(String folderId) async {
    for (final note in await local.allVisibleNotes()) {
      if (note.folderId == folderId) {
        await local.setNoteFolder(id: note.id, folderId: null, now: _clock());
      }
    }
  }

  Future<String> _deviceId() async {
    return _cachedDeviceId ??= await local.deviceId();
  }
}

class _PushResult {
  const _PushResult({this.uploaded = 0, this.conflicts = 0});

  final int uploaded;
  final int conflicts;
}

class _NotePushOutcome {
  const _NotePushOutcome({this.uploaded = false, this.conflict = false});

  final bool uploaded;
  final bool conflict;
}
