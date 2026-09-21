import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_store.dart';
import 'support/test_app.dart';

/// 置顶（本机偏好）和列表页的多选批量操作。
void main() {
  test('置顶只动那一列：不碰更新时间、版本号、脏标记', () async {
    final local = FakeLocalStore()..device = 'pin-test';
    final at = DateTime.utc(2026, 1, 1);
    await local.createNote(
      localNote(
        id: 'n1',
        body: '一条笔记',
        version: 3,
        baseVersion: 3,
        updatedAt: at,
        dirty: false,
      ),
    );

    await local.setNotePinned(id: 'n1', pinned: true);

    final note = (await local.findById('n1'))!;
    expect(note.pinned, isTrue);
    // 这三点不变，置顶才不会被当成「内容改过」推到服务端去。
    expect(note.updatedAt, at, reason: '置顶不该让笔记显得刚改过');
    expect(note.version, 3);
    expect(note.dirty, isFalse, reason: '置顶是本机偏好，不该触发同步');

    await local.setNotePinned(id: 'n1', pinned: false);
    expect((await local.findById('n1'))!.pinned, isFalse);
    expect((await local.findById('n1'))!.updatedAt, at);
  });

  testWidgets('置顶的笔记排到最前面，标题前面带 📌', (tester) async {
    final services = buildTestServices('ui-test-user');
    // n2 更新时间更晚，正常情况下它排在上面。
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: '旧笔记',
        version: 1,
        baseVersion: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
        dirty: false,
      ),
    );
    await services.local.createNote(
      localNote(
        id: 'n2',
        body: '新笔记',
        version: 1,
        baseVersion: 1,
        updatedAt: DateTime.utc(2026, 2, 1),
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    expect(
      tester.getTopLeft(find.text('新笔记')).dy,
      lessThan(tester.getTopLeft(find.text('旧笔记')).dy),
      reason: '没置顶时应该按更新时间倒序',
    );

    // 长按笔记 → 置顶。
    await tester.longPress(find.text('旧笔记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.pinned, isTrue);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('旧笔记')).dy,
      lessThan(tester.getTopLeft(find.text('新笔记')).dy),
      reason: '置顶的应该排到最前面',
    );

    // 再长按一次是取消置顶。
    await tester.longPress(find.text('旧笔记'));
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tap(find.text('取消置顶'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.pinned, isFalse);
    expect(find.byIcon(Icons.push_pin), findsNothing);
  });

  testWidgets('多选删两条，再点撤销两条都回来', (tester) async {
    final services = buildTestServices('ui-test-user');
    for (final (id, body) in [
      ('n1', '第一条'),
      ('n2', '第二条'),
      ('n3', '第三条'),
    ]) {
      await services.local.createNote(
        localNote(id: id, body: body, version: 1, baseVersion: 1, dirty: false),
      );
    }
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    expect(find.text('已选 0 项'), findsOneWidget);
    // 多选模式下新建按钮先收起来，免得误触。
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('第一条'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第三条'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.isDeleted, isTrue);
    expect((await services.local.findById('n3'))!.isDeleted, isTrue);
    expect((await services.local.findById('n2'))!.isDeleted, isFalse);
    expect(find.text('已删除 2 条笔记'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.isDeleted, isFalse);
    expect((await services.local.findById('n3'))!.isDeleted, isFalse);
    expect(find.text('第一条'), findsOneWidget);
    expect(find.text('第三条'), findsOneWidget);
  });

  testWidgets('多选移动到目录，选中的那些一起换过去', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createFolder(
      localFolder(id: 'f1', name: '近期新闻', dirty: false),
    );
    for (final (id, body) in [('n1', '甲'), ('n2', '乙')]) {
      await services.local.createNote(
        localNote(id: id, body: body, version: 1, baseVersion: 1, dirty: false),
      );
    }
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('甲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '移动到…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '近期新闻'));
    await tester.pumpAndSettle();

    expect((await services.local.findById('n1'))!.folderId, 'f1');
    expect((await services.local.findById('n2'))!.folderId, 'f1');
    // 批量操作做完自动退出多选。
    expect(find.text('已选'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('全选按钮把当前列表里的都勾上', (tester) async {
    final services = buildTestServices('ui-test-user');
    for (final (id, body) in [('n1', '甲'), ('n2', '乙')]) {
      await services.local.createNote(
        localNote(id: id, body: body, version: 1, baseVersion: 1, dirty: false),
      );
    }
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('全选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);
  });
}
