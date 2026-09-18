import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/local/database.dart';
import 'data/local/drift_local_store.dart';
import 'data/local/local_store.dart';
import 'data/remote/supabase_remote_api.dart';
import 'data/remote/remote_api.dart';
import 'data/sync/sync_controller.dart';
import 'data/sync/sync_engine.dart';

/// 一次登录会话里的全部依赖。按账号创建，退出登录时整体释放。
class AppServices {
  AppServices({
    required this.userId,
    required this.local,
    required this.remote,
    required this.engine,
    required this.sync,
    this.database,
    this.accountEmail = '',
    this.signOut,
  });

  factory AppServices.create(SupabaseClient client, String userId) {
    final database = AppDatabase('sync_notes_$userId');
    final local = DriftLocalStore(database);
    final remote = SupabaseRemoteApi(client);
    final engine = SyncEngine(local: local, remote: remote);
    return AppServices(
      userId: userId,
      local: local,
      remote: remote,
      engine: engine,
      sync: SyncController(engine: engine, remote: remote, local: local),
      database: database,
      accountEmail: client.auth.currentUser?.email ?? '',
      signOut: client.auth.signOut,
    );
  }

  final String userId;
  final LocalStore local;
  final RemoteApi remote;
  final SyncEngine engine;
  final SyncController sync;

  /// 只有真实运行时才有；界面测试里注入内存实现，不碰文件系统。
  final AppDatabase? database;

  /// 当前登录的邮箱，界面上用来显示和确认。
  final String accountEmail;

  /// 退出登录。界面层不直接依赖 Supabase，认证动作统一从这里走。
  final Future<void> Function()? signOut;

  Future<void> dispose() async {
    sync.dispose();
    await remote.dispose();
    await database?.close();
  }
}

/// 把依赖挂到 widget 树上，界面层从这里取。
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(
      scope != null,
      'AppScope 未挂载。注意它必须在 MaterialApp 外面，'
      '否则 Navigator.push 出来的页面取不到它。',
    );
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services.userId != oldWidget.services.userId;
}
