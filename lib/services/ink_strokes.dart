import 'dart:convert';

/// 手写画布上的一个点，坐标是归一化的（0~1，相对画布宽高）。
///
/// 用归一化坐标而不是像素：手机上画的东西要在电脑上看，屏幕宽度差好几倍，
/// 存像素的话换台设备就会错位。显示时再乘上实际尺寸即可。
class InkPoint {
  const InkPoint(this.x, this.y);

  final double x;
  final double y;
}

/// 一笔。同一次按下到抬起之间的所有点。
class InkStroke {
  const InkStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  /// ARGB 颜色值。
  final int color;

  /// 笔宽，单位是画布的坐标（画布固定按 1000 宽算），显示时按比例缩放。
  final double width;

  final List<InkPoint> points;

  InkStroke copyWith({int? color, double? width, List<InkPoint>? points}) {
    return InkStroke(
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
    );
  }
}

/// 手写画布的标称尺寸。笔迹坐标和笔宽都相对这个尺寸归一化。
const int inkCanvasWidth = 1000;
const int inkCanvasHeight = 1400;

/// 把笔迹整体转 90°，换画布方向（竖屏 ↔ 横屏）时用。
///
/// 笔迹是归一化坐标，只对调画布宽高会把画面压扁；这里把每个点也转 90°，
/// 画出来的样子就不变，相当于"纸"转了。顺次转两次（竖→横→竖）能回到原样。
List<InkStroke> rotateStrokes(
  List<InkStroke> strokes, {
  required bool clockwise,
}) => [
  for (final stroke in strokes)
    stroke.copyWith(
      points: [
        for (final point in stroke.points)
          clockwise
              // 顺时针：原来的左下角转到左上角。
              ? InkPoint(1 - point.y, point.x)
              // 逆时针：原来的右上角转到左上角。
              : InkPoint(point.y, 1 - point.x),
      ],
    ),
];

/// 编成 JSON。点用扁平数组存，比一堆 {x,y} 省一半体积。
String encodeInkStrokes(List<InkStroke> strokes) {
  final data = strokes
      .map(
        (stroke) => {
          'c': stroke.color,
          'w': stroke.width,
          'p': [
            for (final point in stroke.points) ...[point.x, point.y],
          ],
        },
      )
      .toList();
  return jsonEncode(data);
}

/// 解 JSON。数据坏了就当作空白画布，不要让整个编辑器打不开。
List<InkStroke> decodeInkStrokes(String? data) {
  if (data == null || data.isEmpty) return const [];
  try {
    final decoded = jsonDecode(data);
    if (decoded is! List) return const [];

    final strokes = <InkStroke>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final rawPoints = entry['p'];
      if (rawPoints is! List) continue;

      final points = <InkPoint>[];
      for (var i = 0; i + 1 < rawPoints.length; i += 2) {
        final x = rawPoints[i];
        final y = rawPoints[i + 1];
        if (x is! num || y is! num) continue;
        points.add(InkPoint(x.toDouble(), y.toDouble()));
      }
      if (points.isEmpty) continue;

      strokes.add(
        InkStroke(
          color: (entry['c'] as num?)?.toInt() ?? 0xFF000000,
          width: (entry['w'] as num?)?.toDouble() ?? 4,
          points: points,
        ),
      );
    }
    return strokes;
  } catch (_) {
    return const [];
  }
}
