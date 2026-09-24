import 'dart:convert';

/// 正文现在是富文本（Quill Delta）的 JSON。
///
/// 老笔记还是纯文本，带 `[[img:<id>]]` / `[[ink:<id>]]` 这样的标记。
/// 下面这些函数两种格式都认，所以迁移可以慢慢来：
/// 打开或编辑到哪一篇，就把哪一篇转成富文本。

/// 正文里内嵌元素的标记。
///
/// 只在**老格式**的纯文本正文里出现。新格式把内嵌块直接存进文档结构，
/// 不再需要标记。保留它是为了老笔记还能正确解析。
final RegExp embedTokenPattern = RegExp(
  r'\[\[(img|ink):([0-9a-fA-F-]{36})\]\]',
);

/// 把正文按富文本解析。老格式（纯文本）返回 null。
List<dynamic>? tryDecodeRichBody(String body) {
  // 富文本一定是 JSON 数组；纯文本几乎不可能以 [ 开头还能解析成数组，
  // 所以这个判断足够稳。
  if (!body.trimLeft().startsWith('[')) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is List ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// 从正文里取出给人看的纯文本。
///
/// 标题、摘要、搜索都靠它。图片和手写块没有对应文字，
/// 用占位词代替，免得整篇只有图片时列表里一片空白。
String notePlainText(String body) {
  final cached = _plainTextCache[body];
  if (cached != null) return cached;

  final ops = tryDecodeRichBody(body);
  final text = ops == null ? body : _plainTextFromOps(ops);

  // 列表每次重建都会问一遍，缓存住避免反复解析 JSON。
  if (_plainTextCache.length > 500) _plainTextCache.clear();
  _plainTextCache[body] = text;
  return text;
}

final Map<String, String> _plainTextCache = {};

/// 一条还没勾上的待办。
class UncheckedTodo {
  const UncheckedTodo({required this.text, required this.offset});

  /// 这一行的文字（前后空白已经去掉）。
  final String text;

  /// 这一行开头在正文里的位置，用来点进去时把光标放在那儿。
  final int offset;
}

/// 正文里还没勾上的待办项。
///
/// Quill 把勾选框记在**行尾那个换行**的 `list: unchecked` 属性上，
/// 所以这里按行扫一遍：换行带 unchecked 的，那一行的文字就是一条待办。
/// 老格式的纯文本没有这个概念，返回空。
List<UncheckedTodo> uncheckedTodos(String body) {
  final cached = _todoCache[body];
  if (cached != null) return cached;

  final todos = <UncheckedTodo>[];
  final ops = tryDecodeRichBody(body);
  if (ops != null) {
    final buffer = StringBuffer();
    // 文档偏移：文字和图片/手写都各占一个位置，和编辑器里的光标位置对齐。
    var offset = 0;
    var lineStart = 0;

    for (final op in ops) {
      if (op is! Map) continue;
      final attributes = op['attributes'];
      final isUnchecked = attributes is Map && attributes['list'] == 'unchecked';
      final insert = op['insert'];

      if (insert is Map) {
        buffer.write('\uFFFC');
        offset += 1;
        continue;
      }
      if (insert is! String) continue;

      for (final char in insert.split('')) {
        if (char != '\n') {
          buffer.write(char);
          offset += 1;
          continue;
        }
        if (isUnchecked) {
          final line = buffer.toString().trim();
          if (line.isNotEmpty) {
            todos.add(UncheckedTodo(text: line, offset: lineStart));
          }
        }
        offset += 1;
        lineStart = offset;
        buffer.clear();
      }
    }
  }

  if (_todoCache.length > 500) _todoCache.clear();
  _todoCache[body] = todos;
  return todos;
}

/// 还没勾上的待办文字，只要文字不要位置。
List<String> uncheckedItems(String body) =>
    uncheckedTodos(body).map((todo) => todo.text).toList();

/// 这一篇还有几条没勾上的待办。列表页的角标、菜单里的数量都用它。
int uncheckedCount(String body) => uncheckedTodos(body).length;

final Map<String, List<UncheckedTodo>> _todoCache = {};

/// 空白字符，外加图片/手写块在正文里的那个占位符。
///
/// Dart 的 `\s` 跟着 ECMAScript 走，全角空格、不换行空格这些都算在内。
final RegExp _notAChar = RegExp(r'[\s\uFFFC]', unicode: true);

/// 数一段正文有多少字。
///
/// 空白（换行、空格、全角空格）不算，图片和手写块那种占位符也不算——
/// 用户想知道的是「写了多少字」，不是这串数据有多长。
int countChars(String text) {
  if (text.isEmpty) return 0;
  return text.replaceAll(_notAChar, '').runes.length;
}

String _plainTextFromOps(List<dynamic> ops) {
  final buffer = StringBuffer();
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is String) {
      buffer.write(insert);
    } else if (insert is Map) {
      buffer.write(insert.containsKey('ink') ? '[手写]' : '[图片]');
    }
  }
  return buffer.toString();
}

/// 正文里出现过的全部图片 id，用于回收没人引用的图片。
Iterable<String> imageIdsIn(String body) sync* {
  final ops = tryDecodeRichBody(body);
  if (ops == null) {
    yield* embedTokenPattern
        .allMatches(body)
        .where((m) => m.group(1) == 'img')
        .map((m) => m.group(2)!);
    return;
  }
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is Map && insert['image'] is String) {
      yield insert['image'] as String;
    }
  }
}

/// 正文里出现过的全部手写画布 id，同样用于回收。
Iterable<String> inkIdsIn(String body) sync* {
  final ops = tryDecodeRichBody(body);
  if (ops == null) {
    yield* embedTokenPattern
        .allMatches(body)
        .where((m) => m.group(1) == 'ink')
        .map((m) => m.group(2)!);
    return;
  }
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is Map && insert['ink'] is String) {
      yield insert['ink'] as String;
    }
  }
}

/// 纯文本笔记的派生信息：标题取第一段非空内容，其余作摘要。
String noteTitle(String body) {
  for (final line in notePlainText(body).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '新建笔记';
}

String notePreview(String body) {
  final lines = notePlainText(body).split('\n');
  final titleIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (titleIndex == -1) return '无附加内容';
  final rest = lines
      .skip(titleIndex + 1)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join(' ');
  return rest.isEmpty ? '无附加内容' : rest;
}

/// 列表里的时间显示：今天只给时分，昨天给「昨天」，今年给月日，更早给完整日期。
String formatListTime(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final that = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(that).inDays;

  if (diffDays == 0) return '${_two(local.hour)}:${_two(local.minute)}';
  if (diffDays == 1) return '昨天';
  if (local.year == current.year) return '${local.month}月${local.day}日';
  return '${local.year}年${local.month}月${local.day}日';
}

/// 冲突副本标题后缀用的时间戳。
String formatConflictStamp(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// 把「（冲突副本 …）」后缀加在首行标题末尾，正文其余部分原样保留。
///
/// 正文可能是富文本，也可能还是老格式，两种都要处理。
String buildConflictCopyBody(String originalBody, DateTime time) {
  final suffix = '（冲突副本 ${formatConflictStamp(time)}）';

  final ops = tryDecodeRichBody(originalBody);
  if (ops != null) return _suffixFirstLineOfOps(ops, suffix);

  final lines = originalBody.split('\n');
  final titleIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (titleIndex == -1) return '未命名笔记$suffix';
  lines[titleIndex] = '${lines[titleIndex]}$suffix';
  return lines.join('\n');
}

/// 富文本版本：找到第一段有内容的文字，在后缀在它那一行末尾。
String _suffixFirstLineOfOps(List<dynamic> ops, String suffix) {
  final result = <dynamic>[];
  var done = false;

  for (final op in ops) {
    if (done || op is! Map || op['insert'] is! String) {
      result.add(op);
      continue;
    }

    final lines = (op['insert'] as String).split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      lines[i] = '${lines[i]}$suffix';
      done = true;
      break;
    }
    result.add({...op, 'insert': lines.join('\n')});
  }

  // 整篇都是图片和手写，没有文字可加后缀，就在最前面补一个标题。
  if (!done) result.insert(0, {'insert': '未命名笔记$suffix\n'});
  return jsonEncode(result);
}

String _two(int value) => value.toString().padLeft(2, '0');
