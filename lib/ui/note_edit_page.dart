import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/local/local_store.dart';

/// 编辑页。全屏纯文本，停止输入 0.8 秒自动落库，返回时再补一次。
///
/// 只从本地库读一次内容，不做实时回写：避免远处推来的版本把正在打字的
/// 光标位置冲掉。远端变化会体现在列表上，冲突副本机制保证内容不丢。
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  static const Duration _autosaveDelay = Duration(milliseconds: 800);

  final TextEditingController _body = TextEditingController();
  final FocusNode _focus = FocusNode();

  AppServices? _services;
  LocalNote? _note;
  Timer? _debounce;
  bool _loaded = false;
  String _lastSaved = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _services = AppScope.of(context);
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = _services;
    if (services == null) return;
    final note = await services.local.findById(widget.noteId);
    if (!mounted || note == null) return;
    setState(() {
      _note = note;
      _lastSaved = note.body;
      _body.text = note.body;
      _body.selection = TextSelection.collapsed(offset: note.body.length);
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, () => unawaited(_save()));
  }

  Future<void> _save() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final text = _body.text;
    if (text == _lastSaved) return;
    _lastSaved = text;

    await services.local.updateBody(
      id: note.id,
      body: text,
      now: DateTime.now(),
    );
    _note = note.copyWith(body: text, updatedAt: DateTime.now());
    unawaited(services.sync.sync());
  }

  /// 退出前的收尾：先保存，顺手清掉从头到尾都没写过一个字的空笔记。
  Future<void> _finalize() async {
    await _save();
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;
    if (_body.text.trim().isNotEmpty) return;

    if (note.isNew) {
      // 从没上传过，直接删掉，服务端不会留垃圾记录。
      await services.local.hardDelete(note.id);
    } else {
      await services.local.softDelete(id: note.id, now: DateTime.now());
    }
    unawaited(services.sync.sync());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_finalize());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('笔记', style: TextStyle(fontSize: 15)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _body,
              focusNode: _focus,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 16, height: 1.6),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '写点什么…',
              ),
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
    );
  }
}
