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
/// 顺序固定为「先推后拉」，这样拉取阶段遇到的脏数据一定是本轮推送失败的
/// 残留（比如推到一半断网），跳过它交给下一轮即可，不必在这里做二次冲突判定。
///
/// 并发控制用乐观锁：每条记录带上「上次同步成功时的版本号」作为更新条件，
/// 服务端匹配不到行就说明期间被别的设备改过，转入冲突流程。冲突时两边的正文
/// 都会保留下来，不会丢内容。
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
      for (final note in await local.pendingNotes()) {
        final result = await _pushOne(note, device);
        if (result.uploaded) pushed++;
        if (result.conflict) conflicts++;
      }
    } on RemoteApiException catch (error) {
      return SyncReport(
        pushed: pushed,
        conflicts: conflicts,
        offline: true,
        error: error.message,
      );
    }

    try {
      final pulled = await _pull();
      return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts);
    } on RemoteApiException catch (error) {
      return SyncReport(
        pushed: pushed,
        conflicts: conflicts,
        offline: true,
        error: error.message,
      );
    }
  }

  Future<_PushResult> _pushOne(LocalNote note, String device) async {
    if (note.isNew) {
      if (note.isDeleted) {
        // 新建之后还没同步上去就被删了，服务端本来就没有这条，本地丢掉即可。
        await local.hardDelete(note.id);
        return const _PushResult();
      }
      // insert 实现为「按 id upsert」，所以上一次插到一半失败也能安全重试。
      final created = await remote.insert(
        id: note.id,
        body: note.body,
        lastDeviceId: device,
      );
      await local.applyRemote(created);
      return const _PushResult(uploaded: true);
    }

    final updated = await remote.updateIfVersion(
      id: note.id,
      body: note.body,
      expectedVersion: note.baseVersion,
      lastDeviceId: device,
      deletedAt: note.deletedAt,
    );
    if (updated != null) {
      await local.applyRemote(updated);
      return const _PushResult(uploaded: true);
    }

    await _resolveConflict(note, device);
    return const _PushResult(conflict: true);
  }

  /// 版本对不上，说明这条笔记在本地编辑期间被其他设备改过。
  ///
  /// 处理原则是两边内容都留下：一份存成带时间戳的「冲突副本」，
  /// 另一份留在原笔记上，由用户自己合并。
  Future<void> _resolveConflict(LocalNote note, String device) async {
    final current = await remote.fetchById(note.id);
    if (current == null) {
      // 服务端查不到这条（被其他设备硬删过），把本地内容重新建上去。
      final recreated = await remote.insert(
        id: note.id,
        body: note.body,
        lastDeviceId: device,
      );
      await local.applyRemote(recreated);
      return;
    }

    if (note.isDeleted) {
      // 本地删、远端改：先把远端那一版留成副本，再让删除生效。
      await remote.insert(
        id: _uuid.v4(),
        body: buildConflictCopyBody(current.body, _clock()),
        lastDeviceId: device,
      );
      final deleted = await remote.updateIfVersion(
        id: note.id,
        body: current.body,
        expectedVersion: current.version,
        lastDeviceId: device,
        deletedAt: _clock().toUtc(),
      );
      await local.applyRemote(deleted ?? current);
      return;
    }

    // 本地改、远端也改：本地这份存成副本，原笔记接受远端最新版本。
    await remote.insert(
      id: _uuid.v4(),
      body: buildConflictCopyBody(note.body, _clock()),
      lastDeviceId: device,
    );
    await local.applyRemote(current);
  }

  Future<int> _pull() async {
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
        // 版本不比本地新，说明本地已经是最新的。
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

  /// 处理服务端实时推来的一条变更。返回是否真的写进了本地。
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

  Future<String> _deviceId() async {
    return _cachedDeviceId ??= await local.deviceId();
  }
}

class _PushResult {
  const _PushResult({this.uploaded = false, this.conflict = false});

  final bool uploaded;
  final bool conflict;
}
