import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/rich_body.dart';
import 'package:sync_notes/util/note_text.dart';

/// 正文格式转换的测试。
///
/// 正文现在是 Quill Delta 的 JSON，但老笔记还是纯文本，两种格式都要认。
/// 这里把「读进来、存回去、两边派生信息都对」这几件事钉住。
void main() {
  const imageId = '11111111-1111-1111-1111-111111111111';
  const inkId = '22222222-2222-2222-2222-222222222222';

  /// 文档里每一段插入内容的类型，图片和手写是 Map，文字是 String。
  List<Object> insertTypes(Document document) => [
    for (final op in document.toDelta().toJson())
      (op as Map)['insert'] as Object,
  ];

  test('老笔记的纯文本能读成文档，标记变成内嵌块', () {
    final document = RichBody.documentFrom(
      '标题\n[[img:$imageId]]\n[[ink:$inkId]]\n结尾',
    );

    final embeds = insertTypes(document).whereType<Map>().toList();
    expect(embeds.map((e) => e.keys.first), ['image', 'ink']);
    expect(embeds[0]['image'], imageId);
    expect(embeds[1]['ink'], inkId);

    // 文字部分原样保留，标题和摘要才取得到。
    expect(document.toPlainText(), contains('标题'));
    expect(document.toPlainText(), contains('结尾'));
  });

  test('空正文也能变成一个合法文档', () {
    final document = RichBody.documentFrom('');
    expect(document.toPlainText().trim(), isEmpty);
    expect(
      () => Document.fromJson(RichBody.opsFromPlainText('')),
      returnsNormally,
    );
  });

  test('存出去再读回来，内容和样式都不变', () {
    final document = RichBody.documentFrom('重点内容\n第二行');
    document.format(0, 4, const ColorAttribute('#ffd32f2f'));

    final body = RichBody.encode(document);
    final reloaded = RichBody.documentFrom(body);

    expect(body, startsWith('['));
    expect(reloaded.toPlainText(), document.toPlainText());
    expect(body, contains('#ffd32f2f'));
  });

  test('富文本正文里能取出图片、手写和纯文本', () {
    final body = RichBody.encode(
      RichBody.documentFrom('标题\n[[img:$imageId]]\n[[ink:$inkId]]'),
    );

    expect(imageIdsIn(body), [imageId]);
    expect(inkIdsIn(body), [inkId]);
    expect(noteTitle(body), '标题');
    expect(notePlainText(body), contains('[图片]'));
    expect(notePlainText(body), contains('[手写]'));
  });

  test('冲突副本的后缀加在富文本的首行末尾', () {
    final body = RichBody.encode(RichBody.documentFrom('购物清单\n牛奶'));
    final copy = buildConflictCopyBody(body, DateTime(2026, 9, 18, 14, 30));

    expect(copy, startsWith('['));
    expect(noteTitle(copy), '购物清单（冲突副本 2026-09-18 14:30）');
    expect(notePlainText(copy), contains('牛奶'));
  });

  group('插入内嵌块', () {
    test('块独占一行，光标落到块下面那一行的行首', () {
      final document = RichBody.documentFrom('第一行\n第二行\n');
      // 光标停在第一行末尾。
      final caret = RichBody.insertBlockEmbed(
        document,
        3,
        BlockEmbed.image(imageId),
      );

      // 块自己占一行，下面空一行给光标，原来的第二行往后挪。
      expect(document.toPlainText(), '第一行\n\uFFFC\n\n第二行\n');
      expect(insertTypes(document).whereType<Map>().single['image'], imageId);

      // 接着打的字落在块下面，不会挤到图片那一行上去。
      document.insert(caret, '图下面');
      expect(document.toPlainText(), '第一行\n\uFFFC\n图下面\n第二行\n');
    });

    test('块插在行首或文末时，光标都有下面一行可站', () {
      final atStart = RichBody.documentFrom('正文');
      final startCaret = RichBody.insertBlockEmbed(
        atStart,
        0,
        BlockEmbed.image(imageId),
      );
      expect(atStart.toPlainText(), '\uFFFC\n\n正文\n');
      atStart.insert(startCaret, '开头');
      expect(atStart.toPlainText(), '\uFFFC\n开头\n正文\n');

      final atEnd = RichBody.documentFrom('正文');
      final endCaret = RichBody.insertBlockEmbed(
        atEnd,
        2,
        BlockEmbed('ink', inkId),
      );
      expect(atEnd.toPlainText(), '正文\n\uFFFC\n\n');
      atEnd.insert(endCaret, '结尾');
      expect(atEnd.toPlainText(), '正文\n\uFFFC\n结尾\n');
    });
  });

  test('正文格式判定：JSON 数组算富文本，普通文字不算', () {
    expect(tryDecodeRichBody('[{"insert":"\\n"}]'), isNotNull);
    expect(tryDecodeRichBody('标题\n正文'), isNull);
    // 一句话而已，不能因为以 [ 开头就当成富文本。
    expect(tryDecodeRichBody('[图片] 这一段是正文'), isNull);
  });

  test('存下来的正文是合法 JSON', () {
    final body = RichBody.encode(RichBody.documentFrom('标题'));
    expect(jsonDecode(body), isA<List<dynamic>>());
  });
}
