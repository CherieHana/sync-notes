import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/ink_strokes.dart';

void main() {
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
