import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../ui/widgets/ink_view.dart';
import 'ink_strokes.dart';

/// 让用户挑个地方把文件存下去。
///
/// 安卓走系统的「保存到」（能挑相册/Pictures 或下载目录），电脑走另存为。
/// 返回 false 表示用户取消了。
Future<bool> saveBytesAs({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return uri != null;
}

/// 导出的文件名里用的时间戳，形如 `20260920-1530`。
String exportStamp([DateTime? now]) {
  final at = (now ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}';
}

/// 把旋转烘焙进图片的副本，原图不动。
///
/// 角度按顺时针算，和正文里的 Transform.rotate 一致。image 包的 copyRotate
/// 同样是顺时针，所以直接传角度就行。
Uint8List bakeRotation(Uint8List raw, double degrees, {int quality = 90}) {
  final normalized = degrees % 360;
  if (normalized.abs() < 0.01) return raw;

  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  final rotated = img.copyRotate(decoded, angle: normalized);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: quality));
}

/// 把手写笔迹画成 PNG：白底，按画布尺寸的 [pixelRatio] 倍出图。
///
/// 这里不经过控件渲染——笔迹本来就是归一化坐标，直接画到画布上最省事，
/// 出图尺寸也和画布标称尺寸严格对应。
Future<Uint8List?> renderStrokesToPng({
  required List<InkStroke> strokes,
  required int canvasWidth,
  required int canvasHeight,
  double pixelRatio = 2,
}) async {
  if (canvasWidth <= 0 || canvasHeight <= 0) return null;

  final width = canvasWidth.toDouble();
  final height = canvasHeight.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );
  InkPainter(strokes: strokes).paint(canvas, Size(width, height));

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * pixelRatio).round(),
    (height * pixelRatio).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data?.buffer.asUint8List();
}
