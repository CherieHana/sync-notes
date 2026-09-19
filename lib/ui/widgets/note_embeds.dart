import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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

  /// 图片在正文里的最大显示尺寸，避免一张大图把整屏占满。
  static const double maxWidth = 300;
  static const double maxHeight = 240;

  /// 按原始比例算出的显示尺寸。
  ///
  /// 固定宽度会把窄图压扁、让宽图撑破一行；也不能太小，否则小图会缩成一条。
  Size get displaySize {
    final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 4 / 3;
    var width = maxWidth;
    var height = width / ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }
    if (width < 80) {
      width = 80;
      height = width / ratio;
    }
    return Size(width, height);
  }
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

/// 把文档里的图片渲染成本机文件。
///
/// Quill 自带的图片内嵌是按 URL 加载的，我们的图片存在本机，所以自己接管。
class NoteImageEmbedBuilder extends EmbedBuilder {
  const NoteImageEmbedBuilder({required this.infoOf});

  final NoteImageInfo Function(String imageId) infoOf;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final id = embedContext.node.value.data as String;
    final info = infoOf(id);
    final size = info.displaySize;
    final theme = Theme.of(context);
    final path = info.path;

    final Widget picture = path == null
        ? _box(theme, size, const Icon(Icons.image_outlined, size: 28))
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) =>
                _box(theme, size, const Icon(Icons.broken_image_outlined)),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // 块级内嵌拿到的是「宽度撑满整行」的紧约束，直接写死宽高的盒子会被
      // 父级覆盖，于是图片被拉伸、还在整行里居中。Align 会把约束放松，
      // 尺寸和左对齐才生效。
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: picture,
          ),
        ),
      ),
    );
  }

  Widget _box(ThemeData theme, Size size, Widget child) => Container(
    width: size.width,
    height: size.height,
    color: theme.colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: child,
  );
}

/// 把文档里的手写数据渲染成画布。点一下进全屏画布页继续写。
class NoteInkEmbedBuilder extends EmbedBuilder {
  const NoteInkEmbedBuilder({required this.infoOf, this.onTap});

  final NoteInkInfo Function(String inkId) infoOf;

  /// 点画布时回调，用来打开全屏画布页。
  final void Function(String inkId)? onTap;

  static const double maxWidth = 300;
  static const double maxHeight = 260;

  @override
  String get key => inkEmbedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final id = embedContext.node.value.data as String;
    final info = infoOf(id);
    final theme = Theme.of(context);

    final ratio = info.aspectRatio.isFinite && info.aspectRatio > 0
        ? info.aspectRatio
        : inkCanvasWidth / inkCanvasHeight;
    var width = maxWidth;
    var height = width / ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }

    final strokes = info.strokes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // 同图片：不套 Align 的话画布会被拉成全宽的一条，里面的笔画跟着变形。
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap == null ? null : () => onTap!(id),
          child: Container(
            width: width,
            height: height,
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
                    child: Text(
                      '空手写块，点一下开始写',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : CustomPaint(painter: InkPainter(strokes: strokes)),
          ),
        ),
      ),
    );
  }
}
