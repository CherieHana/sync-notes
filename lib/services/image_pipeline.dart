import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

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

/// 一次选图的结果：成功的按选中顺序排好，失败的带着原因。
class PickedImages {
  const PickedImages({this.images = const [], this.failed = const []});

  final List<PreparedImage> images;

  /// 每一条是「哪张图 + 为什么没进来」，用来给用户一句提示。
  final List<String> failed;

  bool get isEmpty => images.isEmpty && failed.isEmpty;
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

  /// 选图。相册支持一次选多张，按选中的先后返回；相机一次一张。
  ///
  /// 单张失败不打断整批：能插的先插进去，失败的在 [_PickedImages.failed] 里报给用户。
  static Future<PickedImages> pickMany({bool fromCamera = false}) async {
    final picker = ImagePicker();
    if (fromCamera) {
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return const PickedImages();
      return _prepareAll([picked]);
    }

    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return const PickedImages();
    return _prepareAll(picked);
  }

  /// 选一张图。返回 null 表示用户取消了。相机和「只想要一张」的场景用这个。
  static Future<PreparedImage?> pick({bool fromCamera = false}) async {
    final picked = await pickMany(fromCamera: fromCamera);
    return picked.images.isEmpty ? null : picked.images.first;
  }

  static Future<PickedImages> _prepareAll(List<XFile> files) async {
    final images = <PreparedImage>[];
    final failed = <String>[];

    for (final file in files) {
      final name = p.basename(file.path);
      try {
        final raw = await file.readAsBytes();
        if (raw.length > maxSourceBytes) {
          throw const ImageTooLargeException('原图超过 20MB');
        }
        images.add(await prepare(raw));
      } on ImageTooLargeException catch (error) {
        failed.add('$name：${error.message}');
      } catch (_) {
        failed.add('$name：读不出来');
      }
    }
    return PickedImages(images: images, failed: failed);
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
