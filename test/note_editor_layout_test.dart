import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
import 'package:sync_notes/services/ink_strokes.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/ui/ink_canvas_page.dart';
import 'package:sync_notes/ui/note_edit_page.dart';
import 'package:sync_notes/ui/widgets/ink_view.dart';

import 'support/fake_store.dart';

/// 编辑页里内嵌块的排版测试。
///
/// 这里出过两次很难看的 bug：图片往上溢出去盖住文字；块级内嵌拿到「撑满整行」
/// 的紧约束，被拉变形还在整行里居中。两条都在这里钉住。
void main() {
  const imageId = '55555555-5555-5555-5555-555555555555';

  /// 造一张真图片，图片内嵌才能拿到路径渲染出来。
  String writeSampleImage() {
    final image = img.Image(width: 900, height: 600);
    final file = File(
      p.join(Directory.systemTemp.path, 'sync-notes-layout-sample.png'),
    );
    file.writeAsBytesSync(img.encodePng(image));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    return file.path;
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    String body, {
    bool withImageFile = true,
  }) async {
    final local = FakeLocalStore()..device = 'layout-test';
    final at = DateTime.now();
    local.notes['n1'] = LocalNote(
      id: 'n1',
      body: body,
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );
    local.images[imageId] = LocalImage(
      id: imageId,
      storagePath: 'demo/$imageId.jpg',
      byteSize: 1024,
      width: 900,
      height: 600,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );
    if (withImageFile) local.imageRealPaths[imageId] = writeSampleImage();

    final remote = FakeRemoteApi();
    final engine = SyncEngine(local: local, remote: remote);
    await tester.pumpWidget(
      AppScope(
        services: AppServices(
          userId: 'layout-test',
          local: local,
          remote: remote,
          engine: engine,
          sync: SyncController(engine: engine, remote: remote, local: local),
        ),
        child: MaterialApp(
          // 工具栏要 Quill 的本地化代理，缺了会变成一块灰条。
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NoteEditPage(noteId: 'n1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('图片按原始比例排版，靠左，不撑满整行', (tester) async {
    await pumpEditor(tester, '第一行\n[[img:$imageId]]\n第二行');

    final image = tester.getRect(find.byType(Image));
    final editor = tester.getRect(find.byType(QuillEditor));

    // 900×600 的图缩到 300×200，既没被拉伸也没被压扁。
    expect(image.width, closeTo(300, 0.5));
    expect(image.height, closeTo(200, 0.5));
    expect(
      image.left,
      closeTo(editor.left, 1),
      reason: '图片应该贴着正文左边，实际偏了 ${image.left - editor.left}',
    );
    expect(image.right, lessThan(editor.right - 100));
  });

  testWidgets('图片独占一行，不会压住前面那行文字', (tester) async {
    await pumpEditor(tester, '第一行\n[[img:$imageId]]\n第二行');

    final image = tester.getRect(find.byType(Image));
    final firstLine = tester.getRect(find.text('第一行', findRichText: true));
    final lastLine = tester.getRect(find.text('第二行', findRichText: true));

    // 图片整块排在第一行下面、第二行上面。
    expect(
      image.top,
      greaterThanOrEqualTo(firstLine.bottom - 0.5),
      reason: '图片压住了上面的文字',
    );
    expect(image.bottom, lessThanOrEqualTo(lastLine.top + 0.5));
  });

  testWidgets('图片文件还没下回来时也会占住位置', (tester) async {
    await pumpEditor(tester, '[[img:$imageId]]\n后面的文字', withImageFile: false);

    // 没有文件就画占位框，尺寸同样按比例算出来，正文不会跳。
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    final text = tester.getRect(find.text('后面的文字', findRichText: true));
    final editor = tester.getRect(find.byType(QuillEditor));
    expect(text.top, greaterThan(editor.top + 100));
  });

  testWidgets('手写块按画布比例显示，点一下能进画布页', (tester) async {
    const inkId = '66666666-6666-6666-6666-666666666666';
    final local = FakeLocalStore()..device = 'layout-test';
    final at = DateTime.now();
    local.notes['n1'] = LocalNote(
      id: 'n1',
      body: '标题\n[[ink:$inkId]]\n',
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );
    local.inks[inkId] = LocalInk(
      id: inkId,
      strokes: encodeInkStrokes(const [
        InkStroke(
          color: 0xFF1976D2,
          width: 6,
          points: [InkPoint(0.2, 0.3), InkPoint(0.7, 0.6)],
        ),
      ]),
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );

    final remote = FakeRemoteApi();
    final engine = SyncEngine(local: local, remote: remote);
    await tester.pumpWidget(
      AppScope(
        services: AppServices(
          userId: 'layout-test',
          local: local,
          remote: remote,
          engine: engine,
          sync: SyncController(engine: engine, remote: remote, local: local),
        ),
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NoteEditPage(noteId: 'n1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 块级内嵌拿到的是撑满整行的紧约束，不套 Align 画布会被拉成横宽的一条。
    final canvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is InkPainter,
    );
    expect(canvas, findsOneWidget);
    final size = tester.getSize(canvas);
    expect(
      size.width / size.height,
      closeTo(inkCanvasWidth / inkCanvasHeight, 0.02),
      reason: '手写块被拉变形了，实测尺寸 $size',
    );

    // 编辑器自己也在抢点击手势，这里确认点到的是画布而不是把光标移过去。
    await tester.tap(canvas);
    await tester.pumpAndSettle();
    expect(find.byType(InkCanvasPage), findsOneWidget);
  });

  testWidgets('插图之后接着打的字排在图片下面', (tester) async {
    await pumpEditor(tester, '第一行');
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    final controller = editor.controller;

    // 走和「插入图片」菜单一样的路子：插块，光标停到返回的位置，然后接着打字。
    final caret = RichBody.insertBlockEmbed(
      controller.document,
      controller.document.length - 1,
      BlockEmbed.image(imageId),
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: caret),
      ChangeSource.local,
    );
    const typed = '图片下面的字';
    controller.document.insert(caret, typed);
    controller.updateSelection(
      TextSelection.collapsed(offset: caret + typed.length),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();

    final image = tester.getRect(find.byType(Image));
    final text = tester.getRect(find.text(typed, findRichText: true));
    expect(
      text.top,
      greaterThanOrEqualTo(image.bottom - 0.5),
      reason: '打出来的字跑到图片上面去了',
    );
  });

  testWidgets('光标跑到看不见的地方，视图会跟着滚过去', (tester) async {
    final long = List.generate(80, (i) => '第 $i 行，把正文撑得比一屏长').join('\n');
    await pumpEditor(tester, long);

    final state = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(state.position.pixels, 0);

    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    final end = controller.document.length - 1;
    controller.document.insert(end, '在文末新写的一行');
    controller.updateSelection(
      TextSelection.collapsed(offset: end + 4),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();

    expect(state.position.pixels, greaterThan(0), reason: '光标在文末，视图应该跟着往下滚');
  });

  testWidgets('点正文下面的空白处，光标照样落在文末', (tester) async {
    await pumpEditor(tester, '第一行');
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    final viewport = tester.getRect(find.byType(SingleChildScrollView));

    // 正文只有一行，编辑器自己要铺满一屏，下面那片空白点下去也应该落光标。
    await tester.tapAt(Offset(viewport.center.dx, viewport.bottom - 40));
    await tester.pumpAndSettle();

    expect(
      controller.selection.baseOffset,
      controller.document.length - 1,
      reason: '点空白处没把光标放到文末',
    );
  });

  testWidgets('拖着选到窗口下边缘，正文会自动往下滚', (tester) async {
    final long = List.generate(80, (i) => '第 $i 行，把正文撑得比一屏长').join('\n');
    await pumpEditor(tester, long);

    final state = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    final editor = tester.getRect(find.byType(QuillEditor));
    final gesture = await tester.startGesture(
      Offset(editor.center.dx, editor.top + 30),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    // 拖到可见区域外面，手指/鼠标停在那儿不动，正文应该自己往下走。
    await gesture.moveTo(Offset(editor.center.dx, editor.bottom + 40));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final scrolled = state.position.pixels;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scrolled, greaterThan(50), reason: '拖着选到边缘没有自动滚动，实测滚了 $scrolled');

    // 松手之后不能再自己滚。
    final afterRelease = state.position.pixels;
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.position.pixels, afterRelease);
  });

  testWidgets('打开老笔记会顺手把正文升级成富文本存回去', (tester) async {
    final local = FakeLocalStore()..device = 'layout-test';
    final at = DateTime.now();
    local.notes['n1'] = LocalNote(
      id: 'n1',
      body: '老格式的笔记',
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );
    final remote = FakeRemoteApi();
    final engine = SyncEngine(local: local, remote: remote);
    final services = AppServices(
      userId: 'layout-test',
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
          home: const NoteEditPage(noteId: 'n1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saved = (await local.findById('n1'))!;
    expect(saved.body, startsWith('['));
    expect(RichBody.documentFrom(saved.body).toPlainText(), contains('老格式的笔记'));
  });
}
