import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/util/note_text.dart';

import 'support/fake_store.dart';
import 'support/test_app.dart';

/// 搜索匹配的是正文的**纯文本**，不是存库用的那串 Quill Delta JSON。
///
/// 以前这里直接拿 `note.body` 匹配，结果搜 "insert"、"attributes" 这种
/// 结构词会把所有富文本笔记都命中，用户看到的却是「明明正文里没有这个词」。
void main() {
  final richBody = jsonEncode([
    {'insert': '会议记录\n'},
    {
      'insert': '第二行有关键词',
      'attributes': {'bold': true},
    },
    {'insert': '\n'},
  ]);

  test('纯文本里没有结构词，JSON 里有', () {
    expect(richBody, contains('insert'));
    expect(richBody, contains('attributes'));
    expect(notePlainText(richBody), '会议记录\n第二行有关键词\n');
    expect(notePlainText(richBody), isNot(contains('insert')));
  });

  /// 打开搜索框，搜一个词。
  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  testWidgets('搜结构词不该命中富文本笔记', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: richBody,
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    expect(find.text('会议记录'), findsOneWidget);

    await search(tester, 'insert');

    expect(
      find.text('会议记录'),
      findsNothing,
      reason: '正文里没有 insert 这个词，不该被搜出来',
    );
    expect(find.text('没有匹配「insert」的笔记'), findsOneWidget);
  });

  testWidgets('关键词在第二行也能命中，并给出命中那句当摘要', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: richBody,
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    await search(tester, '关键词');

    expect(find.text('会议记录'), findsOneWidget);
    expect(
      find.text('第二行有关键词'),
      findsOneWidget,
      reason: '摘要位置应该显示命中的那一句',
    );
  });

  testWidgets('老格式的纯文本笔记照样能搜到', (tester) async {
    final services = buildTestServices('ui-test-user');
    await services.local.createNote(
      localNote(
        id: 'n1',
        body: '老笔记标题\n这条还没升级成富文本',
        version: 1,
        baseVersion: 1,
        dirty: false,
      ),
    );
    await pumpWithServices(tester, services);

    await search(tester, '升级');

    expect(find.text('老笔记标题'), findsOneWidget);
  });
}
