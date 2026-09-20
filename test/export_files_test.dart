import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sync_notes/services/export_files.dart';
import 'package:sync_notes/services/ink_strokes.dart';

/// 导出相关的纯计算：文件名、旋转烘焙、手写出图。
void main() {
  test('文件名里的时间戳是 年月日-时分', () {
    expect(exportStamp(DateTime(2026, 9, 20, 5, 7)), '20260920-0507');
  });

  test('转 90° 时标记点转到右上角（顺时针）', () {
    // 2×1 的图：左边一个红点。
    final source = img.Image(width: 2, height: 1);
    source.setPixelRgb(0, 0, 255, 0, 0);
    source.setPixelRgb(1, 0, 255, 255, 255);
    final raw = Uint8List.fromList(img.encodePng(source));

    final rotated = img.decodeImage(bakeRotation(raw, 90))!;
    expect(rotated.width, 1);
    expect(rotated.height, 2);

    // 原来的左上角（红点）转 90° 之后应该落在右上角，也就是 (0, 0)。
    final pixel = rotated.getPixel(0, 0);
    expect(pixel.r, greaterThan(200));
    expect(pixel.g, lessThan(100));
  });

  test('不转的时候原样返回，不重新编码', () {
    final source = img.Image(width: 2, height: 2);
    final raw = Uint8List.fromList(img.encodePng(source));
    expect(bakeRotation(raw, 0), same(raw));
    expect(bakeRotation(raw, 360), same(raw));
  });

  testWidgets('手写导出成 PNG：白底、按画布尺寸的两倍像素', (tester) async {
    const strokes = [
      InkStroke(
        color: 0xFF000000,
        width: 40,
        points: [InkPoint(0.2, 0.3), InkPoint(0.7, 0.6)],
      ),
    ];

    // 出图要走引擎的异步图像管线，得在 runAsync 里跑。
    final bytes = await tester.runAsync(
      () => renderStrokesToPng(
        strokes: strokes,
        canvasWidth: 1000,
        canvasHeight: 1400,
      ),
    );
    expect(bytes, isNotNull);

    final decoded = img.decodeImage(bytes!)!;
    expect(decoded.width, 2000);
    expect(decoded.height, 2800);

    // 左上角是白的（背景），笔画经过的地方有黑像素。
    final background = decoded.getPixel(5, 5);
    expect(background.r, greaterThan(240));
    var darkPixels = 0;
    for (var y = 800; y < 900; y++) {
      for (var x = 300; x < 700; x++) {
        if (decoded.getPixel(x, y).r < 100) darkPixels++;
      }
    }
    expect(darkPixels, greaterThan(0), reason: '导出图里应该有笔画');
  });
}
