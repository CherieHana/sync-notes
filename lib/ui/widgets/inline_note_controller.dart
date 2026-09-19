import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/ink_strokes.dart';
import '../../util/note_text.dart';
import 'ink_view.dart';

/// 正文里内嵌的东西有哪几种。
enum EmbedKind { image, ink }

/// 编辑态里第 k 个占位符对应的内嵌元素。
class EmbedRef {
  const EmbedRef(this.kind, this.id);

  const EmbedRef.image(this.id) : kind = EmbedKind.image;

  const EmbedRef.ink(this.id) : kind = EmbedKind.ink;

  final EmbedKind kind;
  final String id;
}

/// 渲染一张内嵌图片需要的信息。
class InlineImageInfo {
  const InlineImageInfo({this.path, this.aspectRatio = 4 / 3});

  /// 图片在本机的路径。还没从服务端下回来时为 null，界面画占位框。
  final String? path;

  /// 宽高比，用来在正文里按原始比例排版。不知道时按 4:3 处理。
  final double aspectRatio;
}

/// 渲染一块手写画布需要的信息。
class InlineInkInfo {
  const InlineInkInfo({
    this.strokes,
    this.aspectRatio = inkCanvasWidth / inkCanvasHeight,
  });

  /// 笔迹。为 null 表示还没从服务端同步下来。
  final List<InkStroke>? strokes;
  final double aspectRatio;
}

/// 编辑器用的文本控制器，负责把正文里的内嵌标记换成真正的组件。
///
/// 为什么要在两种形式之间来回转换，而不是直接把标记渲染成组件：
/// Flutter 的 `EditableText` 要求渲染出来的文本长度和 `value.text` 完全一致，
/// 否则光标定位和选区都会错位（一个 `WidgetSpan` 只顶一个字符，
/// 而 `[[img:uuid]]` 有 49 个字符）。
///
/// 所以编辑态里一个内嵌块就是一个占位符字符，文档里才展开成完整的标记。
/// 文档始终是唯一的真相来源，编辑态由它推导出来。
class InlineNoteController extends TextEditingController {
  InlineNoteController({
    required this.embedsOf,
    required this.imageInfoOf,
    required this.inkInfoOf,
    this.onTapInk,
  });

  /// 编辑态里代表一个内嵌块的字符（U+FFFC，对象替换符）。
  static const String placeholder = '\uFFFC';

  /// 当前占位符顺序对应的内嵌块。
  ///
  /// 必须由调用方提供：编辑态文本里只有占位符，没有 id，
  /// 从文本本身解析是拿不到的——早先就是在这里栽过一次，
  /// 结果所有占位符都退化成原始字符，界面上显示成一排「OBJ」方块。
  final List<EmbedRef> Function() embedsOf;

  final InlineImageInfo Function(String imageId) imageInfoOf;

  final InlineInkInfo Function(String inkId) inkInfoOf;

  /// 点手写画布时回调，通常用来打开全屏画布页。
  final void Function(String inkId)? onTapInk;

  /// 图片在正文里的最大显示尺寸，避免一张大图把整屏占满。
  static const double maxImageWidth = 300;
  static const double maxImageHeight = 240;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final embeds = embedsOf();
    final children = <InlineSpan>[];
    var index = 0;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char != placeholder) {
        children.add(TextSpan(text: char, style: style));
        continue;
      }

      // 占位符必须换成同样「占一个字符」的 WidgetSpan，
      // 否则渲染出来的文本长度和 value.text 对不上，光标会错位。
      final embed = index < embeds.length ? embeds[index] : null;
      index++;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: switch (embed?.kind) {
            EmbedKind.image => _InlineImage(
              key: ValueKey('img-${embed!.id}'),
              info: imageInfoOf(embed.id),
            ),
            EmbedKind.ink => InkPreview(
              key: ValueKey('ink-${embed!.id}'),
              strokes: inkInfoOf(embed.id).strokes,
              aspectRatio: inkInfoOf(embed.id).aspectRatio,
              onTap: onTapInk == null ? null : () => onTapInk!(embed.id),
            ),
            null => _MissingEmbed(key: ValueKey('orphan-$i')),
          },
        ),
      );
    }

    return TextSpan(style: style, children: children);
  }

  // ---------------------------------------------------------------------
  // 文档 ↔ 编辑态的转换
  // ---------------------------------------------------------------------

  /// 文档形式转成编辑态：标记换成占位符，同时记下顺序和种类。
  static ({String display, List<EmbedRef> embeds}) toDisplay(String document) {
    final embeds = <EmbedRef>[];
    final buffer = StringBuffer();
    var last = 0;
    for (final match in embedTokenPattern.allMatches(document)) {
      buffer.write(document.substring(last, match.start));
      buffer.write(placeholder);
      embeds.add(
        match.group(1) == 'ink'
            ? EmbedRef.ink(match.group(2)!)
            : EmbedRef.image(match.group(2)!),
      );
      last = match.end;
    }
    buffer.write(document.substring(last));
    return (display: buffer.toString(), embeds: embeds);
  }

  /// 编辑态转回文档：第 k 个占位符换回第 k 个内嵌块的标记。
  static String toDocument(String display, List<EmbedRef> embeds) {
    final buffer = StringBuffer();
    var index = 0;
    for (var i = 0; i < display.length; i++) {
      final char = display[i];
      if (char != placeholder) {
        buffer.write(char);
        continue;
      }
      if (index < embeds.length) {
        final embed = embeds[index];
        buffer.write(
          embed.kind == EmbedKind.ink
              ? inkMarker(embed.id)
              : imageMarker(embed.id),
        );
        index++;
      }
      // 多出来的占位符没有对应记录，直接丢掉，免得文档里留下无法解释的字符。
    }
    return buffer.toString();
  }

  /// 编辑之后算出剩下的内嵌块。
  ///
  /// 通过对比编辑前后的文本定位被改动的区间，数一数区间里少了几个占位符，
  /// 就知道删掉的是第几个块。文本编辑器里绝大多数是单点编辑，这个判断够用。
  static List<EmbedRef> embedsAfterEdit({
    required String oldDisplay,
    required String newDisplay,
    required List<EmbedRef> embeds,
  }) {
    var prefix = 0;
    final maxPrefix = math.min(oldDisplay.length, newDisplay.length);
    while (prefix < maxPrefix && oldDisplay[prefix] == newDisplay[prefix]) {
      prefix++;
    }

    var suffix = 0;
    final maxSuffix = math.min(
      oldDisplay.length - prefix,
      newDisplay.length - prefix,
    );
    while (suffix < maxSuffix &&
        oldDisplay[oldDisplay.length - 1 - suffix] ==
            newDisplay[newDisplay.length - 1 - suffix]) {
      suffix++;
    }

    final oldRegion = oldDisplay.substring(prefix, oldDisplay.length - suffix);
    final newRegion = newDisplay.substring(prefix, newDisplay.length - suffix);

    // 只看两边占位符数量的差，而不是「区间里有几个」。
    // 差别在：用户在图片前后都改了字时，改动区间会把图片一起圈进去，
    // 但那并不代表图片被删了——两边数量一样就说明它还在。
    final removedCount =
        countPlaceholders(oldRegion) - countPlaceholders(newRegion);
    if (removedCount <= 0) return embeds;

    final removedStart = countPlaceholders(oldDisplay.substring(0, prefix));
    final result = List<EmbedRef>.from(embeds);
    final from = math.min(removedStart, result.length);
    final to = math.min(removedStart + removedCount, result.length);
    if (from < to) result.removeRange(from, to);
    return result;
  }

  /// 数一段文本里有多少个内嵌占位符。插入块时要靠它算出插到第几个。
  static int countPlaceholders(String value) {
    var count = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == placeholder) count++;
    }
    return count;
  }
}

/// 占位符找不到对应记录时画的框。仍然只占一个字符，不影响光标定位。
class _MissingEmbed extends StatelessWidget {
  const _MissingEmbed({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: 96,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        alignment: Alignment.center,
        child: const Text('内容已丢失', style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// 编辑态里的一张图。
class _InlineImage extends StatelessWidget {
  const _InlineImage({required this.info, super.key});

  final InlineImageInfo info;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(8));
    final theme = Theme.of(context);

    // 按原始比例算出显示尺寸。固定宽度会导致窄图被压扁、宽图撑破布局，
    // 早先没算这个，宽图的占位符比一行还宽，文字就被挤成一行一个字。
    final ratio = info.aspectRatio.isFinite && info.aspectRatio > 0
        ? info.aspectRatio
        : 4 / 3;
    var width = InlineNoteController.maxImageWidth;
    var height = width / ratio;
    if (height > InlineNoteController.maxImageHeight) {
      height = InlineNoteController.maxImageHeight;
      width = height * ratio;
    }
    if (width < 80) {
      width = 80;
      height = width / ratio;
    }

    final path = info.path;
    if (path == null) {
      // 文件还没从服务端下回来，先给个占位框。
      return _box(
        theme,
        radius,
        width: width,
        height: height,
        child: const Center(child: Icon(Icons.image_outlined, size: 28)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => _box(
              theme,
              radius,
              width: width,
              height: height,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(
    ThemeData theme,
    BorderRadius radius, {
    required double width,
    required double height,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: child,
      ),
    );
  }
}
