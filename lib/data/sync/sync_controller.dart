import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models.dart';
import '../remote/remote_api.dart';
import 'sync_engine.dart';

enum SyncStatus { idle, syncing, offline, error }

/// 同步的调度中枢：决定什么时候同步，并把状态暴露给界面。
///
/// 触发点有四类：
/// 1. App 启动、从后台切回前台（由界面层的生命周期回调调用 [sync]）
/// 2. 网络恢复（这里监听）
/// 3. 服务端实时推送（这里监听，只影响单条）
/// 4. 前台定时兜底（防止实时通道静默断开后长时间不同步）
class SyncController extends ChangeNotifier {
  SyncController({
    required this.engine,
    required this.remote,
    required this.local,
    this.pollInterval = const Duration(seconds: 60),
  });

  final SyncEngine engine;
  final RemoteApi remote;
  final LocalStore local;
  final Duration pollInterval;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  int _pendingCount = 0;
  DateTime? _lastSyncedAt;

  StreamSubscription<RemoteNote>? _realtimeSubscription;
  StreamSubscription<RemoteFolder>? _folderRealtimeSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollTimer;
  bool _disposed = false;

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Future<void> start() async {
    _realtimeSubscription = remote.watchChanges().listen(
      _onRealtimeNote,
      onError: (_) {
        // 实时通道断开不影响正确性，定时兜底会把数据补齐。
      },
    );

    _folderRealtimeSubscription = remote.watchFolderChanges().listen(
      _onRealtimeFolder,
      onError: (_) {},
    );

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        results,
      ) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online) unawaited(sync());
      }, onError: (_) {});
    } catch (_) {
      // 插件在当前环境不可用（比如跑界面测试时）就退化成只靠前台定时对账，
      // 不该因为一个可选的能力缺失让整个应用起不来。
    }

    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(sync()));
    await sync();
  }

  /// 跑一轮完整同步：先推本地改动，再拉远端变化。
  Future<void> sync() async {
    if (_disposed) return;
    await _refreshPending();
    _setStatus(SyncStatus.syncing);

    final report = await engine.syncNow();
    if (_disposed) return;

    await _refreshPending();
    if (report.offline) {
      _lastError = report.error;
      _setStatus(SyncStatus.offline);
    } else {
      _lastError = null;
      _lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.idle);
    }
  }

  Future<void> _onRealtimeNote(RemoteNote note) async {
    if (_disposed) return;
    final applied = await engine.applyRealtime(note);
    if (applied && !_disposed) {
      await _refreshPending();
      notifyListeners();
    }
  }

  Future<void> _onRealtimeFolder(RemoteFolder folder) async {
    if (_disposed) return;
    final applied = await engine.applyFolderRealtime(folder);
    if (applied && !_disposed) {
      await _refreshPending();
      notifyListeners();
    }
  }

  Future<void> _refreshPending() async {
    final count = await local.pendingCount();
    if (count == _pendingCount) return;
    _pendingCount = count;
    notifyListeners();
  }

  void _setStatus(SyncStatus status) {
    if (_status == status) {
      notifyListeners();
      return;
    }
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_folderRealtimeSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }
}
