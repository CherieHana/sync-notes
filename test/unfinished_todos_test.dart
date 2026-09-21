import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/ui/note_edit_page.dart';
import 'package:sync_notes/ui/unfinished_page.dart';
import 'package:sync_notes/util/note_text.dart';

import 'support/fake_store.dart';
import 'support/test_app.dart';

/// 拼一篇正文：每行标一个「这行是什么」。
///
/// 列表属性在 Quill 里是挂在**换行**上的（`ResolveLineFormatRule` 只往
/// 换行字符上加行级属性），所以这里也照着这个形状拼。
String bodyOf(List<(String line, String? list)> lines) => jsonEncode([
  for (final (line, list) in lines)
    if (list == null)
      {'insert': '$line\n'}
    else ...[
      {'insert': line},
      {
        'insert': '\n',
        'attributes': {'list': list},
      },
    ],
]);

/// 勾选框 + 「未完成」汇总页。
void main() {
  group('未勾选的待办解析', () {
    test('只挑没勾上的行：已勾选、项目符号、普通段落都不算', () {
      final body = bodyOf([
        ('购物清单', null),
        ('牛奶', 'unchecked'),
        ('鸡蛋', 'checked'),
        ('只是要点', 'bullet'),
        ('第一项', 'ordered'),
        ('交周报', 'unchecked'),
      ]);

      expect(uncheckedItems(body), ['牛奶', '交周报']);
      expect(uncheckedCount(body), 2);
    });

    test('位置指向那一行的开头，点进去时光标落得准', () {
      final body = bodyOf([('购物清单', null), ('牛奶', 'unchecked')]);
      final todo = uncheckedTodos(body).single;

      expect(todo.text, '牛奶');
      expect(notePlainText(body).substring(todo.offset), startsWith('牛奶'));
    });

    test('老格式的纯文本正文没有勾选框，返回空', () {
      expect(uncheckedItems('购物清单\n牛奶\n鸡蛋'), isEmpty);
      expect(uncheckedCount(''), 0);
      expect(
        uncheckedCount('[[img:11111111-1111-1111-1111-111111111111]]'),
        0,
      );
    });

    test('用编辑器自己的接口打勾选框，解析器也认', () {
      final document = RichBody.documentFrom('购物清单\n牛奶\n面包\n');
      final start = document.toPlainText().indexOf('牛奶');
      // 工具栏是拿「光标位置 + 选区长度」去套属性的；光标不带选区时长度是 0，
      // 这时行级属性只会落到光标这一行的换行上（Quill 的 ResolveLineFormatRule）。
      document.format(start, 0, const ListAttribute('unchecked'));

      final body = RichBody.encode(document);
      expect(uncheckedItems(body), ['牛奶']);

      // 勾上之后就不再算「未完成」。
      document.format(start, 0, const ListAttribute('checked'));
      expect(uncheckedItems(RichBody.encode(document)), isEmpty);
    });
  });

  testWidgets('列表行上的角标显示还没勾上的条数', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: bodyOf([
          ('购物清单', null),
          ('牛奶', 'unchecked'),
          ('鸡蛋', 'unchecked'),
          ('面包', 'checked'),
        ]),
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    expect(find.text('☑ 2'), findsOneWidget, reason: '勾上的那行不该算进角标');
  });

  testWidgets('加锁且没解锁的笔记不解析正文，也不显示角标', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'locked',
        body: bodyOf([('私密标题', null), ('偷偷记的待办', 'unchecked')]),
        version: 1,
        baseVersion: 1,
        dirty: false,
        locked: true,
        passphraseHash: 'hash',
        passphraseSalt: 'salt',
      ),
    );
    await pumpWithServices(tester, services);

    expect(find.text('私密标题'), findsOneWidget);
    expect(find.textContaining('☑'), findsNothing);
  });

  testWidgets('未完成汇总页按笔记分组列出，点一条能打开那篇笔记', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: bodyOf([('购物清单', null), ('牛奶', 'unchecked')]),
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await services.local.createNote(
      localNote(
        id: 'n2',
        body: bodyOf([('本周', null), ('交周报', 'unchecked')]),
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    // 菜单项上带着总数。
    expect(find.text('未完成（2）'), findsOneWidget);
    await tester.tap(find.text('未完成（2）'));
    await tester.pumpAndSettle();

    expect(find.byType(UnfinishedPage), findsOneWidget);
    // 两篇笔记的未勾选项都列出来了，各自带自己的标题。
    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('购物清单'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);

    // 点一条 → 打开那篇笔记，光标落在这一行上。
    await tester.tap(find.text('交周报'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditPage), findsOneWidget);

    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    final offset = editor.controller.selection.baseOffset;
    expect(offset, greaterThan(0), reason: '光标应该落在待办那一行上');
    final plain = editor.controller.document.toPlainText();
    expect(plain.substring(offset), startsWith('交周报'));
  });

  testWidgets('一条未完成都没有时，汇总页给一句提示', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: '普通笔记，没有待办',
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    // 没有未完成项时菜单上不带数字。
    await tester.tap(find.text('未完成'));
    await tester.pumpAndSettle();

    expect(find.text('没有未完成的勾选项'), findsOneWidget);
  });
}
