import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

// flutter_quill 只导出了 Rule，没导出它的返回类型 RuleType，不这么引一下
// 根本写不出自定义规则。库自己的导出漏了，等它补上就能去掉这行。
// ignore: implementation_imports
import 'package:flutter_quill/src/rules/rule.dart' show RuleType;

/// 打字时把「看着像网址」的词自动变成链接。
///
/// 库自带的两条规则（AutoFormatLinksRule / AutoFormatMultipleLinksRule）
/// 只认带 `http://` `https://` 前缀的网址。用户直接敲 `www.example.com`、
/// `example.com`，打多少空格都不会变链接——这才是大家平时写网址的样子。
/// 这里补上这一段：打空格或回车收尾时，光标前那个词像个域名就给它加上链接。
///
/// 只**加**不删：用户自己插的链接、别的规则认出来的链接都不去动它，
/// 免得打字打到一半把已存在的链接改坏。
class AutoLinkBareDomainRule extends Rule {
  const AutoLinkBareDomainRule();

  /// 词的收尾符。用它触发，而不是每敲一个字都判断，
  /// 这样「baidu.com」敲到一半不会被提前认成网址。
  static const String _terminators = ' \n\t';

  /// 常见顶级域名。
  ///
  /// 光靠「最后一段是字母」判断的话，`报告.pdf`、`v1.2`、`a.bc` 这些
  /// 都会在打空格时变成链接，比不认还烦人，所以这里用白名单卡一道。
  static const Set<String> _tlds = {
    'com', 'cn', 'net', 'org', 'edu', 'gov', 'int', 'mil',
    'info', 'biz', 'name', 'mobi', 'asia', 'co',
    'io', 'ai', 'dev', 'app', 'me', 'cc', 'tv', 'xyz', 'top',
    'site', 'online', 'tech', 'store', 'shop', 'cloud', 'wiki',
    'blog', 'art', 'link', 'live', 'one', 'run', 'pro', 'space',
    'uk', 'us', 'jp', 'kr', 'hk', 'tw', 'sg', 'de', 'fr', 'ru',
    'au', 'ca', 'it', 'es', 'nl', 'se', 'ch', 'in', 'br',
  };

  /// 没写协议的网址：至少两段，最后一段是字母。
  static final RegExp _bareDomain = RegExp(
    r'^(?:[a-zA-Z0-9_-]+\.)+[a-zA-Z]{2,}(?::\d+)?(?:[/?#]\S*)?$',
  );

  /// `www.example.com/path?q=1` 这种要不要认成网址。
  static bool looksLikeBareDomain(String word) {
    if (word.isEmpty) return false;
    // 带协议的交给库自带的规则，别在这儿再补一个 https://。
    if (word.startsWith('http://') || word.startsWith('https://')) {
      return false;
    }
    if (!_bareDomain.hasMatch(word)) return false;

    // 域名（去掉路径和端口）的最后一段必须在白名单里。
    final host = word.split(RegExp(r'[/?#]')).first.split(':').first;
    final tld = host.split('.').last.toLowerCase();
    return _tlds.contains(tld);
  }

  @override
  RuleType get type => RuleType.insert;

  @override
  void validateArgs(int? len, Object? data, Attribute? attribute) {
    // 插入规则不需要额外校验。
  }

  @override
  Delta? applyRule(
    Document document,
    int index, {
    int? len,
    Object? data,
    Attribute? attribute,
  }) {
    // 一次只处理「敲了一个收尾符」，粘贴一大段不在这里管。
    if (data is! String || data.length != 1) return null;
    if (!_terminators.contains(data)) return null;

    final before = document.toPlainText().substring(0, index);
    // `\S+` 里不含换行，所以这里自然只会匹配「光标所在的这一段」。
    final match = RegExp(r'(\S+)\s*$').firstMatch(before);
    if (match == null) return null;

    final word = match.group(1)!;
    if (!looksLikeBareDomain(word)) return null;

    return Delta()
      ..retain(match.start)
      ..retain(word.length, LinkAttribute('https://$word').toJson())
      // 词和光标之间可能还夹着空白（比如换行），原样留着。
      ..retain(index - match.start - word.length)
      ..insert(data);
  }
}
