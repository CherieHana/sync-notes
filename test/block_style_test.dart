import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/block_style.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/ui/widgets/note_embeds.dart';

/// 内嵌块的大小/旋转：读写正文、以及排版尺寸的计算。
void main() {
  const imageId = '11111111-1111-1111-1111-111111111111';

  /// 正文里第 [offset] 个位置上的样式。
  BlockStyle styleAt(Document document, int offset) {
    var index = 0;
    for (final op in document.toDelta().toList()) {
      final length = op.length ?? 0;
      if (offset < index + length) {
        if (op.isInsert && op.data is Map) {
          return BlockStyle.fromJson(op.attributes);
        }
        return BlockStyle.none;
      }
      index += length;
    }
    return BlockStyle.none;
  }

  test('写进正文再读回来，大小和角度都在', () {
    final document = RichBody.documentFrom('标题\n[[img:$imageId]]\n');
    final offset = document.toPlainText().indexOf('\uFFFC');
    expect(offset, greaterThan(0));

    applyBlockStyle(document, offset, const BlockStyle(width: 240, rotate: 90));

    expect(styleAt(document, offset), const BlockStyle(width: 240, rotate: 90));
    // 存在正文里，跟着一起同步。
    expect(RichBody.encode(document), contains('"rotate":90'));

    // 重新解析一遍（相当于重新打开笔记）属性还在。
    final reopened = RichBody.documentFrom(RichBody.encode(document));
    expect(
      styleAt(reopened, reopened.toPlainText().indexOf('\uFFFC')),
      const BlockStyle(width: 240, rotate: 90),
    );
  });

  test('传 null 就是把属性清掉，回到自动尺寸', () {
    final document = RichBody.documentFrom('[[img:$imageId]]\n');
    final offset = document.toPlainText().indexOf('\uFFFC');
    applyBlockStyle(document, offset, const BlockStyle(width: 200, rotate: 45));
    applyBlockStyle(document, offset, BlockStyle.none);

    expect(styleAt(document, offset), BlockStyle.none);
    expect(RichBody.encode(document), isNot(contains('rotate')));
    expect(RichBody.encode(document), isNot(contains('"width"')));
  });

  test('宽度限制在 80–600，角度归一到 0–360', () {
    final style = BlockStyle.fromJson({'width': 5000, 'rotate': -90});
    expect(style.width, maxBlockWidth);
    expect(style.rotate, 270);

    expect(BlockStyle.fromJson({'width': 10}).width, minBlockWidth);
    // 0 度和 360 度都算「没转」，不留没用的属性。
    expect(BlockStyle.fromJson({'rotate': 360}).rotate, isNull);
    expect(BlockStyle.fromJson({'rotate': 0}).rotate, isNull);
    // 老笔记里没有这两个属性。
    expect(BlockStyle.fromJson(const {}), BlockStyle.none);
  });

  group('排版尺寸', () {
    test('不设属性时和以前完全一样', () {
      // 900×600 的图：自动尺寸 300×200。
      final auto = noteImageAutoSize(900 / 600);
      expect(auto, const Size(300, 200));

      final layout = layoutBlock(autoSize: auto);
      expect(layout.box, const Size(300, 200));
      expect(layout.content, const Size(300, 200));
      expect(layout.angle, 0);
    });

    test('设了宽度就按宽度等比缩放', () {
      final layout = layoutBlock(
        autoSize: const Size(300, 200),
        style: const BlockStyle(width: 150),
      );
      expect(layout.content, const Size(150, 100));
      expect(layout.box, const Size(150, 100));
    });

    test('转 90° 时外接矩形把宽高对调', () {
      final layout = layoutBlock(
        autoSize: const Size(300, 200),
        style: const BlockStyle(rotate: 90),
      );
      expect(layout.box.width, closeTo(200, 0.001));
      expect(layout.box.height, closeTo(300, 0.001));
      expect(layout.content, const Size(300, 200));
    });

    test('微调角度按外接矩形撑开，行高跟着变', () {
      final layout = layoutBlock(
        autoSize: const Size(300, 200),
        style: const BlockStyle(rotate: 12.5),
      );
      final radians = 12.5 * math.pi / 180;
      final expectedWidth =
          300 * math.cos(radians).abs() + 200 * math.sin(radians).abs();
      final expectedHeight =
          300 * math.sin(radians).abs() + 200 * math.cos(radians).abs();
      expect(layout.box.width, closeTo(expectedWidth, 0.001));
      expect(layout.box.height, closeTo(expectedHeight, 0.001));
      expect(layout.box.height, greaterThan(200));
    });
  });
}
