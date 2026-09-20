import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../services/block_style.dart';
import '../../services/ink_strokes.dart';
import 'ink_view.dart';

/// 正文里手写画布的类型名。图片用 Quill 内置的 `image`。
const String inkEmbedType = 'ink';

/// 渲染一张内嵌图片需要的信息。
///
/// 正文里只存图片 id，路径和宽高比要现查本地库：别的设备写的笔记同步过来时，
/// 图片文件是随后才慢慢下回来的，刚打开那一刻可能还没有。
class NoteImageInfo {
  const NoteImageInfo({this.path, this.aspectRatio = 4 / 3});

  /// 图片在本机的路径。为 null 表示文件还没下回来，界面画个占位框。
  final String? path;

  /// 宽高比，用来在正文里按原始比例排版。不知道时按 4:3 处理。
  final double aspectRatio;
}

/// 渲染一块内嵌手写需要的信息。
class NoteInkInfo {
  const NoteInkInfo({
    this.strokes,
    this.aspectRatio = inkCanvasWidth / inkCanvasHeight,
  });

  /// 笔迹。为 null 表示还没从服务端同步下来。
  final List<InkStroke>? strokes;
  final double aspectRatio;
}

/// 图片块在正文里的自动尺寸（没手动调过大小时用）。
Size noteImageAutoSize(double aspectRatio) => autoBlockSize(
  aspectRatio: aspectRatio,
  maxWidth: 300,
  maxHeight: 240,
  minWidth: 80,
);

/// 手写块在正文里的自动尺寸。
Size noteInkAutoSize(double aspectRatio) =>
    autoBlockSize(aspectRatio: aspectRatio, maxWidth: 300, maxHeight: 260);

/// 一个内嵌块的通用外壳：按大小/旋转摆好位置，套上点击和长按手势。
///
/// 正文编辑器和导出长图都用它，保证两边长得一模一样。
class NoteBlockShell extends StatelessWidget {
  const NoteBlockShell({
    super.key,
    required this.layout,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final BlockLayout layout;
  final Widget child;

  /// 单击：图片打开大图、手写进画布。
  final VoidCallback? onTap;

  /// 长按：弹出大小/旋转面板。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // 块级内嵌拿到的是「宽度撑满整行」的紧约束，直接写死宽高的盒子会被
      // 父级覆盖，于是内容被拉伸、还在整行里居中。Align 会把约束放松，
      // 尺寸和左对齐才生效。
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: layout.box.width,
            height: layout.box.height,
            // 内容绕自己的中心转，外接矩形就是上面算出来的 box，
            // 所以转过的块不会压住上下两行文字。
            child: Center(
              child: Transform.rotate(
                angle: layout.angle,
                child: SizedBox(
                  width: layout.content.width,
                  height: layout.content.height,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 正文/导出长图里的一张图。
class NoteImageBlock extends StatelessWidget {
  const NoteImageBlock({
    super.key,
    required this.info,
    this.style = BlockStyle.none,
    this.onTap,
    this.onLongPress,
  });

  final NoteImageInfo info;
  final BlockStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = layoutBlock(
      autoSize: noteImageAutoSize(info.aspectRatio),
      style: style,
    );
    final path = info.path;

    final Widget picture = path == null
        ? _placeholder(theme, const Icon(Icons.image_outlined, size: 28))
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) =>
                _placeholder(theme, const Icon(Icons.broken_image_outlined)),
          );

    return NoteBlockShell(
      layout: layout,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: picture,
      ),
    );
  }

  Widget _placeholder(ThemeData theme, Widget child) => Container(
    color: theme.colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: child,
  );
}

/// 正文/导出长图里的一块手写画布。
class NoteInkBlock extends StatelessWidget {
  const NoteInkBlock({
    super.key,
    required this.info,
    this.style = BlockStyle.none,
    this.onTap,
    this.onLongPress,
  });

  final NoteInkInfo info;
  final BlockStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = layoutBlock(
      autoSize: noteInkAutoSize(info.aspectRatio),
      style: style,
    );
    final strokes = info.strokes;

    return NoteBlockShell(
      layout: layout,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: theme.dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: strokes == null
            ? const Center(child: Icon(Icons.draw_outlined, size: 28))
            : strokes.isEmpty
            ? Center(
                child: Text('空手写块，点一下开始写', style: theme.textTheme.bodySmall),
              )
            : CustomPaint(painter: InkPainter(strokes: strokes)),
      ),
    );
  }
}

/// 把文档里的图片渲染成本机文件。
///
/// Quill 自带的图片内嵌是按 URL 加载的，我们的图片存在本机，所以自己接管。
class NoteImageEmbedBuilder extends EmbedBuilder {
  const NoteImageEmbedBuilder({
    required this.infoOf,
    this.onTap,
    this.onLongPress,
  });

  final NoteImageInfo Function(String imageId) infoOf;

  /// 点图片时回调（带上块在正文里的位置），用来打开大图预览。
  final void Function(String imageId, int offset, BlockStyle style)? onTap;

  /// 长按回调，用来弹大小/旋转面板。
  final void Function(String imageId, int offset, BlockStyle style)?
  onLongPress;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final id = node.value.data as String;
    final offset = node.documentOffset;
    final style = BlockStyle.fromAttributes(node.style.attributes);
    return NoteImageBlock(
      info: infoOf(id),
      style: style,
      onTap: onTap == null ? null : () => onTap!(id, offset, style),
      onLongPress: onLongPress == null
          ? null
          : () => onLongPress!(id, offset, style),
    );
  }
}

/// 把文档里的手写数据渲染成画布。点一下进全屏画布页继续写。
class NoteInkEmbedBuilder extends EmbedBuilder {
  const NoteInkEmbedBuilder({
    required this.infoOf,
    this.onTap,
    this.onLongPress,
  });

  final NoteInkInfo Function(String inkId) infoOf;
  final void Function(String inkId, int offset, BlockStyle style)? onTap;
  final void Function(String inkId, int offset, BlockStyle style)? onLongPress;

  @override
  String get key => inkEmbedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final id = node.value.data as String;
    final offset = node.documentOffset;
    final style = BlockStyle.fromAttributes(node.style.attributes);
    return NoteInkBlock(
      info: infoOf(id),
      style: style,
      onTap: onTap == null ? null : () => onTap!(id, offset, style),
      onLongPress: onLongPress == null
          ? null
          : () => onLongPress!(id, offset, style),
    );
  }
}
