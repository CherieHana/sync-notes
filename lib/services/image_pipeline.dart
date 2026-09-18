import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// 处理好的图片：已经压到合适的尺寸和体积，可以直接落盘上传。
class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 选图与压缩。
///
/// 压到长边 1600、JPEG 质量 82。手机拍的原图动辄四五兆，直接传上去既慢又占
/// 空间，而这个尺寸在手机和电脑上看都足够清楚。
class ImagePipeline {
  const ImagePipeline._();

  static const int maxEdge = 1600;
  static const int jpegQuality = 82;

  /// 原文件超过这个大小直接拒绝，免得在解码阶段就把内存吃满。
  static const int maxSourceBytes = 20 * 1024 * 1024;

  /// 压缩后仍然超过这个大小也拒绝，多半是格式特别怪。
  static const int maxResultBytes = 5 * 1024 * 1024;

  static const List<String> imageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
  ];

  /// 按后缀粗略判断是不是图片。真正的把关在解码那一步，
  /// 这里只是避免把明显不是图片的文件丢进解码器。
  static bool looksLikeImage(String path) {
    final lower = path.toLowerCase();
    return imageExtensions.any(lower.endsWith);
  }

  /// 选一张图。返回 null 表示用户取消了。
  static Future<PreparedImage?> pick({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return null;

    final raw = await picked.readAsBytes();
    if (raw.length > maxSourceBytes) {
      throw const ImageTooLargeException('原图超过 20MB，换一张小一点的吧');
    }
    return prepare(raw);
  }

  /// 压缩。解码和重编码放在后台 isolate 里做，免得卡住界面。
  static Future<PreparedImage> prepare(Uint8List raw) async {
    final prepared = await compute(_compress, raw);
    if (prepared.bytes.length > maxResultBytes) {
      throw const ImageTooLargeException('压缩后仍然超过 5MB，换一张图片试试');
    }
    return prepared;
  }
}

PreparedImage _compress(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw const ImageTooLargeException('这个文件不是能识别的图片格式');
  }

  var image = decoded;
  final longEdge = image.width > image.height ? image.width : image.height;
  if (longEdge > ImagePipeline.maxEdge) {
    // 按长边等比缩放，短边自动跟着算，避免图片被拉变形。
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: ImagePipeline.maxEdge,
            interpolation: img.Interpolation.linear,
          )
        : img.copyResize(
            image,
            height: ImagePipeline.maxEdge,
            interpolation: img.Interpolation.linear,
          );
  }

  final encoded = img.encodeJpg(image, quality: ImagePipeline.jpegQuality);
  return PreparedImage(
    bytes: Uint8List.fromList(encoded),
    width: image.width,
    height: image.height,
  );
}
