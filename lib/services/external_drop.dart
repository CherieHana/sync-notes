import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 从软件外部拖进来的一批内容。
class DroppedContent {
  const DroppedContent({this.files = const [], this.text});

  /// 拖进来的文件路径。从资源管理器拖文件过来时是这个。
  final List<String> files;

  /// 拖进来的文本。从网页或别的文档里拖一段选中的文字时是这个。
  final String? text;

  bool get isEmpty =>
      files.isEmpty && (text == null || text!.trim().isEmpty);
}

/// 接收系统拖放事件。
///
/// 目前只有 Windows 实现了原生接收端：用 OLE 的 IDropTarget，
/// 文件和选中的文字都能收到。手机端不做。
class ExternalDrop {
  const ExternalDrop._();

  static const MethodChannel _channel = MethodChannel('sync_notes/drop');
  static final StreamController<DroppedContent> _controller =
      StreamController<DroppedContent>.broadcast();

  static bool get isSupported => defaultTargetPlatform == TargetPlatform.windows;

  /// 拖进来的内容。编辑器页面订阅它。
  static Stream<DroppedContent> get stream => _controller.stream;

  /// App 启动时调一次，把原生那边的回调接上。
  static void listen() {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'dropped') return null;
      final arguments = call.arguments;
      if (arguments is! Map) return null;

      final files =
          (arguments['files'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      final content = DroppedContent(
        files: files,
        text: arguments['text'] as String?,
      );
      if (!content.isEmpty && !_controller.isClosed) {
        _controller.add(content);
      }
      return null;
    });
  }
}
