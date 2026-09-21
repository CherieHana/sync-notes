import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sync_notes/services/block_style.dart';
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

  /// 横线纸的一条横线所在的像素带里有多少非白像素。
  int linePixels(img.Image image, int bandCenter) {
    var count = 0;
    for (var y = bandCenter - 5; y <= bandCenter + 5; y++) {
      for (var x = 100; x < image.width - 100; x += 7) {
        if (image.getPixel(x, y).r < 240) count++;
      }
    }
    return count;
  }

  testWidgets('横线纸导出成 PNG：纸上真有横线；空白纸同一位置什么都没有', (tester) async {
    // 行距是宽度的 1/20。1000 逻辑像素宽、2 倍像素 → 画布宽 2000，
    // 第一条横线落在 y = 100（2000 的两倍之后是 2000/20 = 100）。
    const firstLineY = 100;

    final lined = await tester.runAsync(
      () => renderStrokesToPng(
        strokes: const [],
        canvasWidth: 1000,
        canvasHeight: 1400,
        paper: PaperStyle.lined,
      ),
    );
    final blank = await tester.runAsync(
      () => renderStrokesToPng(
        strokes: const [],
        canvasWidth: 1000,
        canvasHeight: 1400,
      ),
    );

    final linedImage = img.decodeImage(lined!)!;
    final blankImage = img.decodeImage(blank!)!;
    expect(linedImage.width, 2000);
    expect(linedImage.height, 2800);

    expect(
      linePixels(linedImage, firstLineY),
      greaterThan(50),
      reason: '横线纸上该有横线',
    );
    expect(
      linePixels(blankImage, firstLineY),
      0,
      reason: '空白纸不该凭空多出横线（默认观感要和以前一样）',
    );
  });
}
