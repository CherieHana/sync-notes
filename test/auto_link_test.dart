import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/auto_link.dart';
import 'package:sync_notes/services/rich_body.dart';

/// 打字时的自动链接。
///
/// 库自带的两条规则只认带 `http://` `https://` 的网址，用户平时写的
/// `www.example.com`、`example.com` 打了空格也不会变链接——上一版就是这样，
/// 被反馈「链接自动识别没作用」。这里把这一条钉住。
void main() {
  /// 照着人的手感敲字：一个字一个字地插到光标处（正文末尾、结尾换行之前）。
  Document typeInto(Document document, String text) {
    for (final char in text.split('')) {
      document.insert(document.length - 1, char);
    }
    return document;
  }

  /// 正文里带链接的那几段。
  List<({String text, String link})> linksIn(Document document) => [
    for (final op in document.toDelta().toList())
      if (op.attributes?[Attribute.link.key] != null && op.data is String)
        (text: op.data! as String, link: op.attributes![Attribute.link.key]!),
  ];

  test('带协议的网址还是照旧自动变链接（库自带规则）', () {
    final document = typeInto(RichBody.documentFrom(''), 'https://example.com');
    expect(linksIn(document).single.link, 'https://example.com');
  });

  test('敲一个光秃秃的域名再打空格，也会变链接，并补上 https://', () {
    final document = typeInto(RichBody.documentFrom(''), 'www.example.com ');

    final link = linksIn(document).single;
    expect(link.text, 'www.example.com');
    expect(link.link, 'https://www.example.com', reason: '没协议的话浏览器不认');
  });

  test('句子中间的域名一样认', () {
    final document = typeInto(RichBody.documentFrom(''), '看这个 www.example.com 不错');

    final link = linksIn(document).single;
    expect(link.link, 'https://www.example.com');
    expect(document.toPlainText(), '看这个 www.example.com 不错\n');
  });

  test('回车收尾也会变链接', () {
    final document = typeInto(RichBody.documentFrom(''), 'example.com');
    document.insert(document.length - 1, '\n');

    expect(linksIn(document).single.link, 'https://example.com');
  });

  test('带路径和查询串的域名整段都进链接', () {
    final document = typeInto(
      RichBody.documentFrom(''),
      'baidu.com/s?wd=天气 ',
    );

    expect(linksIn(document).single.link, 'https://baidu.com/s?wd=天气');
  });

  group('不该被当成网址', () {
    for (final word in ['报告.pdf', '3.14', 'v1.2', 'a.bc', '见', 'a.']) {
      test('「$word」打完空格还是普通文字', () {
        final document = typeInto(RichBody.documentFrom(''), '$word ');
        expect(linksIn(document), isEmpty, reason: '$word 不是网址');
      });
    }
  });

  test('只认常见顶级域名', () {
    expect(AutoLinkBareDomainRule.looksLikeBareDomain('www.baidu.com'), isTrue);
    expect(AutoLinkBareDomainRule.looksLikeBareDomain('a.cn'), isTrue);
    expect(AutoLinkBareDomainRule.looksLikeBareDomain('a.zzz'), isFalse);
    // 带协议的交给库自带的规则，别重复处理。
    expect(
      AutoLinkBareDomainRule.looksLikeBareDomain('https://example.com'),
      isFalse,
    );
  });
}
