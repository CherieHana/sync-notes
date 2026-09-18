import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/util/note_text.dart';

void main() {
  test('标题取第一段非空内容，前面有空行也不影响', () {
    expect(noteTitle('\n\n  会议记录  \n第二行'), '会议记录');
    expect(noteTitle(''), '新建笔记');
  });

  test('摘要跳过标题，只取后面的内容', () {
    expect(notePreview('标题\n正文一\n正文二'), '正文一 正文二');
    expect(notePreview('只有标题'), '无附加内容');
  });

  test('冲突副本的后缀加在首行末尾，正文其余部分不动', () {
    final body = buildConflictCopyBody('购物清单\n牛奶', DateTime(2026, 9, 18, 14, 30));
    final lines = body.split('\n');
    expect(lines.first, '购物清单（冲突副本 2026-09-18 14:30）');
    expect(lines[1], '牛奶');
  });

  test('空正文的冲突副本也会有一条能看的标题', () {
    final body = buildConflictCopyBody('', DateTime(2026, 9, 18, 14, 30));
    expect(body, contains('冲突副本 2026-09-18 14:30'));
  });

  test('列表时间：今天看时分，昨天看「昨天」，今年看月日', () {
    final now = DateTime(2026, 9, 18, 20, 0);
    expect(formatListTime(DateTime(2026, 9, 18, 9, 5), now: now), '09:05');
    expect(formatListTime(DateTime(2026, 9, 17, 9, 5), now: now), '昨天');
    expect(formatListTime(DateTime(2026, 3, 2, 9, 5), now: now), '3月2日');
    expect(
      formatListTime(DateTime(2025, 3, 2, 9, 5), now: now),
      '2025年3月2日',
    );
  });
}
