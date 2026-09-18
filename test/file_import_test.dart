import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/file_import.dart';

void main() {
  ImportedDocument import(String name, List<int> bytes) =>
      FileImport.fromBytes(fileName: name, bytes: Uint8List.fromList(bytes));

  test('UTF-8 文件正常解码，文件名当标题', () {
    final doc = import('会议记录.txt', utf8.encode('第一行\n第二行'));
    expect(doc.title, '会议记录');
    expect(doc.body, '会议记录\n\n第一行\n第二行');
    expect(doc.wasGbk, isFalse);
  });

  test('带 UTF-8 BOM 的文件不会在开头留下怪字符', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('正文')];
    final doc = import('a.txt', bytes);
    expect(doc.body, 'a\n\n正文');
  });

  test('GBK 编码的中文文件不会变成乱码', () {
    final bytes = gbk.encode('这是 GBK 编码的内容');
    final doc = import('旧文档.txt', bytes);
    expect(doc.wasGbk, isTrue);
    expect(doc.body, contains('这是 GBK 编码的内容'));
  });

  test('Windows 的 CRLF 换行统一成 LF', () {
    final doc = import('a.txt', utf8.encode('第一行\r\n第二行\r第三行'));
    expect(doc.body, 'a\n\n第一行\n第二行\n第三行');
  });

  test('markdown 文件按纯文本导入，扩展名不进标题', () {
    final doc = import('读书笔记.md', utf8.encode('# 标题\n\n正文'));
    expect(doc.title, '读书笔记');
    expect(doc.body, '读书笔记\n\n# 标题\n\n正文');
  });

  test('文件名没有扩展名时整串当标题', () {
    expect(FileImport.titleFromFileName('无标题'), '无标题');
  });

  test('空文件报错而不是生成一篇空白笔记', () {
    expect(
      () => import('空.txt', const []),
      throwsA(isA<FormatException>()),
    );
  });
}
