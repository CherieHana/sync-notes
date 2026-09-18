import 'package:flutter/material.dart';

import '../data/local/local_store.dart';
import '../services/note_lock.dart';
import '../util/note_text.dart';

/// 加锁笔记的解锁页。
///
/// 口令输入框刻意不做 `***` 遮蔽：这道锁挡的是拿到手机的人，
/// 不是旁边看着屏幕的人，能看见自己输了什么可以省掉打错的麻烦。
class NoteUnlockView extends StatefulWidget {
  const NoteUnlockView({
    super.key,
    required this.note,
    required this.onUnlocked,
    required this.onForgotPassphrase,
  });

  final LocalNote note;
  final VoidCallback onUnlocked;
  final VoidCallback onForgotPassphrase;

  @override
  State<NoteUnlockView> createState() => _NoteUnlockViewState();
}

class _NoteUnlockViewState extends State<NoteUnlockView> {
  final TextEditingController _passphrase = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final value = _passphrase.text;
    if (value.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await NoteLock.verify(
      passphrase: value,
      hash: widget.note.passphraseHash,
      salt: widget.note.passphraseSalt,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = '口令不对';
    });
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                noteTitle(widget.note.body),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '这篇笔记加了锁，输入口令才能打开',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passphrase,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '口令',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _busy ? null : _unlock(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('解锁'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : widget.onForgotPassphrase,
                child: const Text('忘记口令？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
