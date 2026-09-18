import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

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

    final raw = result['bytes'];
    if (raw is! Uint8List) return null;

    switch (result['format']) {
      case 'file':
        // 剪切板里直接放的就是图片文件字节，不用再处理。
        return raw;
      case 'rgba':
        final width = result['width'];
        final height = result['height'];
        if (width is! int || height is! int) return null;
        // 平台那边给的是原始像素，编码成 PNG 才能进后续的压缩流程。
        // 一张截图有上百万像素，放后台 isolate 里做，别卡住界面。
        return compute(_encodeRgba, (raw, width, height));
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
