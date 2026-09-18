// 界面层的回归测试。
//
// 这里曾经出过一个只在正式包里才看得见的 bug：新建笔记后进入编辑页，
// 整屏变成灰底、什么都点不了。原因是 AppScope 被放在了 MaterialApp 里面，
// 而 Navigator.push 出来的页面挂在 Navigator 的 Overlay 下、和首页平级，
// 取不到 AppScope，`scope!` 抛空断言。调试模式会显示红色报错屏，
// release 模式则把整棵子树渲染成一块灰底，所以只有正式包才发现。
//
// 这个测试走的是和正式运行完全一样的 widget 树（AuthenticatedApp），
// 所以能把结构问题挡在提交之前。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
import 'package:sync_notes/services/note_lock.dart';
import 'package:sync_notes/ui/note_edit_page.dart';
import 'package:sync_notes/ui/notes_list_page.dart';

import 'support/fake_store.dart';

/// 用内存实现替换真实依赖，测试里不碰文件系统也不连网络。
AppServices buildTestServices(String userId) {
  final local = FakeLocalStore()..device = 'ui-test-device';
  final remote = FakeRemoteApi();
  final engine = SyncEngine(local: local, remote: remote);
  final sync = SyncController(engine: engine, remote: remote, local: local);
  return AppServices(
    userId: userId,
    local: local,
    remote: remote,
    engine: engine,
    sync: sync,
  );
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    AuthenticatedApp(userId: 'ui-test-user', servicesBuilder: buildTestServices),
  );
  await tester.pumpAndSettle();
}

/// 直接把依赖挂到树上，方便测试里预置数据。
Future<void> pumpWithServices(
  WidgetTester tester,
  AppServices services,
) async {
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: const MaterialApp(home: NotesListPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // PBKDF2 内部用 Future.delayed 让出线程，而 widget 测试的虚拟时钟不会自己
  // 往前走，所以这里在 fake async 之外先把口令摘要算好。
  late String lockSalt;
  late String lockHash;

  setUpAll(() async {
    lockSalt = NoteLock.newSalt();
    lockHash = await NoteLock.hash('abcd', lockSalt);
  });

  /// 推进虚拟时钟，让 PBKDF2 里那些让出线程的延时跑完。
  Future<void> settleCrypto(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('新建笔记后编辑页能正常渲染，不是一片灰底', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NotesListPage), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '打开编辑页不该抛异常');
    expect(find.byType(NoteEditPage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: '正文输入框应该在');
    expect(find.text('写点什么…'), findsOneWidget, reason: '空白笔记应显示提示文案');
  });

  testWidgets('编辑页里敲的字会落到本地库', (tester) async {
    final services = buildTestServices('ui-test-user');
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: NotesListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '开会记一下');
    await tester.pump(const Duration(seconds: 1)); // 等自动保存的防抖
    await tester.pumpAndSettle();

    final notes = await services.local.watchVisibleNotes().first;
    expect(notes, hasLength(1));
    expect(notes.single.body, '开会记一下');
  });

  testWidgets('列表页有退出登录入口', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('新建目录后顶部出现对应的标签', (tester) async {
    final services = buildTestServices('ui-test-user');
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建目录'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '工作');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsWidgets);
    final folders = await services.local.watchVisibleFolders().first;
    expect(folders.map((f) => f.name), contains('工作'));
  });

  testWidgets('右键笔记可以把它换到别的目录', (tester) async {
    final services = buildTestServices('ui-test-user');
    final at = DateTime.now();

    LocalFolder folder(String id, String name) => LocalFolder(
      id: id,
      name: name,
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );

    await services.local.createFolder(folder('f1', '近期新闻'));
    await services.local.createFolder(folder('f2', '过期新闻'));
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: '一条新闻',
        version: 1,
        baseVersion: 1,
        folderId: 'f1',
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    // 鼠标右键。触屏上的长按不算自然操作，桌面端得有右键入口。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('一条新闻')),
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('移动到…'), findsOneWidget);
    await tester.tap(find.text('移动到…'));
    await tester.pumpAndSettle();

    // 选「过期新闻」。顶部标签里也有同名文字，这里点的是弹层里的那一项。
    await tester.tap(find.widgetWithText(ListTile, '过期新闻'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.folderId, 'f2');
  });

  testWidgets('编辑页的菜单里也能改目录', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(id: 'n1', body: '正文', version: 1, baseVersion: 1, dirty: false),
    );
    await pumpWithServices(tester, services);

    await tester.tap(find.text('正文'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('移动到…'), findsOneWidget);
  });

  testWidgets('左滑删除后能点撤销把笔记找回来', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(id: 'n1', body: '别删我', version: 1, baseVersion: 1, dirty: false),
    );
    await pumpWithServices(tester, services);

    expect(find.text('别删我'), findsOneWidget);

    await tester.drag(find.text('别删我'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // 列表里没了，但提示条给了反悔的机会。
    expect(find.text('撤销'), findsOneWidget);
    expect((await services.local.findById('n1'))!.isDeleted, isTrue);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.isDeleted, isFalse);
    expect(find.text('别删我'), findsOneWidget);
  });

  testWidgets('加锁的笔记在列表里只露出标题和锁标记', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'locked',
        body: '私密标题\n这里是不该出现在列表里的正文',
        version: 1,
        baseVersion: 1,
        dirty: false,
        locked: true,
        passphraseHash: lockHash,
        passphraseSalt: lockSalt,
      ),
    );

    await pumpWithServices(tester, services);

    expect(find.text('私密标题'), findsOneWidget);
    expect(find.text('已加密，打开需要口令'), findsOneWidget);
    expect(find.textContaining('不该出现在列表里'), findsNothing);
  });

  testWidgets('打开加锁笔记先要口令，且口令框不做遮蔽', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'locked',
        body: '私密标题\n正文',
        version: 1,
        baseVersion: 1,
        dirty: false,
        locked: true,
        passphraseHash: lockHash,
        passphraseSalt: lockSalt,
      ),
    );

    await pumpWithServices(tester, services);
    await tester.tap(find.text('私密标题'));
    await tester.pumpAndSettle();

    expect(find.text('这篇笔记加了锁，输入口令才能打开'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse, reason: '口令要看得见，避免打错');

    // 输错了不开门
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('解锁'));
    await settleCrypto(tester);
    await tester.pumpAndSettle();
    expect(find.text('口令不对'), findsOneWidget);

    // 输对了才进编辑器
    await tester.enterText(find.byType(TextField), 'abcd');
    await tester.tap(find.text('解锁'));
    await settleCrypto(tester);
    await tester.pumpAndSettle();
    expect(find.text('这篇笔记加了锁，输入口令才能打开'), findsNothing);
    expect(find.textContaining('正文'), findsWidgets);
  });
}
