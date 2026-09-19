import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/ui/widgets/inline_note_controller.dart';

void main() {
  const idA = '11111111-1111-1111-1111-111111111111';
  const inkA = '33333333-3333-3333-3333-333333333333';

  const placeholder = InlineNoteController.placeholder;

  List<String> idsOf(List<EmbedRef> embeds) =>
      embeds.map((e) => e.id).toList();

  /// 测试里用的控制器：不给任何真实数据，只验证文档与编辑态的互转。
  InlineNoteController controllerWith(List<EmbedRef> embeds) =>
      InlineNoteController(
        embedsOf: () => embeds,
        imageInfoOf: (_) => const InlineImageInfo(),
        inkInfoOf: (_) => const InlineInkInfo(),
      );

  test('文档转编辑态：标记变成占位符，顺序和种类都记下来', () {
    final result = InlineNoteController.toDisplay(
      '标题\n[[img:$idA]]\n中间\n[[ink:$inkA]]',
    );
    expect(
      result.display,
      '标题\n$placeholder\n中间\n$placeholder',
    );
    expect(result.embeds.map((e) => e.kind), [
      EmbedKind.image,
      EmbedKind.ink,
    ]);
    expect(idsOf(result.embeds), [idA, inkA]);
  });

  test('编辑态转回文档，图片和手写各归各的标记', () {
    const body = '标题\n[[img:$idA]]\n正文\n[[ink:$inkA]]';
    final display = InlineNoteController.toDisplay(body);
    expect(
      InlineNoteController.toDocument(display.display, display.embeds),
      body,
    );
  });

  test('删掉一个占位符，对应的块也被摘掉', () {
    final display = InlineNoteController.toDisplay(
      '前\n[[img:$idA]]\n中\n[[ink:$inkA]]\n后',
    );
    final edited = display.display.replaceFirst(placeholder, '');

    final embeds = InlineNoteController.embedsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      embeds: display.embeds,
    );

    expect(idsOf(embeds), [inkA]);
  });

  test('只改文字不会动内嵌块', () {
    final display = InlineNoteController.toDisplay('标题\n[[img:$idA]]\n正文');
    const edited = '标题改过了\n$placeholder\n正文也改了';

    final embeds = InlineNoteController.embedsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      embeds: display.embeds,
    );

    expect(idsOf(embeds), [idA]);
  });

  test('在末尾打字不会误伤前面的块', () {
    final display = InlineNoteController.toDisplay('[[img:$idA]]\n正文');
    final edited = '${display.display}又写了一句';

    final embeds = InlineNoteController.embedsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      embeds: display.embeds,
    );

    expect(idsOf(embeds), [idA]);
  });

  test('一次性删掉两个块，两个都摘掉', () {
    final display = InlineNoteController.toDisplay(
      '[[img:$idA]][[ink:$inkA]]结尾',
    );

    final embeds = InlineNoteController.embedsAfterEdit(
      oldDisplay: display.display,
      newDisplay: '结尾',
      embeds: display.embeds,
    );

    expect(embeds, isEmpty);
  });

  test('没有记录撑着的占位符会在转回文档时被丢掉', () {
    expect(InlineNoteController.toDocument('正文$placeholder', const []), '正文');
  });

  group('渲染', () {
    late BuildContext context;

    Future<void> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('占位符会换成组件，而不是把原始字符画出来', (tester) async {
      await pumpContext(tester);
      final controller = controllerWith(const [EmbedRef.image(idA)]);
      controller.text = '前$placeholder后';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      final widgets = span.children!.whereType<WidgetSpan>().toList();

      // 这里曾经出过问题：控制器从编辑态文本里找 id，而编辑态里只有占位符，
      // 结果一个组件都没生成，界面上显示成一排「OBJ」方块。
      expect(widgets, hasLength(1));
    });

    testWidgets('手写块也会渲染成组件', (tester) async {
      await pumpContext(tester);
      final controller = controllerWith(const [EmbedRef.ink(inkA)]);
      controller.text = '前$placeholder后';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      expect(span.children!.whereType<WidgetSpan>(), hasLength(1));
    });

    testWidgets('渲染出来的文本长度和编辑内容完全一致', (tester) async {
      await pumpContext(tester);
      final controller = controllerWith(const [
        EmbedRef.image(idA),
        EmbedRef.ink(inkA),
      ]);
      controller.text = '前$placeholder中$placeholder后';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      // WidgetSpan 只顶一个字符，长度对不上光标就会错位。
      expect(span.toPlainText().length, controller.text.length);
    });

    testWidgets('没有对应记录的占位符也占住一个字符', (tester) async {
      await pumpContext(tester);
      final controller = controllerWith(const []);
      controller.text = '异常$placeholder情况';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      expect(span.children!.whereType<WidgetSpan>(), hasLength(1));
      expect(span.toPlainText().length, controller.text.length);
    });
  });
}
