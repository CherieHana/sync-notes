import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/ink_strokes.dart';

void main() {
  test('换画布方向时笔迹转 90°，转两次回到原样', () {
    const original = [
      InkStroke(
        color: 0xFF000000,
        width: 4,
        points: [InkPoint(0, 0), InkPoint(1, 0.5), InkPoint(0.25, 1)],
      ),
    ];

    final landscape = rotateStrokes(original, clockwise: true);
    // 顺时针：左上角 (0,0) 转到右上角 (1,0)。
    expect(landscape.first.points[0].x, closeTo(1, 0.0001));
    expect(landscape.first.points[0].y, closeTo(0, 0.0001));
    // 笔宽和颜色不变。
    expect(landscape.first.width, 4);
    expect(landscape.first.color, 0xFF000000);

    final back = rotateStrokes(landscape, clockwise: false);
    for (var i = 0; i < original.first.points.length; i++) {
      expect(
        back.first.points[i].x,
        closeTo(original.first.points[i].x, 0.0001),
      );
      expect(
        back.first.points[i].y,
        closeTo(original.first.points[i].y, 0.0001),
      );
    }
  });

  test('笔迹编码再解码，内容不变', () {
    const strokes = [
      InkStroke(
        color: 0xFFD32F2F,
        width: 4,
        points: [InkPoint(0.1, 0.2), InkPoint(0.3, 0.4), InkPoint(0.5, 0.6)],
      ),
    ];

    final decoded = decodeInkStrokes(encodeInkStrokes(strokes));

    expect(decoded, hasLength(1));
    expect(decoded.first.color, 0xFFD32F2F);
    expect(decoded.first.width, 4);
    expect(decoded.first.points, hasLength(3));
    expect(decoded.first.points.first.x, closeTo(0.1, 1e-9));
    expect(decoded.first.points.last.y, closeTo(0.6, 1e-9));
  });

  test('多笔按顺序保存', () {
    const strokes = [
      InkStroke(color: 0xFF000000, width: 2, points: [InkPoint(0.1, 0.1)]),
      InkStroke(color: 0xFF1976D2, width: 8, points: [InkPoint(0.2, 0.2)]),
    ];
    final decoded = decodeInkStrokes(encodeInkStrokes(strokes));
    expect(decoded.map((s) => s.color), [0xFF000000, 0xFF1976D2]);
  });

  test('空画布编出来是空数组', () {
    expect(encodeInkStrokes(const []), '[]');
    expect(decodeInkStrokes('[]'), isEmpty);
    expect(decodeInkStrokes(null), isEmpty);
  });

  test('数据坏了当作空画布，不让编辑器打不开', () {
    expect(decodeInkStrokes('这不是 json'), isEmpty);
    expect(decodeInkStrokes('{"a":1}'), isEmpty);
    expect(decodeInkStrokes('[{"p":[]}]'), isEmpty);
    expect(decodeInkStrokes('[{"p":[0.1]}]'), isEmpty, reason: '点必须成对出现');
  });
}
