import 'package:flutter/material.dart';

/// 一个简单的文本输入弹框。
///
/// controller 由弹框自己持有、自己在 dispose 里释放。如果让调用方
/// 在 `showDialog` 的 future 完成后 dispose，弹框的关闭动画还在跑，
/// 就会撞上「controller 已被释放」的报错。
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.hint,
    this.initial,
    this.helperText,
    this.obscureText = false,
  });

  final String title;
  final String confirmLabel;
  final String? hint;
  final String? initial;
  final String? helperText;

  /// 登录密码这类凭据要遮蔽；笔记口令刻意不遮蔽。
  final bool obscureText;

  /// 弹出来并等用户输入。返回 null 表示取消。
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? hint,
    String? initial,
    String? helperText,
    bool obscureText = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: title,
        confirmLabel: confirmLabel,
        hint: hint,
        initial: initial,
        helperText: helperText,
        obscureText: obscureText,
      ),
    );
  }

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscureText,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.helperText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
