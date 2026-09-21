import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/block_style.dart';
import 'package:sync_notes/services/ink_strokes.dart';
import 'package:sync_notes/ui/ink_canvas_page.dart';
import 'package:sync_notes/ui/widgets/ink_view.dart';

/// 手写画布页：横竖屏切换、缩放，以及缩放之后落笔还准不准。
void main() {
  const strokes = [
    InkStroke(
      color: 0xFF000000,
      width: 4,
      points: [InkPoint(0.1, 0.2), InkPoint(0.9, 0.8)],
    ),
  ];

  /// 打开画布页，返回「完成」时弹出的结果。
  Future<InkCanvasResult? Function()> openCanvas(
    WidgetTester tester, {
    int canvasWidth = inkCanvasWidth,
    int canvasHeight = inkCanvasHeight,
    List<InkStroke> initial = strokes,
  }) async {
    InkCanvasResult? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<InkCanvasResult>(
                    MaterialPageRoute(
                      builder: (_) => InkCanvasPage(
                        initialStrokes: initial,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                      ),
                    ),
                  );
                },
                child: const Text('打开画布'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开画布'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  double canvasAspect(WidgetTester tester) => tester
      .widget<AspectRatio>(
        find.descendant(
          of: find.byType(InkCanvasPage),
          matching: find.byType(AspectRatio),
        ),
      )
      .aspectRatio;

  List<InkStroke> paintedStrokes(WidgetTester tester) {
    // 画布页里还有别的 CustomPaint（水波纹之类），只认画笔迹那个。
    // 纸底纹在 painter 上、笔迹在 foregroundPainter 上，所以认后者。
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is InkPainter,
          )
          .first,
    );
    return (paint.foregroundPainter! as InkPainter).strokes;
  }

  testWidgets('切换横竖屏：画布比例变了，笔迹跟着转 90°', (tester) async {
    final result = await openCanvas(tester);
    expect(canvasAspect(tester), closeTo(1000 / 1400, 0.001));

    await tester.tap(find.text('竖屏'));
    await tester.pumpAndSettle();

    expect(canvasAspect(tester), closeTo(1400 / 1000, 0.001));
    expect(find.text('横屏'), findsOneWidget);

    // 笔迹跟着转：原来的 (0.1, 0.2) 顺时针转 90° 变成 (0.8, 0.1)。
    final rotated = paintedStrokes(tester).first.points.first;
    expect(rotated.x, closeTo(0.8, 0.001));
    expect(rotated.y, closeTo(0.1, 0.001));

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final value = result();
    expect(value, isNotNull);
    expect(value!.canvasWidth, 1400);
    expect(value.canvasHeight, 1000);
    expect(value.strokes.first.points.first.x, closeTo(0.8, 0.001));
  });

  testWidgets('缩放按钮改变倍率，适应按钮回到 100%', (tester) async {
    await openCanvas(tester);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byTooltip('放大'));
    await tester.tap(find.byTooltip('放大'));
    await tester.pumpAndSettle();
    expect(find.text('150%'), findsOneWidget);

    await tester.tap(find.byTooltip('适应画布'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('纸张按钮循环切换，切出来的样式跟着结果带回去', (tester) async {
    final result = await openCanvas(tester);
    expect(find.text('纸张：空白'), findsOneWidget);

    await tester.tap(find.text('纸张：空白'));
    await tester.pumpAndSettle();
    expect(find.text('纸张：横线'), findsOneWidget);

    // 纸的样式进了画布那个 painter，屏幕上真换了纸。
    PaperPainter paperOnScreen() => tester
        .widget<CustomPaint>(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint && widget.painter is PaperPainter,
              )
              .first,
        )
        .painter! as PaperPainter;
    expect(paperOnScreen().paper, PaperStyle.lined);

    // 再点两下到点阵，然后往回点一下回到方格。
    await tester.tap(find.text('纸张：横线'));
    await tester.pumpAndSettle();
    expect(paperOnScreen().paper, PaperStyle.grid);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result()!.paper, PaperStyle.grid, reason: '纸张样式要跟着结果带回去');
  });

  testWidgets('放大之后落笔位置依然准：同一个屏幕点更靠近画布中心', (tester) async {
    final result = await openCanvas(tester);

    final canvas = tester.getRect(
      find
          .descendant(
            of: find.byType(InkCanvasPage),
            matching: find.byType(AspectRatio),
          )
          .first,
    );
    // 选一个明显偏离中心的点：画布左上区域。
    final target = Offset(
      canvas.left + canvas.width * 0.2,
      canvas.top + canvas.height * 0.2,
    );

    Future<InkPoint> drawAndRead(Offset at) async {
      final before = paintedStrokes(tester).length;
      final gesture = await tester.startGesture(at);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      final strokes = paintedStrokes(tester);
      expect(strokes.length, before + 1, reason: '这一笔没画上去');
      return strokes.last.points.first;
    }

    final atFull = await drawAndRead(target);
    // 100% 时这个点落在画布左上角附近。
    expect(atFull.x, lessThan(0.35));
    expect(atFull.y, lessThan(0.35));

    // 放大到 150%，同一个屏幕点对应的画布坐标会更靠中间。
    await tester.tap(find.byTooltip('放大'));
    await tester.tap(find.byTooltip('放大'));
    await tester.pumpAndSettle();
    final zoomed = await drawAndRead(target);
    expect(zoomed.x, greaterThan(atFull.x + 0.05));
    expect(zoomed.y, greaterThan(atFull.y + 0.05));

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
  });
}
