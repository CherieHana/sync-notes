import 'package:flutter/material.dart';

import '../services/ink_strokes.dart';
import 'widgets/ink_view.dart';

/// 全屏手写画布。
///
/// 为什么不在正文里直接画：正文本体是一个输入框，它自己要用拖动手势做选词，
/// 再叠一层画笔两者会互相抢手势。全屏写空间也大得多，手机上体验明显更好。
///
/// 保存时返回笔画列表，取消返回 null。
class InkCanvasPage extends StatefulWidget {
  const InkCanvasPage({super.key, required this.initialStrokes});

  final List<InkStroke> initialStrokes;

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

  late List<InkStroke> _strokes = List<InkStroke>.from(widget.initialStrokes);
  final List<List<InkStroke>> _undoStack = [];

  List<InkPoint>? _drawing;
  bool _erasing = false;
  int _color = _colors.first;
  double _width = _widths[1];
  bool _useEraser = false;

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

  InkPoint _normalize(Offset local, Size size) => InkPoint(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _onPanStart(DragStartDetails details, Size size) {
    if (_useEraser) {
      _pushUndo();
      _erasing = true;
      _eraseAt(details.localPosition, size);
      return;
    }
    _pushUndo();
    setState(() => _drawing = [_normalize(details.localPosition, size)]);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_useEraser) {
      _eraseAt(details.localPosition, size);
      return;
    }
    final drawing = _drawing;
    if (drawing == null) return;
    setState(() => drawing.add(_normalize(details.localPosition, size)));
  }

  void _onPanEnd() {
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
  void _eraseAt(Offset local, Size size) {
    if (!_erasing) return;
    final kept = <InkStroke>[];
    var removed = false;
    for (final stroke in _strokes) {
      final hit = stroke.points.any(
        (point) =>
            (Offset(point.x * size.width, point.y * size.height) - local)
                .distance <=
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(_strokes),
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
              child: Center(
                child: AspectRatio(
                  aspectRatio: inkCanvasWidth / inkCanvasHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return GestureDetector(
                        // 用 pan 而不是 panEnd 之外的手势，写到一半抬笔也能收尾。
                        onPanStart: (details) => _onPanStart(details, size),
                        onPanUpdate: (details) => _onPanUpdate(details, size),
                        onPanEnd: (_) => _onPanEnd(),
                        onPanCancel: _onPanEnd,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CustomPaint(
                            painter: InkPainter(strokes: _visibleStrokes),
                            size: Size.infinite,
                          ),
                        ),
                      );
                    },
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
        spacing: 12,
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
            onSelectionChanged: (value) =>
                setState(() => _useEraser = value.first),
          ),
          for (final color in _colors)
            GestureDetector(
              onTap: () => setState(() {
                _color = color;
                // 选颜色时自动切回画笔，不然点了颜色还以为能擦。
                _useEraser = false;
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
        ],
      ),
    );
  }
}
