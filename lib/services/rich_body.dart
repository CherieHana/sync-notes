import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import '../util/note_text.dart';

/// 富文本正文的读写。
///
/// 正文存的是 Quill Delta 的 JSON。老笔记是纯文本，里面用 `[[img:<id>]]`
/// 这类标记表示内嵌块——打开时自动转换，不用一次性把整个库重写一遍。
class RichBody {
  const RichBody._();

  /// 把正文转成编辑器用的文档。老格式会自动转换。
  static Document documentFrom(String body) {
    final ops = tryDecodeRichBody(body);
    return Document.fromJson(ops ?? opsFromPlainText(body));
  }

  /// 把编辑器里的文档存回正文。
  static String encode(Document document) =>
      jsonEncode(document.toDelta().toJson());

  /// 在正文里插一个块级内嵌（图片、手写），并保证它独占一行。
  ///
  /// 返回插入之后光标该待的位置——块后面那个位置，接着就能打字。
  ///
  /// 为什么要自己补前后换行：Quill 只会给视频补，图片和自定义内嵌会贴着
  /// 光标所在的那一行插进去，和文字挤在一起。独占一行之后它才是块级内嵌，
  /// 也才能按我们想要的大小渲染。
  static int insertBlockEmbed(Document document, int index, Embeddable embed) {
    final text = document.toPlainText();
    final at = index.clamp(0, text.length);
    final before = text.substring(0, at);
    final after = text.substring(at);
    final padBefore = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final padAfter = after.isEmpty || after.startsWith('\n') ? '' : '\n';

    if (padBefore.isNotEmpty) document.insert(at, padBefore);
    final block = at + padBefore.length;
    document.insert(block, embed);
    if (padAfter.isNotEmpty) document.insert(block + 1, padAfter);

    return block + 1;
  }

  /// 老格式的纯文本 → 富文本文档结构。
  ///
  /// `[[img:<id>]]` 和 `[[ink:<id>]]` 变成内嵌块，其余原样保留。
  static List<dynamic> opsFromPlainText(String text) {
    final ops = <dynamic>[];
    var last = 0;

    for (final match in embedTokenPattern.allMatches(text)) {
      if (match.start > last) {
        ops.add({'insert': text.substring(last, match.start)});
      }
      final id = match.group(2)!;
      ops.add({
        'insert': match.group(1) == 'ink' ? {'ink': id} : {'image': id},
      });
      last = match.end;
    }
    if (last < text.length) ops.add({'insert': text.substring(last)});

    // Quill 的文档必须以换行结尾，且不能是空的。
    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    } else {
      final tail = ops.last;
      if (tail is Map && tail['insert'] is String) {
        final value = tail['insert'] as String;
        if (!value.endsWith('\n')) tail['insert'] = '$value\n';
      } else {
        // 结尾是个内嵌块，补一个换行。
        ops.add({'insert': '\n'});
      }
    }
    return ops;
  }
}
