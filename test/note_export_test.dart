import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sync_notes/services/block_style.dart';
import 'package:sync_notes/services/ink_strokes.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/ui/note_image_export.dart';
import 'package:sync_notes/ui/widgets/note_embeds.dart';

/// 导出整篇笔记为一张长图。
///
/// 这条测试盯的是最容易出问题的一步：内容挂在 overlay 的屏幕外位置，
/// 如果它压根没被绘制，抓下来的就是一张白纸。
void main() {
  const imageId = '55555555-5555-5555-5555-555555555555';
  const inkId = '66666666-6666-6666-6666-666666666666';

  String writeSampleImage() {
    final image = img.Image(width: 300, height: 200);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 200, 30, 30);
      }
    }
    final file = File(
      p.join(Directory.systemTemp.path, 'sync-notes-export-sample.png'),
    );
    file.writeAsBytesSync(img.encodePng(image));
    addTearDown(() {
      // 图片可能还被 ImageCache 攥着，删不掉就算了（在系统临时目录里）。
      PaintingBinding.instance.imageCache.clear();
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // 忽略：临时目录里的残留不影响测试结果。
      }
    });
    return file.path;
  }

  testWidgets('屏幕外的长图能抓出来：宽度对、有内容、不是白纸', (tester) async {
    final imagePath = writeSampleImage();
    final body = RichBody.encode(
      RichBody.documentFrom(
        '导出测试标题\n[[img:$imageId]]\n正文第二行\n[[ink:$inkId]]\n结尾',
      ),
    );

    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -noteExportWidth - 4000,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: NoteExportView(
            body: body,
            imageInfoOf: (id) => NoteImageInfo(
              path: id == imageId ? imagePath : null,
              aspectRatio: 300 / 200,
            ),
            inkInfoOf: (id) => const NoteInkInfo(
              strokes: [
                InkStroke(
                  color: 0xFF000000,
                  width: 20,
                  points: [InkPoint(0.1, 0.1), InkPoint(0.9, 0.9)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(hostContext, rootOverlay: true).insert(entry);
    addTearDown(entry.remove);
    await tester.pump();
    await tester.pump();

    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    expect(boundary, isNotNull);
    expect(boundary!.size.width, noteExportWidth);
    expect(boundary.size.height, greaterThan(300));

    // 抓图要走引擎的异步图像管线，得在 runAsync 里做。
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    });
    expect(bytes, isNotNull, reason: '没抓到图');

    final decoded = img.decodeImage(bytes!)!;
    // 720 逻辑像素宽 × 2 倍像素。
    expect(decoded.width, (noteExportWidth * 2).round());
    expect(decoded.height, (boundary.size.height * 2).round());

    // 不是白纸：文字和手写都会留下深色像素。
    var dark = 0;
    for (var y = 0; y < decoded.height; y += 3) {
      for (var x = 0; x < decoded.width; x += 3) {
        if (decoded.getPixel(x, y).r < 140) dark++;
      }
    }
    expect(dark, greaterThan(20), reason: '导出的图是空白的');
  });

  test('内容太高时自动降倍率，实在放不下就放弃', () {
    expect(exportPixelRatio(1000, 2), 2);
    // 20000 像素高：2 倍放不下，压到 16000/20000 倍。
    expect(exportPixelRatio(20000, 2), closeTo(0.8, 0.001));
    // 高到连 0.3 倍都放不下。
    expect(exportPixelRatio(60000, 2), 0);
  });

  test('导出长图里的块和正文排版用的是同一套尺寸', () {
    // 手写块默认自动尺寸：竖版画布（1000×1400）落在 300×260 那一档里。
    final layout = layoutBlock(autoSize: noteInkAutoSize(1000 / 1400));
    expect(layout.box.height, lessThanOrEqualTo(260.001));
    expect(layout.box.width, lessThanOrEqualTo(300.001));
    expect(layout.box.height / layout.box.width, closeTo(1.4, 0.02));
  });

  test('导出的手写块也认正文里的旋转', () {
    final layout = layoutBlock(
      autoSize: noteInkAutoSize(1),
      style: const BlockStyle(rotate: 90),
    );
    expect(layout.box.width, closeTo(layout.content.height, 0.001));
    expect(layout.box.height, closeTo(layout.content.width, 0.001));
  });
}
