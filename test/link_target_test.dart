import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
import 'package:sync_notes/services/file_import.dart';
import 'package:sync_notes/services/link_target.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/ui/note_edit_page.dart';

import 'support/fake_store.dart';

/// 给桩用的「选中的文件」。PlatformFile 是 base class，只能在库外继承。
final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.path);

  @override
  final String name;

  @override
  final String path;

  @override
  Uri get uri => Uri.file(path);

  @override
  XFile get xFile => XFile(path);

  @override
  int? lengthSync() => 0;

  @override
  Future<int?> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

/// 正文里带链接的那几段。
List<({String text, String link})> linksIn(Document document) => [
  for (final op in document.toDelta().toList())
    if (op.attributes?[Attribute.link.key] != null && op.data is String)
      (text: op.data! as String, link: op.attributes![Attribute.link.key]!),
];

String bodyWithLink(String text, String url) => jsonEncode([
  {
    'insert': text,
    'attributes': {'link': url},
  },
  {'insert': '\n'},
]);

void main() {
  group('链接指向哪里', () {
    test('http / https 归到网页', () {
      expect(classifyLink('https://example.com/a?b=1'), LinkKind.http);
      expect(classifyLink('http://example.com'), LinkKind.http);
      expect(classifyLink('  https://example.com  '), LinkKind.http);
    });

    test('file 协议和裸的绝对路径都归到本机文件', () {
      expect(classifyLink('file:///C:/Users/me/a.txt'), LinkKind.file);
      expect(classifyLink(r'C:\Users\me\a.txt'), LinkKind.file);
      expect(classifyLink(r'D:\图片\签名.png'), LinkKind.file);
      expect(classifyLink('/Users/me/a.txt'), LinkKind.file);
    });

    test('别的协议原样交给系统', () {
      expect(classifyLink('tg://resolve?domain=x'), LinkKind.other);
      expect(classifyLink('mailto:me@example.com'), LinkKind.other);
      expect(classifyLink(''), LinkKind.other);
    });

    test('路径 → 链接 → 路径 转一圈还是原来那个', () {
      const path = r'C:\Users\me\我的文档\报告.pdf';
      final url = fileLinkUrl(path);
      expect(url, startsWith('file:///'));
      expect(filePathFromLink(url), path);
      // 网页链接不是文件。
      expect(filePathFromLink('https://example.com/a.txt'), isNull);
    });

    test('交给系统之前，文件链接不会被补上 https://', () {
      const path = r'C:\Users\me\报告.pdf';
      // 编辑器的默认规则会把 file:///… 改成 https://file:///…，那样根本打不开。
      expect(normalizeLink(fileLinkUrl(path)), fileLinkUrl(path));
      expect(normalizeLink('https://example.com/a'), 'https://example.com/a');
      expect(normalizeLink('tg://resolve'), 'tg://resolve');
      // 光秃秃的域名才补协议，不然浏览器不认。
      expect(normalizeLink('example.com'), 'https://example.com');
    });
  });

  group('编辑页里的链接', () {
    late List<String> opened;
    late String? openError;

    setUp(() {
      opened = [];
      openError = null;
      // 真去调浏览器/系统程序在测试里没法验证，换成桩。
      linkOpener = (url) async {
        opened.add(url);
        return openError;
      };
    });

    tearDown(() {
      linkOpener = defaultLinkOpener;
      filePicker = systemFilePicker;
    });

    Future<AppServices> pumpEditor(
      WidgetTester tester,
      String body, {
      TargetPlatform platform = TargetPlatform.windows,
    }) async {
      final local = FakeLocalStore()..device = 'link-test';
      await local.createNote(
        localNote(
          id: 'n1',
          body: body,
          version: 1,
          baseVersion: 1,
          dirty: false,
        ),
      );
      final remote = FakeRemoteApi();
      final engine = SyncEngine(local: local, remote: remote);
      final services = AppServices(
        userId: 'link-test',
        local: local,
        remote: remote,
        engine: engine,
        sync: SyncController(engine: engine, remote: remote, local: local),
      );
      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            // 「点一下链接是打开它还是放光标」按平台分岔：电脑上打开，
            // 手机上留给放光标。测试里直接指定平台，不用去改全局变量。
            theme: ThemeData(platform: platform),
            home: const NoteEditPage(noteId: 'n1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return services;
    }

    /// 打开 ⋮ 菜单里的一项。
    Future<void> tapMenuItem(WidgetTester tester, String label) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    /// 点链接文字。整行的 RichText 铺满一行，中心点常常落在字右边的空白上，
    /// 所以从它左上角往里挪一点点，确保落在字的笔画上。
    Future<void> tapLink(WidgetTester tester, String text) async {
      final rect = tester.getRect(find.text(text, findRichText: true));
      await tester.tapAt(rect.topLeft + Offset(4, rect.height / 2));
    }

    /// 长按链接文字，同样要按在字上而不是整行的空白处。
    Future<void> longPressLink(WidgetTester tester, String text) async {
      final rect = tester.getRect(find.text(text, findRichText: true));
      final gesture = await tester.startGesture(
        rect.topLeft + Offset(4, rect.height / 2),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('电脑上点一下网址就打开浏览器', (tester) async {
      await pumpEditor(tester, bodyWithLink('官网', 'https://example.com/page'));

      await tapLink(tester, '官网');
      await tester.pumpAndSettle();

      expect(opened.single, 'https://example.com/page');
    });

    testWidgets('文件链接走的是打开本机文件那条路', (tester) async {
      const path = r'C:\Users\me\报告.pdf';
      await pumpEditor(tester, bodyWithLink('报告.pdf', fileLinkUrl(path)));

      await tapLink(tester, '报告.pdf');
      await tester.pumpAndSettle();

      expect(opened.single, fileLinkUrl(path));
      expect(classifyLink(opened.single), LinkKind.file);
    });

    testWidgets('打不开的时候把原因说给用户听', (tester) async {
      openError = '这个文件只在那台设备上有';

      await pumpEditor(tester, bodyWithLink('报告.pdf', fileLinkUrl(r'C:\a.pdf')));
      await tapLink(tester, '报告.pdf');
      await tester.pumpAndSettle();

      expect(find.text('这个文件只在那台设备上有'), findsOneWidget);
    });

    testWidgets('手机上点链接只是放光标，不打开（长按才弹菜单）', (tester) async {
      await pumpEditor(
        tester,
        bodyWithLink('官网', 'https://example.com/page'),
        platform: TargetPlatform.android,
      );

      await tapLink(tester, '官网');
      await tester.pumpAndSettle();

      expect(opened, isEmpty, reason: '手机上点一下要留给放光标');
    });

    testWidgets('手机上长按链接弹出中文菜单，选「打开链接」才打开', (tester) async {
      await pumpEditor(
        tester,
        bodyWithLink('官网', 'https://example.com/page'),
        platform: TargetPlatform.android,
      );

      await longPressLink(tester, '官网');

      expect(find.text('打开链接'), findsOneWidget);
      expect(find.text('复制链接'), findsOneWidget);
      expect(find.text('删除链接'), findsOneWidget);
      expect(opened, isEmpty, reason: '光是弹菜单不该打开');

      await tester.tap(find.text('打开链接'));
      await tester.pumpAndSettle();
      expect(opened.single, 'https://example.com/page');
    });

    testWidgets('插入日期：写进当天的年月日', (tester) async {
      await pumpEditor(tester, '标题');
      await tapMenuItem(tester, '插入日期');

      final now = DateTime.now();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}';

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(editor.controller.document.toPlainText(), contains(stamp));
    });

    testWidgets('插入日期时间：年月日 + 时分', (tester) async {
      await pumpEditor(tester, '标题');
      await tapMenuItem(tester, '插入日期时间');

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final text = editor.controller.document.toPlainText();
      expect(
        RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}').hasMatch(text),
        isTrue,
        reason: '正文里没看到日期时间：$text',
      );
    });

    testWidgets('插入文件链接：显示文件名，指向本机路径', (tester) async {
      const path = r'C:\Users\me\我的资料\季度报告.pdf';
      // 系统文件框换成桩，不然测试会真的弹框。
      filePicker = ({type = FileType.any, allowedExtensions}) async => [
        _PickedFile('季度报告.pdf', path),
      ];

      await pumpEditor(tester, '标题');
      await tapMenuItem(tester, '插入文件链接…');

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final link = linksIn(editor.controller.document).single;
      expect(link.text, '季度报告.pdf', reason: '显示文字要用文件名');
      expect(link.link, fileLinkUrl(path));
      // 链接也在正文里存下来了，跟着同步走。
      expect(
        RichBody.encode(editor.controller.document),
        contains('季度报告.pdf'),
      );
    });

    testWidgets('格式栏里有项目符号、编号、勾选框和插入链接', (tester) async {
      await pumpEditor(tester, '标题');

      // 这几个是这一版新放出来的按钮，少一个用户就找不到功能入口。
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('插入链接的弹框：填个光秃秃的域名也能点确定', (tester) async {
      await pumpEditor(tester, '标题');

      // 选中「标题」，链接就包住这段字。
      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
        ChangeSource.local,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.link));
      await tester.pumpAndSettle();

      // 两个输入框：显示文字（已经带上选中的「标题」）和网址。
      await tester.enterText(find.byType(TextFormField).last, 'www.example.com');
      await tester.pumpAndSettle();

      final okButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      expect(
        tester.widget<TextButton>(okButton).onPressed,
        isNotNull,
        reason: '填了网址，「确定」不该还是灰的（上一版点了没反应就是这个原因）',
      );

      await tester.tap(okButton);
      await tester.pumpAndSettle();

      final link = linksIn(editor.controller.document).single;
      expect(link.text, '标题');
      expect(link.link, 'www.example.com');
    });
  });
}
