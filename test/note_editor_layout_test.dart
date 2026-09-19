import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:sync_notes/ui/image_preview_page.dart';
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
    TargetPlatform? platform,
    double keyboardInset = 0,
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
    if (keyboardInset > 0) {
      // 假装输入法已经开着：系统就是通过 viewInsets 把键盘高度报上来的。
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
      addTearDown(tester.view.reset);
    }

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
          theme: platform == null ? null : ThemeData(platform: platform),
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

  testWidgets('点正文里的图片能打开大图预览，滚轮能放大', (tester) async {
    await pumpEditor(tester, '看图\n[[img:$imageId]]\n');

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewPage), findsOneWidget);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = viewer.transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), 1);

    // 鼠标滚轮往上滚＝放大。
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();

    expect(
      transform.value.getMaxScaleOnAxis(),
      greaterThan(1.2),
      reason: '滚轮没有放大图片',
    );

    // 「适应屏幕」把缩放还原。
    await tester.tap(find.byTooltip('适应屏幕'));
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), 1);
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

  testWidgets('从菜单插入手写之后，光标落在画布下面', (tester) async {
    await pumpEditor(tester, '第一行');
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    final controller = editor.controller;

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('插入手写'));
    await tester.pumpAndSettle();
    expect(find.byType(InkCanvasPage), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 光标要落在画布下面那一行：接着打的字应该排在画布后面。
    final caret = controller.selection.baseOffset;
    controller.document.insert(caret, '画布下面');
    expect(
      controller.document.toPlainText(),
      '第一行\n\uFFFC\n画布下面\n',
      reason: '光标没落在画布下面那一行',
    );
    expect(editor.focusNode.hasFocus, isTrue, reason: '插完画布焦点要回到编辑器');
  });

  testWidgets('插入手写画布之后，再点它还能打开画布页', (tester) async {
    await pumpEditor(tester, '第一行');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('插入手写'));
    await tester.pumpAndSettle();

    // 在画布上随手画一笔，插进正文的才是真笔画而不是空画布。
    final surface = tester.getRect(find.byType(InkCanvasPage));
    await tester.dragFrom(
      surface.center - const Offset(40, 0),
      const Offset(80, 40),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final canvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is InkPainter,
    );
    expect(canvas, findsOneWidget);

    await tester.tap(canvas);
    await tester.pumpAndSettle();
    expect(
      find.byType(InkCanvasPage),
      findsOneWidget,
      reason: '点正文里的手写块没打开画布页',
    );
  });

  testWidgets('「回到光标」把看不见的光标拉回屏幕中间', (tester) async {
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
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;

    // 光标放到文末，再把视图拖回顶部，模拟「光标被翻到看不见的地方」。
    final end = controller.document.length - 1;
    controller.updateSelection(
      TextSelection.collapsed(offset: end),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();
    state.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(state.position.pixels, 0);

    await tester.tap(find.byTooltip('回到光标'));
    await tester.pumpAndSettle();

    expect(state.position.pixels, greaterThan(0), reason: '「回到光标」没把光标滚回来');
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

  testWidgets('往下滚看内容之后，页面不会自己弹回光标那里', (tester) async {
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
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;

    // 光标放文末，视图跟着滚下去——这是「滚回去」的目标位置。
    final end = controller.document.length - 1;
    controller.updateSelection(
      TextSelection.collapsed(offset: end),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();
    final caretOffset = state.position.pixels;
    expect(caretOffset, greaterThan(100));

    // 手指往下推，回头去看前面的内容（视图离底部越远，越能看出有没有弹回去）。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SingleChildScrollView)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 16));
    // 分几步慢慢推：末速度接近零，松手后就该停在原地。
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final beforeRelease = state.position.pixels;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      state.position.pixels,
      closeTo(beforeRelease, 2),
      reason: '松手之后页面又弹回光标那里了',
    );
    expect(beforeRelease, lessThan(caretOffset - 100), reason: '这一下没滚动起来');
  });

  testWidgets('安卓上轻点不弹输入法，双击才弹', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    await pumpEditor(tester, '第一行\n第二行', platform: TargetPlatform.android);
    calls.clear();

    await tester.tap(find.byType(QuillEditor));
    await tester.pumpAndSettle();
    expect(
      calls.where((call) => call == 'TextInput.show'),
      isEmpty,
      reason: '轻点一下就唤起输入法了',
    );
    expect(calls, contains('TextInput.hide'));

    // 紧接着再点一下就是双击，这次要弹。
    calls.clear();
    await tester.tap(find.byType(QuillEditor));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byType(QuillEditor));
    await tester.pumpAndSettle();
    // flutter_quill 双击之后还会排一个「显示选区菜单」的回调。留着不跑，
    // 它会落在测试结束、树已经拆掉之后，然后崩在一个空引用上。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, contains('TextInput.show'), reason: '双击没唤起输入法');
  });

  testWidgets('安卓上选区菜单不会盖住格式栏', (tester) async {
    await pumpEditor(tester, '第一行\n第二行', platform: TargetPlatform.android);
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;

    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    tester
        .state<QuillRawEditorState>(find.byType(QuillRawEditor))
        .showToolbar();
    await tester.pumpAndSettle();

    final toolbar = tester.getRect(find.byType(QuillSimpleToolbar));
    // 量菜单里的按钮，不量 AdaptiveTextSelectionToolbar 本身：
    // 那一层铺满整屏，量它的框量不出可见位置。
    final menu = tester.getRect(
      find
          .descendant(
            of: find.byType(AdaptiveTextSelectionToolbar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      menu.top,
      greaterThanOrEqualTo(toolbar.bottom),
      reason: '浮动菜单盖在格式栏上了',
    );
    // 选区就在格式栏下面，上方放不下，菜单应该翻到选区下方去，
    // 而且要让出选区两端的抓手（抓手大约 22 高）。
    final selectedLine = tester.getRect(find.text('第一行', findRichText: true));
    expect(
      menu.top,
      greaterThanOrEqualTo(selectedLine.bottom + 20),
      reason: '浮动菜单压在选区或者抓手上',
    );
  });

  testWidgets('选区上方有地方时，菜单待在格式栏和选区之间', (tester) async {
    final long = List.generate(60, (i) => '第 $i 行，把正文撑得比一屏长').join('\n');
    await pumpEditor(tester, long, platform: TargetPlatform.android);
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;

    // 点屏幕中间那行，让选区上方空出一大截。
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    await tester.tapAt(Offset(viewport.center.dx, viewport.top + 220));
    await tester.pumpAndSettle();
    final caret = controller.selection.baseOffset;
    controller.updateSelection(
      TextSelection(baseOffset: caret, extentOffset: caret + 3),
      ChangeSource.local,
    );
    tester
        .state<QuillRawEditorState>(find.byType(QuillRawEditor))
        .showToolbar();
    await tester.pumpAndSettle();

    final toolbar = tester.getRect(find.byType(QuillSimpleToolbar));
    final menu = tester.getRect(
      find
          .descendant(
            of: find.byType(AdaptiveTextSelectionToolbar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      menu.top,
      greaterThanOrEqualTo(toolbar.bottom),
      reason: '浮动菜单盖在格式栏上了',
    );
    expect(
      menu.bottom,
      lessThanOrEqualTo(viewport.top + 220 - 20),
      reason: '浮动菜单压住了选区或者起始抓手',
    );
  });

  testWidgets('选区菜单里的「选择」把选区重新点亮，抓手才有得拖', (tester) async {
    await pumpEditor(tester, '第一行文字\n第二行文字', platform: TargetPlatform.android);
    final controller = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    final state = tester.state<QuillRawEditorState>(
      find.byType(QuillRawEditor),
    );

    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    state.showToolbar();
    await tester.pumpAndSettle();
    expect(find.text('选择'), findsOneWidget);

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    // 选区还在（没被点成光标），菜单也重新摆出来了。
    expect(controller.selection.isCollapsed, isFalse);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(controller.selection.start, 0);
    expect(controller.selection.end, greaterThanOrEqualTo(4));
  });

  testWidgets('拖选的时候输入法被摁住，不会一次次往上顶', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    await pumpEditor(
      tester,
      '第一行文字，拿来拖选\n第二行文字',
      platform: TargetPlatform.android,
      keyboardInset: 300,
    );
    calls.clear();

    // 鼠标从左往右拖过第一行，选中一段字。
    final line = tester.getRect(find.text('第一行文字，拿来拖选', findRichText: true));
    final gesture = await tester.startGesture(
      line.centerLeft + const Offset(4, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls, contains('TextInput.hide'), reason: '拖选过程中输入法没被摁住');
  });

  testWidgets('点完菜单里的按钮，焦点收回来、键盘也不会又弹出来', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    await pumpEditor(tester, '第一行文字\n第二行文字', platform: TargetPlatform.android);
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    final controller = editor.controller;
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    tester
        .state<QuillRawEditorState>(find.byType(QuillRawEditor))
        .showToolbar();
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    calls.clear();

    // 点菜单里的「复制」。
    await tester.tap(find.text('Copy'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(editor.focusNode.hasFocus, isTrue, reason: '点完菜单没把焦点收回来');
    expect(calls, contains('TextInput.hide'), reason: '点完菜单键盘又冒出来了');
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
