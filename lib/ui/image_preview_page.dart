import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 图片预览：点正文里的图打开，可以放大看细节。
///
/// 缩放方式按常用的来：手机双指捏合、电脑鼠标滚轮直接滚（不用按 Ctrl）、
/// 双击在图和 1:1 之间切换。放大之后拖着平移。
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({super.key, required this.path, this.title});

  /// 图片在本机的完整路径。
  final String path;

  /// 标题栏上显示的文字，一般给个文件名。
  final String? title;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  static const double minScale = 1;
  static const double maxScale = 8;

  /// 双击放大到这个倍数。
  static const double doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  Offset? _lastDoubleTapPosition;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _reset() => _transform.value = Matrix4.identity();

  /// 以 [focus] 为中心缩放 [factor] 倍：那个点在屏幕上的位置保持不动。
  void _zoomAround(Offset focus, double factor) {
    final current = _scale;
    final next = (current * factor).clamp(minScale, maxScale);
    if ((next - current).abs() < 0.001) return;

    // 先把屏幕上的点换算成「画面坐标」，再反推平移量——不然缩放会以左上角
    // 为锚点，滚轮一动画面就滑走了。
    final scene = _transform.toScene(focus);
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, focus.dx - scene.dx * next)
      ..setEntry(1, 3, focus.dy - scene.dy * next);
    _transform.value = matrix;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // 滚轮直接缩放：看图片时还要按着 Ctrl 太别扭了。
    _zoomAround(event.localPosition, math.exp(-event.scrollDelta.dy / 320));
  }

  void _handleDoubleTap() {
    final focus = _lastDoubleTapPosition;
    if (focus == null) return;
    if (_scale > 1.05) {
      _reset();
    } else {
      _zoomAround(focus, doubleTapScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title == null || title.isEmpty ? '图片' : title,
          style: const TextStyle(fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '适应屏幕',
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: _reset,
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) =>
            _lastDoubleTapPosition = details.localPosition,
        onDoubleTap: _handleDoubleTap,
        child: Listener(
          onPointerSignal: _handlePointerSignal,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: minScale,
            maxScale: maxScale,
            child: Center(
              child: Image.file(
                File(widget.path),
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '这张图在本地找不到了',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
