import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/block_style.dart';
import '../../services/ink_strokes.dart';

/// 把纸张底纹画到画布上。
///
/// 手写画布页、正文里的预览、导出 PNG、导出长图四处都调它，
/// 保证同一个画布在哪儿看都是同一种纸。
void paintPaper(Canvas canvas, Size size, PaperStyle paper) {
  if (size.isEmpty || paper == PaperStyle.blank) return;

  final paint = Paint()
    ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.45)
    ..strokeWidth = 1;

  // 间距按画布宽度缩放，缩到 50% 看也不至于糊成一片。
  final step = size.width / 20;

  switch (paper) {
    case PaperStyle.blank:
      return;
    case PaperStyle.lined:
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    case PaperStyle.grid:
      for (var y = step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      for (var x = step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    case PaperStyle.dots:
      final dot = Paint()..color = paint.color;
      for (var y = step; y < size.height; y += step) {
        for (var x = step; x < size.width; x += step) {
          canvas.drawCircle(Offset(x, y), 1.1, dot);
        }
      }
  }
}

/// 画布底色 + 纸张底纹。画布页和正文预览都先用它铺一层。
class PaperPainter extends CustomPainter {
  const PaperPainter({required this.paper, required this.background});

  final PaperStyle paper;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    paintPaper(canvas, size, paper);
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.background != background;
}

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
