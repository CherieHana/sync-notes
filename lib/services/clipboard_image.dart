import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'image_pipeline.dart';

/// 从系统剪切板里读一张图片。
///
/// 目前只实现了 Windows：桌面上的截图工具、浏览器里右键复制图片，都会把图片
/// 放进系统剪切板，而 Flutter 自带的 Clipboard 只认文本，读不到图片。
///
/// 手机端不做这件事：安卓的图片剪切板走的是 content:// 那一套，
/// 而且手机上"复制图片再粘贴到文本框"本身也不是常见操作。
class ClipboardImage {
  const ClipboardImage._();

  static const MethodChannel _channel = MethodChannel(
    'sync_notes/clipboard_image',
  );

  /// 当前平台是否支持。界面据此决定要不要露出「粘贴图片」这个入口。
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.windows;

  /// 读剪切板里的图片，返回能直接交给 ImagePipeline 的图片字节。
  /// 剪切板里没有图片（或者平台不支持）时返回 null。
  static Future<Uint8List?> read() async {
    if (!isSupported) return null;

    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('readImage');
    if (result == null) return null;

    // 注意：不能在这里先统一要求 bytes 存在。
    // 「复制的是文件」那条路给的是路径、没有 bytes 字段，
    // 提前判空会让文件路径这条路直接返回 null。
    switch (result['format']) {
      case 'file':
        // 剪切板里直接放的就是图片文件字节，不用再处理。
        final raw = result['bytes'];
        return raw is Uint8List ? raw : null;
      case 'rgba':
        final raw = result['bytes'];
        final width = result['width'];
        final height = result['height'];
        if (raw is! Uint8List || width is! int || height is! int) return null;
        // 平台那边给的是原始像素，编码成 PNG 才能进后续的压缩流程。
        // 一张截图有上百万像素，放后台 isolate 里做，别卡住界面。
        return compute(_encodeRgba, (raw, width, height));
      case 'path':
        // 在资源管理器里复制的文件，剪切板上只有路径。
        final path = result['path'];
        if (path is! String) return null;
        // 只认图片；复制一个 txt 过来时不该往笔记里塞图。
        if (!ImagePipeline.looksLikeImage(path)) return null;
        final file = File(path);
        if (!file.existsSync()) return null;
        return file.readAsBytes();
      default:
        return null;
    }
  }
}

Uint8List _encodeRgba((Uint8List, int, int) args) {
  final (rgba, width, height) = args;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodePng(image));
}
