import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:file_picker/file_picker.dart';

/// 从文件读出来的一篇待导入内容。
class ImportedDocument {
  const ImportedDocument({
    required this.title,
    required this.body,
    required this.byteSize,
    required this.wasGbk,
  });

  /// 由文件名（去掉扩展名）得来的标题，会作为正文的第一行。
  final String title;
  final String body;
  final int byteSize;

  /// 是否走了 GBK 解码。界面可以据此提示一句。
  final bool wasGbk;
}

/// 导入 txt / markdown 文件。
///
/// markdown 按纯文本导入，不渲染、也不解析里面的图片链接——
/// 这个应用目前只有一种正文格式，混两种语义会让人分不清看到的是什么。
class FileImport {
  const FileImport._();

  static const List<String> allowedExtensions = ['txt', 'md', 'markdown'];

  /// 超过这个大小的文件先提醒一句。正文越大，每次同步要传的整行也越大。
  static const int largeFileBytes = 1024 * 1024;

  /// 让用户挑文件，支持一次多选。返回空列表表示取消了。
  static Future<List<PlatformFile>> pickFiles() {
    return FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  /// 解析成一个待导入的文档。读不出内容时抛 [FormatException]。
  static Future<ImportedDocument> parse(PlatformFile file) async {
    return fromBytes(fileName: file.name, bytes: await file.readAsBytes());
  }

  /// 从文件名和字节解析。抽出来是为了能脱离文件选择器测试。
  static ImportedDocument fromBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw FormatException('读不到「$fileName」的内容');
    }

    final decoded = decodeText(bytes);
    final title = titleFromFileName(fileName);
    return ImportedDocument(
      title: title,
      // 首行放文件名，这样列表里一眼能看出这篇是从哪个文件来的。
      body: '$title\n\n${decoded.text}',
      byteSize: bytes.length,
      wasGbk: decoded.wasGbk,
    );
  }

  /// 文件名去掉扩展名当标题。
  static String titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final trimmed = base.trim();
    return trimmed.isEmpty ? '导入的笔记' : trimmed;
  }

  /// 先按 UTF-8 严格解码，失败再退回 GBK。
  ///
  /// 国内不少 txt 是 GBK 编码的，直接按 UTF-8 读会得到一堆乱码，
  /// 而且不会报错（除非严格模式），所以这里刻意用严格模式让它抛异常。
  static ({String text, bool wasGbk}) decodeText(Uint8List bytes) {
    var data = bytes;
    // 去掉 UTF-8 BOM，否则正文开头会多一个看不见的字符。
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }

    try {
      return (text: _normalizeNewlines(utf8.decode(data)), wasGbk: false);
    } on FormatException {
      return (text: _normalizeNewlines(gbk.decode(data)), wasGbk: true);
    }
  }

  /// 统一成 \n，编辑器里只认这一种换行。
  static String _normalizeNewlines(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
