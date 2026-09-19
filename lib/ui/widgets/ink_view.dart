import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/ink_strokes.dart';

/// 把笔迹画到画布上。
///
/// 笔迹坐标是归一化的（0~1），这里乘上实际尺寸即可，所以同一份数据在手机上
/// 和电脑上画出来的形状一致，只是大小不同。
class InkPainter extends CustomPainter {
  const InkPainter({required this.strokes});

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 笔宽按宽度缩放，这样细笔画在大屏上不会显得像头发丝。
    final widthScale = size.width / inkCanvasWidth;

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final color = Color(stroke.color);
      final strokeWidth = math.max(1.0, stroke.width * widthScale);

      if (stroke.points.length == 1) {
        // 单点也要看得见，画个实心圆。
        final point = stroke.points.first;
        canvas.drawCircle(
          Offset(point.x * size.width, point.y * size.height),
          strokeWidth / 2,
          Paint()..color = color,
        );
        continue;
      }

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.x * size.width, first.y * size.height);
      for (var i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        path.lineTo(point.x * size.width, point.y * size.height);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(InkPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
