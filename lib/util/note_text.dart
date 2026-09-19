/// 正文里内嵌元素的标记。
///
/// `[[img:<uuid>]]` 是插入的图片，`[[ink:<uuid>]]` 是一块手写画布。
/// 用自定义标记而不是 markdown 语法，是为了让「这里就是一个内嵌块」
/// 这件事没有歧义——导入的 markdown 里也可能有图片语法，混在一起会认错。
final RegExp embedTokenPattern = RegExp(r'\[\[(img|ink):([0-9a-fA-F-]{36})\]\]');

/// 正文里出现过的全部图片 id，用于回收没人引用的图片。
Iterable<String> imageIdsIn(String body) => embedTokenPattern
    .allMatches(body)
    .where((m) => m.group(1) == 'img')
    .map((m) => m.group(2)!);

/// 正文里出现过的全部手写画布 id，同样用于回收。
Iterable<String> inkIdsIn(String body) => embedTokenPattern
    .allMatches(body)
    .where((m) => m.group(1) == 'ink')
    .map((m) => m.group(2)!);

String imageMarker(String id) => '[[img:$id]]';

String inkMarker(String id) => '[[ink:$id]]';

/// 纯文本笔记的派生信息：标题取第一段非空内容，其余作摘要。
String noteTitle(String body) {
  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '新建笔记';
}

String notePreview(String body) {
  final lines = body.split('\n');
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
String buildConflictCopyBody(String originalBody, DateTime time) {
  final suffix = '（冲突副本 ${formatConflictStamp(time)}）';
  final lines = originalBody.split('\n');
  final titleIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (titleIndex == -1) return '未命名笔记$suffix';
  lines[titleIndex] = '${lines[titleIndex]}$suffix';
  return lines.join('\n');
}

String _two(int value) => value.toString().padLeft(2, '0');
