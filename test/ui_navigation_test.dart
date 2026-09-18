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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
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

void main() {
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
}
