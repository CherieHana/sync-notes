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
    this.verifyPassword,
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
      verifyPassword: (password) async {
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw const RemoteApiException('当前没有登录账号');
        }
        // 重新登录一次来验证密码。密码错了 Supabase 会抛异常。
        await client.auth.signInWithPassword(email: email, password: password);
      },
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

  /// 联网校验登录密码，用于「忘记笔记口令」时确认身份。
  /// 失败时抛异常；离线时也会失败，界面据此提示需要联网。
  final Future<void> Function(String password)? verifyPassword;

  /// 本次运行期间已解锁的笔记 id。
  ///
  /// 刻意只放内存、且不落盘：App 进程结束就失效，下次打开还得重新输口令。
  /// 存到磁盘上的话，那道锁就名存实亡了。
  final Set<String> _unlockedNotes = <String>{};

  bool isUnlocked(String noteId) => _unlockedNotes.contains(noteId);

  void markUnlocked(String noteId) => _unlockedNotes.add(noteId);

  void markLocked(String noteId) => _unlockedNotes.remove(noteId);

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
