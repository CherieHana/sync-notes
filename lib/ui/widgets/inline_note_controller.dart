import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../util/note_text.dart';

/// 渲染一张内嵌图片需要的信息。
class InlineImageInfo {
  const InlineImageInfo({this.path, this.aspectRatio = 4 / 3});

  /// 图片在本机的路径。还没从服务端下回来时为 null，界面画占位框。
  final String? path;

  /// 宽高比，用来在正文里按原始比例排版。不知道时按 4:3 处理。
  final double aspectRatio;
}

/// 编辑器用的文本控制器，负责把正文里的图片占位符换成真正的图片。
///
/// 为什么要在两种形式之间来回转换，而不是直接把标记渲染成图片：
/// Flutter 的 `EditableText` 要求渲染出来的文本长度和 `value.text` 完全一致，
/// 否则光标定位和选区都会错位（一个 `WidgetSpan` 只顶一个字符，
/// 而 `[[img:uuid]]` 有 49 个字符）。
///
/// 所以编辑态里一张图就是一个占位符字符，文档里才展开成完整的标记。
/// 文档始终是唯一的真相来源，编辑态由它推导出来。
class InlineNoteController extends TextEditingController {
  InlineNoteController({required this.idsOf, required this.imageInfoOf});

  /// 编辑态里代表一张图的字符（U+FFFC，对象替换符）。
  static const String placeholder = '\uFFFC';

  /// 当前占位符顺序对应的图片 id。
  ///
  /// 必须由调用方提供：编辑态文本里只有占位符，没有 id，
  /// 从文本本身解析是拿不到的——早先就是在这里栽过一次，
  /// 结果所有占位符都退化成原始字符，界面上显示成一排「OBJ」方块。
  final List<String> Function() idsOf;

  /// 取某张图的渲染信息。
  final InlineImageInfo Function(String imageId) imageInfoOf;

  /// 图片在正文里的最大显示尺寸，避免一张大图把整屏占满。
  static const double maxImageWidth = 300;
  static const double maxImageHeight = 240;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final ids = idsOf();
    final children = <InlineSpan>[];
    var idIndex = 0;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char != placeholder) {
        children.add(TextSpan(text: char, style: style));
        continue;
      }

      // 占位符必须换成同样「占一个字符」的 WidgetSpan，
      // 否则渲染出来的文本长度和 value.text 对不上，光标会错位。
      final id = idIndex < ids.length ? ids[idIndex] : null;
      idIndex++;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineImage(
            key: ValueKey(id ?? 'orphan-$i'),
            info: id == null ? null : imageInfoOf(id),
          ),
        ),
      );
    }

    return TextSpan(style: style, children: children);
  }

  // ---------------------------------------------------------------------
  // 文档 ↔ 编辑态的转换
  // ---------------------------------------------------------------------

  /// 文档形式转成编辑态：标记换成占位符，同时记下顺序。
  static ({String display, List<String> ids}) toDisplay(String document) {
    final ids = <String>[];
    final buffer = StringBuffer();
    var last = 0;
    for (final match in imageTokenPattern.allMatches(document)) {
      buffer.write(document.substring(last, match.start));
      buffer.write(placeholder);
      ids.add(match.group(1)!);
      last = match.end;
    }
    buffer.write(document.substring(last));
    return (display: buffer.toString(), ids: ids);
  }

  /// 编辑态转回文档：第 k 个占位符换回第 k 个 id 的标记。
  static String toDocument(String display, List<String> ids) {
    final buffer = StringBuffer();
    var idIndex = 0;
    for (var i = 0; i < display.length; i++) {
      final char = display[i];
      if (char != placeholder) {
        buffer.write(char);
        continue;
      }
      if (idIndex < ids.length) {
        buffer.write(imageMarker(ids[idIndex]));
        idIndex++;
      }
      // 多出来的占位符没有对应记录，直接丢掉，免得文档里留下无法解释的字符。
    }
    return buffer.toString();
  }

  /// 编辑之后算出剩下的图片 id。
  ///
  /// 通过对比编辑前后的文本定位被改动的区间，数一数区间里少了几个占位符，
  /// 就知道删掉的是第几张图。文本编辑器里绝大多数是单点编辑，这个判断够用。
  static List<String> idsAfterEdit({
    required String oldDisplay,
    required String newDisplay,
    required List<String> ids,
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
    if (removedCount <= 0) return ids;

    final removedStart = countPlaceholders(oldDisplay.substring(0, prefix));
    final result = List<String>.from(ids);
    final from = math.min(removedStart, result.length);
    final to = math.min(removedStart + removedCount, result.length);
    if (from < to) result.removeRange(from, to);
    return result;
  }

  /// 数一段文本里有多少个图片占位符。插入图片时要靠它算出插到第几张。
  static int countPlaceholders(String value) {
    var count = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == placeholder) count++;
    }
    return count;
  }
}

/// 编辑态里的一张图。
class _InlineImage extends StatelessWidget {
  const _InlineImage({required this.info, super.key});

  /// 为 null 表示这个占位符没有对应的图片记录。
  final InlineImageInfo? info;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(8));
    final theme = Theme.of(context);

    final info = this.info;
    if (info == null) {
      return _box(
        theme,
        radius,
        width: 96,
        height: 36,
        child: const Center(
          child: Text('图片已丢失', style: TextStyle(fontSize: 11)),
        ),
      );
    }

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
