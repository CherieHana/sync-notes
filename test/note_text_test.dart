import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/rich_body.dart';
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
    final body = buildConflictCopyBody(
      '购物清单\n牛奶',
      DateTime(2026, 9, 18, 14, 30),
    );
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
    expect(formatListTime(DateTime(2025, 3, 2, 9, 5), now: now), '2025年3月2日');
  });

  test('能从正文里挑出全部图片 id', () {
    const id1 = '11111111-1111-1111-1111-111111111111';
    const id2 = '22222222-2222-2222-2222-222222222222';
    final body = '标题\n[[img:$id1]]\n正文\n[[img:$id2]]';
    expect(imageIdsIn(body).toList(), [id1, id2]);
  });

  test('图片标记写进富文本后还能被认出来', () {
    const id = '33333333-3333-3333-3333-333333333333';
    final body = RichBody.encode(RichBody.documentFrom('标题\n[[img:$id]]\n'));
    expect(imageIdsIn(body).single, id);
  });

  test('不像标记的文本不会被当成图片', () {
    expect(imageIdsIn('普通正文，没有图片').isEmpty, isTrue);
    expect(imageIdsIn('[[img:不是uuid]]').isEmpty, isTrue);
  });

  group('数正文有多少字', () {
    test('中文字一个字算一个', () {
      expect(countChars('今天开会'), 4);
      expect(countChars(''), 0);
    });

    test('换行、空格、全角空格都不算', () {
      expect(countChars('今天 开会\n第二行'), 7);
      expect(countChars('　全角空格　'), 4);
      expect(countChars('   \n\n  '), 0);
    });

    test('图片和手写块不算字', () {
      // 它们在正文里各占一个 \\uFFFC 的位子。
      expect(countChars('看图\uFFFC结束'), 4);
      expect(countChars('\uFFFC'), 0);
    });

    test('emoji 这样的字符按一个算', () {
      expect(countChars('开心😀'), 3);
    });

    test('老格式的笔记打开后，图片标记也不占字数', () {
      const inkId = '44444444-4444-4444-4444-444444444444';
      // 老格式的 [[ink:…]] 打开时会换成内嵌块，不再是一串看得见的字。
      final document = RichBody.documentFrom('标题\n[[ink:$inkId]]');
      expect(countChars(document.toPlainText()), 2);
    });
  });
}
