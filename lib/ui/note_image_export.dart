import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/block_style.dart';
import '../services/rich_body.dart';
import '../util/note_text.dart';
import 'widgets/note_embeds.dart';

/// 导出长图的固定宽度（逻辑像素）和最大高度（实际像素）。
const double noteExportWidth = 720;
const double noteExportPadding = 28;
const double noteExportMaxPixels = 16000;

/// 一次导出的结果。失败、太长、少图都要能跟用户说清楚。
class NoteExportResult {
  const NoteExportResult({
    this.bytes,
    this.tooLong = false,
    this.missingImages = 0,
  });

  final Uint8List? bytes;

  /// 内容太长，按最小倍率也放不下。
  final bool tooLong;

  /// 还没同步下来的图片张数（长图里会画成占位框）。
  final int missingImages;

  bool get ok => bytes != null;
}

/// 把一篇笔记渲染成一张长图。
///
/// 做法：把内容挂到 root overlay 的屏幕外位置（Overlay 不裁剪，屏幕外的内容
/// 照样会画进自己的图层），等图片解码完、两帧之后用 RepaintBoundary 抓图。
Future<NoteExportResult> exportNoteImage({
  required BuildContext context,
  required String body,
  required NoteImageInfo Function(String imageId) imageInfoOf,
  required NoteInkInfo Function(String inkId) inkInfoOf,
  double pixelRatio = 2,

  /// 等一帧。给测试留的口子：测试里没法等真实帧，需要自己推。
  Future<void> Function()? awaitFrame,
}) async {
  final waitFrame = awaitFrame ?? () => WidgetsBinding.instance.endOfFrame;
  final missing = <String>[
    for (final id in imageIdsIn(body))
      if (imageInfoOf(id).path == null) id,
  ];
  final paths = <String>[
    for (final id in imageIdsIn(body))
      if (imageInfoOf(id).path != null) imageInfoOf(id).path!,
  ];

  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: -noteExportWidth - 4000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: NoteExportView(
          body: body,
          imageInfoOf: imageInfoOf,
          inkInfoOf: inkInfoOf,
        ),
      ),
    ),
  );

  final overlay = Overlay.of(context, rootOverlay: true);
  overlay.insert(entry);
  try {
    await waitFrame();
    final exportContext = key.currentContext;
    if (exportContext == null || !exportContext.mounted) {
      return const NoteExportResult();
    }

    // 图片得先解码完，不然抓下来是空白。
    for (final path in paths) {
      if (!exportContext.mounted) break;
      // 单张图卡住不该把导出拖死，等不到就先按占位框算。
      await precacheImage(
        FileImage(File(path)),
        exportContext,
      ).timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    await waitFrame();
    await waitFrame();

    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.isEmpty) {
      return NoteExportResult(missingImages: missing.length);
    }

    final ratio = exportPixelRatio(boundary.size.height, pixelRatio);
    if (ratio <= 0) {
      return NoteExportResult(tooLong: true, missingImages: missing.length);
    }

    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return NoteExportResult(
      bytes: data?.buffer.asUint8List(),
      missingImages: missing.length,
    );
  } finally {
    entry.remove();
  }
}

/// 抓图时用多大的像素倍率。
///
/// 长笔记按 2 倍出图会超出限制（内存吃不消），这里按内容高度往下压；
/// 压到 0.3 倍还放不下就返回 0，表示这张图没法导（调用方提示用户）。
double exportPixelRatio(double contentHeight, double requested) {
  if (contentHeight <= 0) return requested;
  final maxRatio = noteExportMaxPixels / contentHeight;
  final ratio = requested < maxRatio ? requested : maxRatio;
  return ratio < 0.3 ? 0 : ratio;
}

/// 按正文里的样子把笔记画成一列控件，专供导出用。
///
/// 文字样式、图片、手写块都走和编辑器同一套尺寸/旋转计算，所以导出来的
/// 和屏幕上看到的一致。
class NoteExportView extends StatelessWidget {
  const NoteExportView({
    super.key,
    required this.body,
    required this.imageInfoOf,
    required this.inkInfoOf,
  });

  final String body;
  final NoteImageInfo Function(String imageId) imageInfoOf;
  final NoteInkInfo Function(String inkId) inkInfoOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: noteExportWidth,
      color: Colors.white,
      padding: const EdgeInsets.all(noteExportPadding),
      child: Theme(
        // 导出图固定白底，文字颜色按主题的正文色来，免得深色主题下导出黑底。
        data: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5C34B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _blocks(context),
        ),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context) {
    final ops = tryDecodeRichBody(body) ?? RichBody.opsFromPlainText(body);
    final widgets = <Widget>[];
    var spans = <InlineSpan>[];

    void flushLine() {
      widgets.add(
        spans.isEmpty
            // 空行也得占一行高，用不换行空格撑住。
            ? const Text('\u00A0', style: _baseStyle)
            : Text.rich(TextSpan(children: spans, style: _baseStyle)),
      );
      spans = <InlineSpan>[];
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final attributes = op['attributes'] as Map?;
      final insert = op['insert'];

      if (insert is String) {
        final lines = insert.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            spans.add(TextSpan(text: lines[i], style: _textStyle(attributes)));
          }
          if (i < lines.length - 1) flushLine();
        }
        continue;
      }

      if (insert is Map) {
        if (spans.isNotEmpty) flushLine();
        final style = BlockStyle.fromJson(attributes);
        final image = insert['image'];
        if (image is String) {
          widgets.add(NoteImageBlock(info: imageInfoOf(image), style: style));
        } else if (insert['ink'] is String) {
          widgets.add(
            NoteInkBlock(
              info: inkInfoOf(insert['ink'] as String),
              style: style,
            ),
          );
        }
      }
    }
    if (spans.isNotEmpty) flushLine();
    return widgets;
  }

  static const TextStyle _baseStyle = TextStyle(
    fontSize: 16,
    height: 1.6,
    color: Color(0xFF1B1B1B),
  );

  TextStyle _textStyle(Map? attributes) {
    final decorations = <TextDecoration>[
      if (attributes?['underline'] == true) TextDecoration.underline,
      if (attributes?['strike'] == true) TextDecoration.lineThrough,
    ];
    return _baseStyle.copyWith(
      fontSize: inlineFontSizeFor(attributes?['size']),
      fontWeight: attributes?['bold'] == true ? FontWeight.bold : null,
      fontStyle: attributes?['italic'] == true ? FontStyle.italic : null,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
      color: parseAttributeColor(attributes?['color']) ?? _baseStyle.color,
      backgroundColor: parseAttributeColor(attributes?['background']),
    );
  }
}
