import 'package:flutter/material.dart';

import '../../services/block_style.dart';

/// 长按正文里的图片/手写块时弹出的调整面板：整格转向、微调角度、大小、还原。
///
/// 返回用户确认后的样式；点关闭或点外面返回 null（等于没改）。
Future<BlockStyle?> showBlockStyleSheet(
  BuildContext context, {
  required String title,
  required BlockStyle initial,
  required double aspectRatio,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  final panel = _BlockStylePanel(
    title: title,
    initial: initial,
    aspectRatio: aspectRatio,
  );
  if (wide) {
    return showDialog<BlockStyle>(
      context: context,
      builder: (context) => Dialog(child: panel),
    );
  }
  return showModalBottomSheet<BlockStyle>(
    context: context,
    showDragHandle: true,
    builder: (context) => panel,
  );
}

class _BlockStylePanel extends StatefulWidget {
  const _BlockStylePanel({
    required this.title,
    required this.initial,
    required this.aspectRatio,
  });

  final String title;
  final BlockStyle initial;
  final double aspectRatio;

  @override
  State<_BlockStylePanel> createState() => _BlockStylePanelState();
}

class _BlockStylePanelState extends State<_BlockStylePanel> {
  late double _width;
  late double _rotate;

  @override
  void initState() {
    super.initState();
    _width = widget.initial.width ?? _autoWidth;
    _rotate = widget.initial.rotate ?? 0;
  }

  /// 没设过宽度时，滑块默认停在自动尺寸上。
  double get _autoWidth {
    final size = autoBlockSize(aspectRatio: widget.aspectRatio);
    return size.width.clamp(minBlockWidth, maxBlockWidth).toDouble();
  }

  /// 微调滑块的取值范围：围绕最近的 90° 档位 ±45°。
  double get _baseAngle => (_rotate / 90).roundToDouble() * 90;

  /// 滑块都在默认位置时就返回「空样式」——这样正文里不会留没用的属性。
  BlockStyle get _style {
    final isAutoWidth = (_width - _autoWidth).abs() < 0.5;
    if (isAutoWidth && _rotate.abs() < 0.01) return BlockStyle.none;
    return BlockStyle(width: _width, rotate: _rotate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = layoutBlock(
      autoSize: autoBlockSize(aspectRatio: widget.aspectRatio),
      style: _style,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _rotate = (_rotate + 90) % 360),
                  icon: const Icon(Icons.rotate_90_degrees_cw, size: 18),
                  label: const Text('转 90°'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _width = _autoWidth;
                    _rotate = 0;
                  }),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('还原'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '微调 ${(_rotate - _baseAngle).toStringAsFixed(0)}°',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: (_rotate - _baseAngle).clamp(-45, 45).toDouble(),
              min: -45,
              max: 45,
              divisions: 18,
              onChanged: (value) =>
                  setState(() => _rotate = (_baseAngle + value) % 360),
            ),
            Text(
              '大小 ${_width.round()} 像素（实际 ${layout.content.width.round()}×'
              '${layout.content.height.round()}）',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _width.clamp(minBlockWidth, maxBlockWidth).toDouble(),
              min: minBlockWidth,
              max: maxBlockWidth,
              divisions: ((maxBlockWidth - minBlockWidth) / 20).round(),
              onChanged: (value) => setState(() => _width = value),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_style),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
