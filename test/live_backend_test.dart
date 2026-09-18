// 真实后端的端到端联调测试。
//
// 平时跑 `flutter test` 会跳过（需要一个测试账号和网络），
// 需要显式开启：
//
//   flutter test test/live_backend_test.dart \
//     --dart-define=LIVE=true \
//     --dart-define-from-file=config.json \
//     --dart-define=LIVE_EMAIL=你的测试邮箱 \
//     --dart-define=LIVE_PASSWORD=测试账号密码
//
// 它直接使用应用里的 SupabaseRemoteApi 和 SyncEngine，模拟两台设备，
// 覆盖新建、拉取、编辑、版本冲突、删除这几条真实链路，
// 以及跨账号的行级权限隔离。跑完会清掉自己造的数据。
//
// 账号信息从命令行传入而不是写在源码里：这个仓库是公开的，
// 把密码写进文件等于把账号送出去。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/remote/supabase_remote_api.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:uuid/uuid.dart';

import 'support/fake_store.dart';

const bool _live = bool.fromEnvironment('LIVE');
const String _url = String.fromEnvironment('SUPABASE_URL');
const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// 专门给这个测试用的账号，和你自己用的账号互不影响。
const String _emailA = String.fromEnvironment('LIVE_EMAIL');
const String _password = String.fromEnvironment('LIVE_PASSWORD');

/// 第二个账号用来验证跨账号隔离，在第一个邮箱的名字后面加 `-2` 推出来。
String get _emailB {
  final at = _emailA.indexOf('@');
  if (at <= 0) return '';
  return '${_emailA.substring(0, at)}-2${_emailA.substring(at)}';
}

const String _zeroUuid = '00000000-0000-0000-0000-000000000000';

void main() {
  if (!_live || _emailA.isEmpty || _password.isEmpty) {
    test(
      '真实后端联调（默认跳过）',
      () {},
      skip: '需要 --dart-define=LIVE=true 以及 LIVE_EMAIL / LIVE_PASSWORD',
    );
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient userA;
  late SupabaseClient userB;

  SupabaseClient newClient() => SupabaseClient(
    _url,
    _anonKey,
    // 不走 PKCE：那需要一套持久化存储，纯测试环境里没必要。
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );

  /// 账号可能是第一次跑测试时注册的，也可能已经存在，两种都兼容。
  Future<void> ensureSignedIn(SupabaseClient client, String email) async {
    try {
      await client.auth.signUp(email: email, password: _password);
    } on AuthException catch (error) {
      if (!error.message.toLowerCase().contains('already')) rethrow;
    }
    if (client.auth.currentSession == null) {
      await client.auth.signInWithPassword(email: email, password: _password);
    }
  }

  setUpAll(() async {
    // flutter_test 默认会把所有 HTTP 请求拦成 400，这里放行真实网络。
    HttpOverrides.global = null;
    userA = newClient();
    userB = newClient();
    await ensureSignedIn(userA, _emailA);
    await ensureSignedIn(userB, _emailB);
  });

  tearDownAll(() async {
    // 这两个账号只服务于本测试，把它们的笔记清空即可。
    for (final client in [userA, userB]) {
      try {
        await client.from('notes').delete().neq('id', _zeroUuid);
      } catch (_) {
        // 清理失败不影响测试结论
      }
      await client.dispose();
    }
  });

  test('两台设备走真实后端完成一轮完整同步', () async {
    final remote = SupabaseRemoteApi(userA);
    final deviceA = FakeLocalStore()..device = 'live-device-a';
    final deviceB = FakeLocalStore()..device = 'live-device-b';
    final engineA = SyncEngine(local: deviceA, remote: remote);
    final engineB = SyncEngine(local: deviceB, remote: remote);

    final id = const Uuid().v4();
    final now = DateTime.now();

    // --- 1. 设备 A 新建一条并上传 ---
    deviceA.notes[id] = LocalNote(
      id: id,
      body: '手机上写的第一条',
      version: 1,
      baseVersion: 0,
      createdAt: now,
      updatedAt: now,
      dirty: true,
      isNew: true,
    );
    final pushA = await engineA.syncNow();
    expect(pushA.offline, isFalse, reason: '上传不该失败：${pushA.error}');
    expect(pushA.pushed, 1);
    expect(deviceA.notes[id]!.dirty, isFalse, reason: '上传成功后就该摘掉脏标记');
    expect(deviceA.notes[id]!.baseVersion, 1);

    // --- 2. 设备 B 拉取，能看见 A 写的内容 ---
    await engineB.syncNow();
    expect(deviceB.notes[id]?.body, '手机上写的第一条');
    expect(deviceB.notes[id]!.dirty, isFalse);

    // --- 3. 设备 B 修改后上传 ---
    await deviceB.updateBody(id: id, body: '电脑上改了一下', now: DateTime.now());
    final pushB = await engineB.syncNow();
    expect(pushB.pushed, 1);
    expect(deviceB.notes[id]!.baseVersion, 2, reason: '服务端版本号应该递增到 2');

    // --- 4. 设备 A 拉取到 B 的修改 ---
    final pullA = await engineA.syncNow();
    expect(pullA.pulled, greaterThanOrEqualTo(1));
    expect(deviceA.notes[id]!.body, '电脑上改了一下');

    // --- 5. 两端基于同一个版本各改各的，制造冲突 ---
    await deviceA.updateBody(id: id, body: 'A 这边的写法', now: DateTime.now());
    await deviceB.updateBody(id: id, body: 'B 那边的写法', now: DateTime.now());
    final raceA = await engineA.syncNow();
    expect(raceA.conflicts, 0, reason: 'A 先推，不该冲突');
    final raceB = await engineB.syncNow();
    expect(raceB.conflicts, 1, reason: 'B 后推，版本已经变了，应该判定为冲突');

    // --- 6. 两份内容都还在：原笔记是 A 的，副本是 B 的 ---
    final rows = await remote.fetchChangedSince(null);
    final original = rows.firstWhere((n) => n.id == id);
    expect(original.body, 'A 这边的写法');
    final copies = rows.where((n) => n.body.contains('冲突副本')).toList();
    expect(copies, hasLength(1), reason: '应该正好生成一份冲突副本');
    expect(copies.single.body, startsWith('B 那边的写法（冲突副本 '));
    expect(copies.single.deletedAt, isNull);

    // --- 7. 删除会传播到另一端 ---
    await deviceA.softDelete(id: id, now: DateTime.now());
    final deletePush = await engineA.syncNow();
    expect(deletePush.pushed, 1);

    await engineB.syncNow();
    expect(deviceB.notes[id]!.isDeleted, isTrue, reason: 'B 端应该同步到删除状态');

    // --- 8. 服务端时间由触发器接管，不是客户端时间 ---
    final afterEdit = rows.firstWhere((n) => n.id == id);
    expect(
      afterEdit.updatedAt.isAfter(now.subtract(const Duration(minutes: 1))),
      isTrue,
      reason: 'updated_at 应该由服务端 now() 生成',
    );
  });

  test('换个账号就看不到别人的笔记', () async {
    final remoteA = SupabaseRemoteApi(userA);
    final remoteB = SupabaseRemoteApi(userB);

    final id = const Uuid().v4();
    final now = DateTime.now();
    final localA = FakeLocalStore()..device = 'live-rls-a';
    localA.notes[id] = LocalNote(
      id: id,
      body: '这是 A 的私密笔记',
      version: 1,
      baseVersion: 0,
      createdAt: now,
      updatedAt: now,
      dirty: true,
      isNew: true,
    );
    await SyncEngine(local: localA, remote: remoteA).syncNow();

    final seenByB = await remoteB.fetchChangedSince(null);
    expect(
      seenByB.where((n) => n.id == id),
      isEmpty,
      reason: 'B 账号不该看到 A 账号的笔记',
    );
    // 但 A 自己能看见
    final seenByA = await remoteA.fetchChangedSince(null);
    expect(seenByA.where((n) => n.id == id), hasLength(1));
  });
}
