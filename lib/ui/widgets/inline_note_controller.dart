import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../util/note_text.dart';

/// 编辑器用的文本控制器，负责把正文里的图片标记换成真正的图片。
///
/// 为什么要在两种形式之间来回转换，而不是直接把标记渲染成图片：
/// Flutter 的 `EditableText` 要求渲染出来的文本长度和 `value.text` 完全一致，
/// 否则光标定位和选区都会错位（一个 `WidgetSpan` 只顶一个字符，
/// 而 `[[img:uuid]]` 有 49 个字符）。
///
/// 所以编辑态里一张图就是一个占位符字符，文档里才展开成完整的标记。
/// 文档始终是唯一的真相来源，编辑态由它推导出来。
class InlineNoteController extends TextEditingController {
  InlineNoteController({required this.imagePathOf});

  /// 编辑态里代表一张图的字符（U+FFFC，对象替换符）。
  static const String placeholder = '\uFFFC';

  /// 返回图片在本机的路径。文件还没下回来时返回 null，界面会画一个占位框。
  final String? Function(String imageId) imagePathOf;

  /// 图片在编辑态里的最大显示高度，避免一张长图把整屏占满。
  static const double maxImageHeight = 260;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // 一个占位符配一个 id，顺序对应。
    final ids = imageIdsIn(text).toList();
    final children = <InlineSpan>[];
    var idIndex = 0;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char != placeholder) {
        children.add(TextSpan(text: char, style: style));
        continue;
      }
      if (idIndex >= ids.length) {
        // 没有对应记录的占位符（多半是从别处粘进来的），当普通字符处理。
        children.add(TextSpan(text: char, style: style));
        continue;
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineImage(
            path: imagePathOf(ids[idIndex]),
            key: ValueKey(ids[idIndex]),
          ),
        ),
      );
      idIndex++;
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
        _countPlaceholders(oldRegion) - _countPlaceholders(newRegion);
    if (removedCount <= 0) return ids;

    final removedStart = _countPlaceholders(oldDisplay.substring(0, prefix));

    final result = List<String>.from(ids);
    final from = math.min(removedStart, result.length);
    final to = math.min(removedStart + removedCount, result.length);
    if (from < to) result.removeRange(from, to);
    return result;
  }

  static int _countPlaceholders(String value) {
    return countPlaceholders(value);
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
  const _InlineImage({required this.path, super.key});

  final String? path;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(8));
    final path = this.path;
    if (path == null) {
      // 还没从服务端下回来，先给个占位框。
      return Container(
        width: 160,
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: const Center(child: Icon(Icons.image_outlined, size: 28)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: InlineNoteController.maxImageHeight,
          ),
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => Container(
              width: 160,
              height: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }
}
