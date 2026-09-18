import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/ui/widgets/inline_note_controller.dart';

void main() {
  const idA = '11111111-1111-1111-1111-111111111111';
  const idB = '22222222-2222-2222-2222-222222222222';

  test('文档转编辑态：标记变成占位符，顺序记下来', () {
    final result = InlineNoteController.toDisplay(
      '标题\n[[img:$idA]]\n中间\n[[img:$idB]]',
    );
    expect(result.ids, [idA, idB]);
    expect(result.display, '标题\n${InlineNoteController.placeholder}\n中间\n${InlineNoteController.placeholder}');
    expect(InlineNoteController.countPlaceholders(result.display), 2);
  });

  test('编辑态转回文档，两边能来回对上', () {
    const body = '标题\n[[img:$idA]]\n正文';
    final display = InlineNoteController.toDisplay(body);
    expect(
      InlineNoteController.toDocument(display.display, display.ids),
      body,
    );
  });

  test('删掉一个占位符，对应那张图也被摘掉', () {
    final display = InlineNoteController.toDisplay(
      '前\n[[img:$idA]]\n中\n[[img:$idB]]\n后',
    );
    // 模拟用户删掉第一个占位符
    final edited = display.display.replaceFirst(
      InlineNoteController.placeholder,
      '',
    );

    final ids = InlineNoteController.idsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      ids: display.ids,
    );

    expect(ids, [idB]);
  });

  test('只改文字不会动图片记录', () {
    final display = InlineNoteController.toDisplay('标题\n[[img:$idA]]\n正文');
    const edited = '标题改过了\n${InlineNoteController.placeholder}\n正文也改了';

    final ids = InlineNoteController.idsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      ids: display.ids,
    );

    expect(ids, [idA]);
  });

  test('在末尾打字不会误伤前面的图片', () {
    final display = InlineNoteController.toDisplay('[[img:$idA]]\n正文');
    final edited = '${display.display}又写了一句';

    final ids = InlineNoteController.idsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      ids: display.ids,
    );

    expect(ids, [idA]);
  });

  test('一次性删掉两张图，两个 id 都摘掉', () {
    final display = InlineNoteController.toDisplay(
      '[[img:$idA]][[img:$idB]]结尾',
    );
    const edited = '结尾';

    final ids = InlineNoteController.idsAfterEdit(
      oldDisplay: display.display,
      newDisplay: edited,
      ids: display.ids,
    );

    expect(ids, isEmpty);
  });

  test('没有记录撑着的占位符会在转回文档时被丢掉', () {
    const display = '正文${InlineNoteController.placeholder}';
    expect(InlineNoteController.toDocument(display, const []), '正文');
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

    testWidgets('占位符会换成图片组件，而不是把原始字符画出来', (tester) async {
      await pumpContext(tester);
      final controller = InlineNoteController(
        idsOf: () => [idA],
        imageInfoOf: (_) => const InlineImageInfo(),
      );
      controller.text = '前${InlineNoteController.placeholder}后';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      final widgets = span.children!.whereType<WidgetSpan>().toList();

      // 这里曾经出过问题：控制器从编辑态文本里找 id，而编辑态里只有占位符，
      // 结果一个图片组件都没生成，界面上显示成一排「OBJ」方块。
      expect(widgets, hasLength(1));
    });

    testWidgets('渲染出来的文本长度和编辑内容完全一致', (tester) async {
      await pumpContext(tester);
      final controller = InlineNoteController(
        idsOf: () => [idA, idB],
        imageInfoOf: (_) => const InlineImageInfo(),
      );
      controller.text =
          '前${InlineNoteController.placeholder}中${InlineNoteController.placeholder}后';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      // WidgetSpan 只顶一个字符，长度对不上光标就会错位。
      expect(span.toPlainText().length, controller.text.length);
    });

    testWidgets('没有对应记录的占位符也占住一个字符', (tester) async {
      await pumpContext(tester);
      final controller = InlineNoteController(
        idsOf: () => const [],
        imageInfoOf: (_) => const InlineImageInfo(),
      );
      controller.text = '异常${InlineNoteController.placeholder}情况';

      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );

      expect(span.children!.whereType<WidgetSpan>(), hasLength(1));
      expect(span.toPlainText().length, controller.text.length);
    });
  });
}
