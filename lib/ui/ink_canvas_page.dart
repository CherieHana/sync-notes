import 'package:flutter/material.dart';

import '../services/export_files.dart';
import '../services/ink_strokes.dart';
import 'widgets/ink_view.dart';

/// 画布页的返回值：笔迹 + 画布标称尺寸（横竖屏切换会改它）。
class InkCanvasResult {
  const InkCanvasResult({
    required this.strokes,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final List<InkStroke> strokes;
  final int canvasWidth;
  final int canvasHeight;
}

/// 全屏手写画布。
///
/// 为什么不在正文里直接画：正文本体是一个输入框，它自己要用拖动手势做选词，
/// 再叠一层画笔两者会互相抢手势。全屏写空间也大得多，手机上体验明显更好。
///
/// 保存时返回 [InkCanvasResult]，取消返回 null。
class InkCanvasPage extends StatefulWidget {
  const InkCanvasPage({
    super.key,
    required this.initialStrokes,
    this.canvasWidth = inkCanvasWidth,
    this.canvasHeight = inkCanvasHeight,
  });

  final List<InkStroke> initialStrokes;

  /// 画布标称尺寸。竖屏 1000×1400、横屏 1400×1000。
  final int canvasWidth;
  final int canvasHeight;

  @override
  State<InkCanvasPage> createState() => _InkCanvasPageState();
}

class _InkCanvasPageState extends State<InkCanvasPage> {
  /// 可选颜色。第一项是默认的黑色。
  static const List<int> _colors = [
    0xFF000000,
    0xFFD32F2F,
    0xFF1976D2,
    0xFF388E3C,
    0xFFF57C00,
  ];

  /// 笔宽，单位是画布坐标（画布按 1000 宽算）。
  static const List<double> _widths = [2, 4, 8];

  static const int _undoLimit = 50;

  /// 橡皮擦的判定半径，像素。
  static const double _eraserRadius = 14;

  /// 画布缩放的上下限和步进。
  static const double _minScale = 0.5;
  static const double _maxScale = 3;
  static const double _scaleStep = 0.25;

  late List<InkStroke> _strokes = List<InkStroke>.from(widget.initialStrokes);
  final List<List<InkStroke>> _undoStack = [];

  late int _canvasWidth = widget.canvasWidth;
  late int _canvasHeight = widget.canvasHeight;

  /// 画布本体的 key：坐标换算要拿它的 RenderBox，缩放平移之后落笔才准。
  final GlobalKey _canvasKey = GlobalKey();

  double _scale = 1;
  Offset _offset = Offset.zero;
  bool _panMode = false;
  Offset? _panFrom;
  Offset _panOrigin = Offset.zero;

  List<InkPoint>? _drawing;
  bool _erasing = false;
  int _color = _colors.first;
  double _width = _widths[1];
  bool _useEraser = false;

  bool _busy = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _pushUndo() {
    _undoStack.add(List<InkStroke>.from(_strokes));
    if (_undoStack.length > _undoLimit) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() => _strokes = _undoStack.removeLast());
  }

  // ---------------------------------------------------------------------
  // 画布：方向与缩放
  // ---------------------------------------------------------------------

  /// 换方向：竖屏 ↔ 横屏，顺带把已有的笔迹一起转 90°。
  ///
  /// 笔迹是归一化坐标，直接对调宽高会被横向拉扁；这里把每个点也转 90°
  /// （竖→横顺时针、横→竖逆时针），画的样子就不变，只是"纸"转了。
  /// 转两次回到原样。
  void _toggleOrientation() {
    final toLandscape = _canvasHeight > _canvasWidth;
    setState(() {
      _strokes = rotateStrokes(_strokes, clockwise: toLandscape);
      final width = _canvasWidth;
      _canvasWidth = _canvasHeight;
      _canvasHeight = width;
      _drawing = null;
    });
  }

  void _zoomBy(double delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale).toDouble();
      if (_scale <= 1) _offset = Offset.zero;
    });
  }

  void _fitCanvas() {
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
    });
  }

  // ---------------------------------------------------------------------
  // 画
  // ---------------------------------------------------------------------

  /// 屏幕坐标 → 画布坐标（0~1）。
  ///
  /// 走 RenderBox.globalToLocal：缩放和平移都套在画布外面，它会把变换链一起
  /// 反算掉，所以放大到 200% 再画，落笔位置照样对。
  InkPoint? _toCanvasPoint(Offset globalPosition) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    return InkPoint(
      (local.dx / box.size.width).clamp(0.0, 1.0),
      (local.dy / box.size.height).clamp(0.0, 1.0),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_panMode) {
      _panFrom = details.globalPosition;
      _panOrigin = _offset;
      return;
    }

    final point = _toCanvasPoint(details.globalPosition);
    if (point == null) return;

    if (_useEraser) {
      _pushUndo();
      _erasing = true;
      _eraseAt(point);
      return;
    }
    _pushUndo();
    setState(() => _drawing = [point]);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panMode) {
      final from = _panFrom;
      if (from == null) return;
      final delta = details.globalPosition - from;
      setState(() => _offset = _panOrigin + delta);
      return;
    }

    final point = _toCanvasPoint(details.globalPosition);
    if (point == null) return;

    if (_useEraser) {
      _eraseAt(point);
      return;
    }
    final drawing = _drawing;
    if (drawing == null) return;
    setState(() => drawing.add(point));
  }

  void _onPanEnd() {
    if (_panMode) {
      _panFrom = null;
      return;
    }
    if (_useEraser) {
      _erasing = false;
      return;
    }
    final drawing = _drawing;
    if (drawing == null) return;
    setState(() {
      _strokes = [
        ..._strokes,
        InkStroke(color: _color, width: _width, points: drawing),
      ];
      _drawing = null;
    });
  }

  /// 橡皮擦：碰到哪一笔就整笔删掉。
  ///
  /// 不做像素级擦除——手写批注里整笔删更符合直觉，数据也简单得多。
  void _eraseAt(InkPoint point) {
    if (!_erasing) return;
    final kept = <InkStroke>[];
    var removed = false;
    for (final stroke in _strokes) {
      final hit = stroke.points.any(
        (candidate) =>
            Offset(
              (candidate.x - point.x) * _canvasWidth,
              (candidate.y - point.y) * _canvasHeight,
            ).distance <=
            _eraserRadius,
      );
      if (hit) {
        removed = true;
      } else {
        kept.add(stroke);
      }
    }
    if (!removed) return;
    setState(() => _strokes = kept);
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _pushUndo();
    setState(() => _strokes = const []);
  }

  /// 正在画的这一笔也要显示出来，否则手感会滞后。
  List<InkStroke> get _visibleStrokes {
    final drawing = _drawing;
    if (drawing == null) return _strokes;
    return [
      ..._strokes,
      InkStroke(color: _color, width: _width, points: drawing),
    ];
  }

  // ---------------------------------------------------------------------
  // 导出
  // ---------------------------------------------------------------------

  Future<void> _exportPng() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await renderStrokesToPng(
        strokes: _strokes,
        canvasWidth: _canvasWidth,
        canvasHeight: _canvasHeight,
      );
      if (!mounted) return;
      if (bytes == null) {
        _toast('导出失败，画布尺寸不对');
        return;
      }
      final saved = await saveBytesAs(
        fileName: '手写-${exportStamp()}.png',
        bytes: bytes,
        mimeType: 'image/png',
      );
      if (!mounted) return;
      if (saved) _toast('已保存为图片');
    } catch (error) {
      if (mounted) _toast('导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '放弃修改',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('手写', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '导出为图片',
            onPressed: _busy ? null : () => _exportPng(),
            icon: const Icon(Icons.image_outlined),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              InkCanvasResult(
                strokes: _strokes,
                canvasWidth: _canvasWidth,
                canvasHeight: _canvasHeight,
              ),
            ),
            child: const Text('完成'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(theme),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: ClipRect(
                child: Center(
                  child: Transform.translate(
                    offset: _offset,
                    child: Transform.scale(
                      scale: _scale,
                      child: AspectRatio(
                        aspectRatio: _canvasWidth / _canvasHeight,
                        child: GestureDetector(
                          // 用 pan 而不是 panEnd 之外的手势，写到一半抬笔也能收尾。
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: (_) => _onPanEnd(),
                          onPanCancel: _onPanEnd,
                          child: Container(
                            key: _canvasKey,
                            foregroundDecoration: BoxDecoration(
                              color: _panMode
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.06,
                                    )
                                  : null,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CustomPaint(
                              painter: InkPainter(strokes: _visibleStrokes),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.edit_outlined, size: 18),
                label: Text('画笔'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.cleaning_services_outlined, size: 18),
                label: Text('橡皮'),
              ),
            ],
            selected: {_useEraser},
            onSelectionChanged: (value) => setState(() {
              _useEraser = value.first;
              _panMode = false;
            }),
          ),
          for (final color in _colors)
            GestureDetector(
              onTap: () => setState(() {
                _color = color;
                // 选颜色时自动切回画笔，不然点了颜色还以为能擦。
                _useEraser = false;
                _panMode = false;
              }),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == color && !_useEraser
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            ),
          for (final width in _widths)
            GestureDetector(
              onTap: () => setState(() {
                _width = width;
                _useEraser = false;
                _panMode = false;
              }),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _width == width && !_useEraser
                      ? theme.colorScheme.primaryContainer
                      : null,
                ),
                child: Container(
                  width: width * 2.2,
                  height: width * 2.2,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: '撤销',
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _toggleOrientation,
            icon: Icon(
              _canvasHeight > _canvasWidth
                  ? Icons.stay_current_portrait
                  : Icons.stay_current_landscape,
              size: 18,
            ),
            label: Text(_canvasHeight > _canvasWidth ? '竖屏' : '横屏'),
          ),
          IconButton(
            tooltip: _panMode ? '回到画线' : '移动画布',
            onPressed: () => setState(() {
              _panMode = !_panMode;
              if (!_panMode) _offset = Offset.zero;
            }),
            isSelected: _panMode,
            icon: const Icon(Icons.open_with),
            selectedIcon: const Icon(Icons.open_with),
          ),
          IconButton(
            tooltip: '缩小',
            onPressed: _scale <= _minScale ? null : () => _zoomBy(-_scaleStep),
            icon: const Icon(Icons.zoom_out),
          ),
          Text('${(_scale * 100).round()}%', style: theme.textTheme.bodySmall),
          IconButton(
            tooltip: '放大',
            onPressed: _scale >= _maxScale ? null : () => _zoomBy(_scaleStep),
            icon: const Icon(Icons.zoom_in),
          ),
          IconButton(
            tooltip: '适应画布',
            onPressed: _fitCanvas,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
        ],
      ),
    );
  }
}
