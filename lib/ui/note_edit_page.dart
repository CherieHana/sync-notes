import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../app_services.dart';
import '../data/local/local_store.dart';
import '../services/clipboard_image.dart';
import '../services/external_drop.dart';
import '../services/file_import.dart';
import '../services/image_pipeline.dart';
import '../services/ink_strokes.dart';
import '../services/note_lock.dart';
import '../services/rich_body.dart';
import '../util/note_text.dart';
import 'ink_canvas_page.dart';
import 'note_unlock_view.dart';
import 'widgets/folder_picker.dart';
import 'widgets/note_embeds.dart';
import 'widgets/text_prompt_dialog.dart';

/// 编辑页。正文是富文本（加粗、斜体、下划线、颜色、字号、高亮），
/// 停止输入 0.8 秒自动落库，返回时再补一次。
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
  static const Duration _imageRetryDelay = Duration(seconds: 3);

  /// 字号档位。Quill 的字号只有 small/normal/large/huge 四档，
  /// 默认是 10/18/22，这里换成能覆盖大号需求的数值。
  static const double _sizeSmall = 12;
  static const double _sizeNormal = 16;
  static const double _sizeLarge = 22;
  static const double _sizeHuge = 32;

  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  AppServices? _services;
  LocalNote? _note;
  Timer? _debounce;
  Timer? _imageRetry;
  StreamSubscription<DroppedContent>? _dropSubscription;

  bool _loaded = false;
  bool _needsUnlock = false;

  /// 最近一次看到的正文。用来判断文档是不是真的变了（动光标不算）。
  String _lastBody = '';

  /// 已经落库的正文，没变就不用再写一次，也就不会白推一次同步。
  String _lastSavedBody = '';

  /// 图片 id → 渲染信息（本机路径与宽高比）。
  final Map<String, NoteImageInfo> _imageInfo = {};

  /// 手写画布 id → 笔迹与比例。
  final Map<String, NoteInkInfo> _inkInfo = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _services = AppScope.of(context);
    if (ExternalDrop.isSupported) {
      _dropSubscription = ExternalDrop.stream.listen((content) {
        unawaited(_handleDrop(content));
      });
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _imageRetry?.cancel();
    unawaited(_dropSubscription?.cancel());
    unawaited(_changes?.cancel());
    _controller?.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // 载入与保存
  // ---------------------------------------------------------------------

  Future<void> _load() async {
    final services = _services;
    if (services == null) return;

    final note = await services.local.findById(widget.noteId);
    if (!mounted || note == null) return;

    final locked = note.locked && !services.isUnlocked(note.id);
    setState(() {
      _note = note;
      _needsUnlock = locked;
    });
    if (locked || _controller != null) return;

    final document = RichBody.documentFrom(note.body);
    final controller = QuillController(
      document: document,
      // 光标落在正文末尾，接着就能往下写。
      selection: TextSelection.collapsed(offset: document.length - 1),
    );
    _controller = controller;
    _changes = controller.document.changes.listen((_) => _onChanged());
    _lastBody = note.body;
    _lastSavedBody = note.body;

    // 老笔记存的是纯文本，第一次打开就换成富文本存回去，之后不用再转。
    final body = RichBody.encode(document);
    if (body != note.body) {
      _lastBody = body;
      _lastSavedBody = body;
      final now = DateTime.now();
      await services.local.updateBody(id: note.id, body: body, now: now);
      _note = note.copyWith(body: body, updatedAt: now);
      unawaited(services.sync.sync());
    }

    unawaited(_resolveEmbeds(imageIdsIn(body).toSet(), inkIdsIn(body).toSet()));
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final controller = _controller;
    if (controller == null) return;

    final body = RichBody.encode(controller.document);
    if (body == _lastBody) return;
    _lastBody = body;

    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, () => unawaited(_save()));

    unawaited(_resolveEmbeds(imageIdsIn(body).toSet(), inkIdsIn(body).toSet()));
  }

  Future<void> _save() async {
    final services = _services;
    final note = _note;
    final controller = _controller;
    if (services == null || note == null || controller == null) return;
    if (_needsUnlock) return;

    final body = RichBody.encode(controller.document);
    if (body == _lastSavedBody) return;
    _lastSavedBody = body;

    final now = DateTime.now();
    await services.local.updateBody(id: note.id, body: body, now: now);
    _note = note.copyWith(body: body, updatedAt: now);
    unawaited(services.sync.sync());
  }

  /// 退出前的收尾：先保存，顺手清掉从头到尾都没写过一个字的空笔记。
  Future<void> _finalize() async {
    await _save();
    final services = _services;
    final note = _note;
    final controller = _controller;
    if (services == null || note == null || controller == null) return;
    if (_needsUnlock) return;
    if (controller.document.toPlainText().trim().isNotEmpty) return;

    if (note.isNew) {
      // 从没上传过，直接删掉，服务端不会留垃圾记录。
      await services.local.hardDelete(note.id);
    } else {
      await services.local.softDelete(id: note.id, now: DateTime.now());
    }
    unawaited(services.sync.sync());
  }

  // ---------------------------------------------------------------------
  // 撤回
  // ---------------------------------------------------------------------

  /// 撤回一步。Quill 自己记着这份文档的历史（插图片、改样式都算），
  /// 而且是内存里的，退出这篇笔记就没了——正好是需求要的行为。
  void _undoStep() {
    final controller = _controller;
    if (controller == null || !controller.hasUndo) return;
    controller.undo();
    unawaited(_save());
  }

  // ---------------------------------------------------------------------
  // 内嵌块的渲染数据
  // ---------------------------------------------------------------------

  NoteImageInfo _imageInfoOf(String imageId) =>
      _imageInfo[imageId] ?? const NoteImageInfo();

  NoteInkInfo _inkInfoOf(String inkId) =>
      _inkInfo[inkId] ?? const NoteInkInfo();

  /// 把内嵌块需要的数据准备好：图片要本机路径，手写要笔迹。
  /// 还没同步下来的先留空，靠 [_scheduleRetry] 过几秒再试。
  Future<void> _resolveEmbeds(Set<String> imageIds, Set<String> inkIds) async {
    final services = _services;
    if (services == null) return;

    var changed = false;
    for (final id in imageIds) {
      if (_imageInfo[id]?.path != null) continue;
      final exists = await services.local.imageFileExists(id);
      final row = await services.local.findImageById(id);
      final path = exists ? await services.local.imageFilePath(id) : null;
      final width = row?.width;
      final height = row?.height;
      final info = NoteImageInfo(
        path: path,
        // 按原始比例排版。比例来自图片元数据，文件还没下回来时也能算。
        aspectRatio: (width != null && height != null && height > 0)
            ? width / height
            : 4 / 3,
      );
      if (_imageInfo[id]?.path != info.path ||
          _imageInfo[id]?.aspectRatio != info.aspectRatio) {
        _imageInfo[id] = info;
        changed = true;
      }
    }

    for (final id in inkIds) {
      if (_inkInfo[id]?.strokes != null) continue;
      final ink = await services.local.findInkById(id);
      if (ink == null) continue;
      _inkInfo[id] = NoteInkInfo(
        strokes: decodeInkStrokes(ink.strokes),
        aspectRatio: ink.aspectRatio,
      );
      changed = true;
    }

    if (changed && mounted) setState(() {});
    _scheduleRetry(imageIds, inkIds);
  }

  /// 有图片或手写还没下回来时，隔几秒重试一次，等同步把文件拉回来。
  void _scheduleRetry(Set<String> imageIds, Set<String> inkIds) {
    final imagesReady = imageIds.every((id) => _imageInfo[id]?.path != null);
    final inksReady = inkIds.every((id) => _inkInfo[id]?.strokes != null);
    _imageRetry?.cancel();
    if (imagesReady && inksReady) return;

    _imageRetry = Timer(_imageRetryDelay, () {
      final controller = _controller;
      if (!mounted || controller == null) return;
      final body = RichBody.encode(controller.document);
      unawaited(
        _resolveEmbeds(imageIdsIn(body).toSet(), inkIdsIn(body).toSet()),
      );
    });
  }

  // ---------------------------------------------------------------------
  // 图片
  // ---------------------------------------------------------------------

  Future<void> _insertImage({required bool fromCamera}) async {
    if (_services == null) return;

    try {
      final prepared = await ImagePipeline.pick(fromCamera: fromCamera);
      if (prepared == null || !mounted) return;
      await _storeImage(prepared);
    } on ImageTooLargeException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('插入图片失败：$error');
    }
  }

  /// 把系统剪切板里的图片粘进来。目前只有桌面端能用。
  Future<void> _pasteImageFromClipboard() async {
    if (_services == null) return;

    try {
      final raw = await ClipboardImage.read();
      if (!mounted) return;
      if (raw == null) {
        _toast('剪切板里没有图片');
        return;
      }
      final prepared = await ImagePipeline.prepare(raw);
      if (!mounted) return;
      await _storeImage(prepared);
    } on ImageTooLargeException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('粘贴图片失败：$error');
    }
  }

  /// 把处理好的图片存到本地，并在光标处插进正文。
  Future<void> _storeImage(PreparedImage prepared) async {
    final services = _services!;
    final id = const Uuid().v4();
    final now = DateTime.now();
    await services.local.writeImageFile(id, prepared.bytes);
    await services.local.createImage(
      LocalImage(
        id: id,
        // 路径第一段放用户 id，服务端的存储策略据此判断归属。
        storagePath: '${services.userId}/$id.jpg',
        byteSize: prepared.bytes.length,
        width: prepared.width,
        height: prepared.height,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _insertBlock(BlockEmbed.image(id));
    unawaited(services.sync.sync());
  }

  // ---------------------------------------------------------------------
  // 手写画布
  // ---------------------------------------------------------------------

  /// 新建一块手写画布：先进画布页写，写完再插进正文。
  Future<void> _insertInk() async {
    final services = _services;
    if (services == null) return;

    final strokes = await Navigator.of(context).push<List<InkStroke>>(
      MaterialPageRoute(
        builder: (_) => const InkCanvasPage(initialStrokes: []),
      ),
    );
    if (strokes == null || !mounted) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    await services.local.createInk(
      LocalInk(
        id: id,
        strokes: encodeInkStrokes(strokes),
        version: 1,
        baseVersion: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _insertBlock(BlockEmbed(inkEmbedType, id));
    unawaited(services.sync.sync());
  }

  /// 点正文里的手写块，打开全屏继续写。
  Future<void> _openInkCanvas(String inkId) async {
    final services = _services;
    if (services == null) return;

    final ink = await services.local.findInkById(inkId);
    if (ink == null || !mounted) return;

    final strokes = await Navigator.of(context).push<List<InkStroke>>(
      MaterialPageRoute(
        builder: (_) =>
            InkCanvasPage(initialStrokes: decodeInkStrokes(ink.strokes)),
      ),
    );
    if (strokes == null || !mounted) return;

    await services.local.updateInkStrokes(
      id: inkId,
      strokes: encodeInkStrokes(strokes),
      now: DateTime.now(),
    );
    _inkInfo[inkId] = NoteInkInfo(
      strokes: strokes,
      aspectRatio: ink.aspectRatio,
    );
    setState(() {});
    unawaited(services.sync.sync());
  }

  // ---------------------------------------------------------------------
  // 往正文里插东西
  // ---------------------------------------------------------------------

  /// 在光标处插一个块级内嵌（图片或手写画布），让它独占一行。
  void _insertBlock(Embeddable embed) {
    final controller = _controller;
    if (controller == null) return;

    final selection = controller.selection;
    final offset = selection.isValid
        ? selection.start
        : controller.document.length - 1;
    final caret = RichBody.insertBlockEmbed(controller.document, offset, embed);
    controller.updateSelection(
      TextSelection.collapsed(offset: caret),
      ChangeSource.local,
    );
    unawaited(_save());
  }

  /// 在光标处插入一段文字。
  void _insertTextAtCaret(String text) {
    final controller = _controller;
    if (controller == null || text.isEmpty) return;

    final document = controller.document;
    final selection = controller.selection;
    final start = (selection.isValid ? selection.start : document.length - 1)
        .clamp(0, document.length);
    final end = (selection.isValid ? selection.end : document.length - 1).clamp(
      start,
      document.length,
    );
    if (end > start) document.delete(start, end - start);
    document.insert(start, text);
    controller.updateSelection(
      TextSelection.collapsed(offset: start + text.length),
      ChangeSource.local,
    );
    unawaited(_save());
  }

  // ---------------------------------------------------------------------
  // 从软件外拖进来
  // ---------------------------------------------------------------------

  Future<void> _handleDrop(DroppedContent content) async {
    if (_needsUnlock || _controller == null) return;

    // 先处理纯文本：从网页或别的文档里拖一段选中的字过来时只有 text。
    final text = content.text;
    if (text != null && text.trim().isNotEmpty) {
      _insertTextAtCaret(text);
    }

    for (final path in content.files) {
      await _insertDroppedFile(path);
    }
  }

  Future<void> _insertDroppedFile(String path) async {
    final services = _services;
    if (services == null) return;
    final name = p.basename(path);

    try {
      if (ImagePipeline.looksLikeImage(path)) {
        final file = File(path);
        // 先看文件大小，超过上限就别读进内存了。
        final size = file.lengthSync();
        if (size > ImagePipeline.maxSourceBytes) {
          _toast('「$name」超过 20MB，换一张小一点的吧');
          return;
        }
        final prepared = await ImagePipeline.prepare(await file.readAsBytes());
        if (!mounted) return;
        await _storeImage(prepared);
        return;
      }

      if (FileImport.allowedExtensions.any(path.toLowerCase().endsWith)) {
        // 文本文件走和「导入文件」同一套解码，中文 txt 不会乱码。
        final decoded = FileImport.decodeText(await File(path).readAsBytes());
        final title = FileImport.titleFromFileName(name);
        if (!mounted) return;
        _insertTextAtCaret('$title\n\n${decoded.text}');
        return;
      }

      _toast('不认识这种文件：$name');
    } on ImageTooLargeException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('「$name」读不了：$error');
    }
  }

  // ---------------------------------------------------------------------
  // 加锁与目录
  // ---------------------------------------------------------------------

  /// 换个目录。放一份在编辑页里，是因为「写到一半想起来该归到别的目录」
  /// 是很常见的事，不用退出去再找。
  Future<void> _moveToFolder() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final folders = await services.local.watchVisibleFolders().first;
    if (!mounted) return;

    final chosen = await showFolderPicker(
      context,
      folders: folders,
      currentFolderId: note.folderId,
    );
    if (chosen == null || !mounted) return;

    final folderId = chosen == pickUncategorized ? null : chosen;
    await services.local.setNoteFolder(
      id: note.id,
      folderId: folderId,
      now: DateTime.now(),
    );
    _note = note.copyWith(folderId: folderId, clearFolderId: folderId == null);
    unawaited(services.sync.sync());
  }

  Future<void> _encryptNote() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final passphrase = await _askPassphrase(
      title: '加密这篇笔记',
      hint: '设置一个口令，至少 ${NoteLock.minLength} 位',
      confirmLabel: '加密',
    );
    if (passphrase == null || !mounted) return;

    final salt = NoteLock.newSalt();
    final hash = await NoteLock.hash(passphrase, salt);
    if (!mounted) return;

    await services.local.setNoteLock(
      id: note.id,
      locked: true,
      hash: hash,
      salt: salt,
      now: DateTime.now(),
    );
    services.markUnlocked(note.id);
    _note = note.copyWith(
      locked: true,
      passphraseHash: hash,
      passphraseSalt: salt,
    );
    unawaited(services.sync.sync());
    _toast('已加密。口令忘了可以用登录密码关闭加密。');
  }

  Future<void> _changePassphrase() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final passphrase = await _askPassphrase(
      title: '修改口令',
      hint: '输入新的口令',
      confirmLabel: '保存',
    );
    if (passphrase == null || !mounted) return;

    final salt = NoteLock.newSalt();
    final hash = await NoteLock.hash(passphrase, salt);
    if (!mounted) return;

    await services.local.setNoteLock(
      id: note.id,
      locked: true,
      hash: hash,
      salt: salt,
      now: DateTime.now(),
    );
    _note = note.copyWith(passphraseHash: hash, passphraseSalt: salt);
    unawaited(services.sync.sync());
    _toast('口令已更新');
  }

  Future<void> _removeLock() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消加密'),
        content: const Text('取消后打开这篇笔记不再需要口令，内容本身不变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取消加密'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await services.local.setNoteLock(
      id: note.id,
      locked: false,
      hash: null,
      salt: null,
      now: DateTime.now(),
    );
    services.markLocked(note.id);
    _note = note.copyWith(locked: false, clearPassphrase: true);
    unawaited(services.sync.sync());
    _toast('已取消加密');
  }

  /// 弹一个不遮蔽的口令输入框。返回 null 表示取消。
  Future<String?> _askPassphrase({
    required String title,
    required String hint,
    required String confirmLabel,
  }) {
    return TextPromptDialog.show(
      context,
      title: title,
      confirmLabel: confirmLabel,
      hint: hint,
      helperText: '口令会以明文显示，方便你确认有没有打错',
      // 故意不遮蔽：口令看得见才不会打错。
    ).then((value) {
      if (value == null) return null;
      final trimmed = value.trim();
      if (trimmed.length < NoteLock.minLength) {
        _toast('口令至少 ${NoteLock.minLength} 位');
        return null;
      }
      return trimmed;
    });
  }

  /// 忘记口令：用登录密码证明身份，然后决定是直接解锁还是重设口令。
  Future<void> _forgotPassphrase() async {
    final services = _services;
    final note = _note;
    if (services == null || note == null) return;

    final password = await _askAccountPassword(services.accountEmail);
    if (password == null || !mounted) return;

    final verify = services.verifyPassword;
    if (verify == null) {
      _toast('当前环境无法校验登录密码');
      return;
    }
    try {
      await verify(password);
    } catch (error) {
      _toast('验证没通过，检查一下密码，也可能是网络不通');
      return;
    }
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('验证通过'),
        content: const Text('要直接取消这篇笔记的加密，还是换一个新口令？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('reset'),
            child: const Text('重设口令'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('remove'),
            child: const Text('取消加密'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'remove') {
      await services.local.setNoteLock(
        id: note.id,
        locked: false,
        hash: null,
        salt: null,
        now: DateTime.now(),
      );
      services.markLocked(note.id);
      unawaited(services.sync.sync());
      if (mounted) setState(() => _needsUnlock = false);
      await _load();
      return;
    }

    final passphrase = await _askPassphrase(
      title: '设置新口令',
      hint: '输入新的口令',
      confirmLabel: '保存',
    );
    if (passphrase == null || !mounted) return;

    final salt = NoteLock.newSalt();
    final hash = await NoteLock.hash(passphrase, salt);
    await services.local.setNoteLock(
      id: note.id,
      locked: true,
      hash: hash,
      salt: salt,
      now: DateTime.now(),
    );
    services.markUnlocked(note.id);
    unawaited(services.sync.sync().then((_) => _load()));
  }

  Future<String?> _askAccountPassword(String email) {
    return TextPromptDialog.show(
      context,
      title: '验证登录密码',
      confirmLabel: '验证',
      hint: '登录密码',
      // 登录密码和笔记口令不是一回事，这里保持遮蔽。
      obscureText: true,
      helperText: email.isEmpty ? '需要联网向服务器确认' : '账号：$email\n需要联网向服务器确认',
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // 界面
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_finalize());
      },
      child: Scaffold(appBar: _buildAppBar(), body: _buildBody()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final note = _note;
    final controller = _controller;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        _needsUnlock ? '已加密' : '笔记',
        style: const TextStyle(fontSize: 15),
      ),
      centerTitle: true,
      actions: [
        if (!_needsUnlock && controller != null)
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton(
              tooltip: '撤回',
              icon: const Icon(Icons.undo),
              onPressed: controller.hasUndo ? _undoStep : null,
            ),
          ),
        if (!_needsUnlock && note != null)
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'gallery':
                  unawaited(_insertImage(fromCamera: false));
                case 'camera':
                  unawaited(_insertImage(fromCamera: true));
                case 'ink':
                  unawaited(_insertInk());
                case 'paste':
                  unawaited(_pasteImageFromClipboard());
                case 'move':
                  unawaited(_moveToFolder());
                case 'encrypt':
                  unawaited(_encryptNote());
                case 'change':
                  unawaited(_changePassphrase());
                case 'unlock-off':
                  unawaited(_removeLock());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'gallery', child: Text('插入图片')),
              const PopupMenuItem(value: 'camera', child: Text('拍照插入')),
              const PopupMenuItem(value: 'ink', child: Text('插入手写')),
              if (ClipboardImage.isSupported)
                const PopupMenuItem(value: 'paste', child: Text('粘贴图片')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'move', child: Text('移动到…')),
              const PopupMenuDivider(),
              if (!note.locked)
                const PopupMenuItem(value: 'encrypt', child: Text('加密这篇笔记'))
              else ...[
                const PopupMenuItem(value: 'change', child: Text('修改口令')),
                const PopupMenuItem(value: 'unlock-off', child: Text('取消加密')),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_needsUnlock) {
      final note = _note;
      if (note == null) return const SizedBox.shrink();
      return NoteUnlockView(
        note: note,
        onUnlocked: () {
          _services!.markUnlocked(note.id);
          setState(() => _needsUnlock = false);
          unawaited(_load());
        },
        onForgotPassphrase: () => unawaited(_forgotPassphrase()),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          _buildToolbar(controller),
          const Divider(height: 1),
          Expanded(
            child: QuillEditor.basic(
              controller: controller,
              focusNode: _focus,
              scrollController: _scroll,
              config: QuillEditorConfig(
                autoFocus: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                placeholder: '写点什么…',
                embedBuilders: [
                  NoteImageEmbedBuilder(infoOf: _imageInfoOf),
                  NoteInkEmbedBuilder(
                    infoOf: _inkInfoOf,
                    onTap: (id) => unawaited(_openInkCanvas(id)),
                  ),
                ],
                contextMenuBuilder: _buildContextMenu,
                // 只接管字号属性的渲染，不动 DefaultStyles。
                //
                // 自己拼一个 DefaultStyles 会把主题带过来的文字颜色丢掉，
                // 结果是正文全白、在白底上完全看不见（踩过）。
                // 这个扩展点在默认样式之后再合并，正好用来覆盖字号。
                customStyleBuilder: (attribute) =>
                    attribute.key == Attribute.size.key
                    ? TextStyle(fontSize: _fontSizeFor(attribute.value))
                    : const TextStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式工具栏。要求的就是这六样：加粗、斜体、下划线、颜色、字号、高亮。
  ///
  /// 注意工具栏自己会用「箭头 + 溢出列表」处理放不下的按钮，所以必须给它
  /// 一个有界宽度，不能塞进横向滚动的容器里——那样宽度变成无界，
  /// 它内部带 flex 的 Row 会直接报错。
  Widget _buildToolbar(QuillController controller) {
    return QuillSimpleToolbar(
      controller: controller,
      config: const QuillSimpleToolbarConfig(
        showFontFamily: false,
        showFontSize: true,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showColorButton: true,
        showBackgroundColorButton: true,
        // 没有放「清除格式」：多一个按钮工具栏就挤到边框上了，
        // 选中后重新点一次同样的按钮就能取消该样式。
        showClearFormat: false,
        showUndo: false,
        showRedo: false,
        showSearchButton: false,
        showStrikeThrough: false,
        showInlineCode: false,
        showSubscript: false,
        showSuperscript: false,
        showHeaderStyle: false,
        showListNumbers: false,
        showListBullets: false,
        showListCheck: false,
        showCodeBlock: false,
        showQuote: false,
        showIndent: false,
        showLink: false,
        showAlignmentButtons: false,
        showLineHeightButton: false,
        showSmallButton: false,
        showDirection: false,
        multiRowsDisplay: false,
      ),
    );
  }

  /// Quill 的字号只有 small/normal/large/huge 四档，这里映射成具体像素值。
  static double _fontSizeFor(Object? value) => switch (value) {
    'small' => _sizeSmall,
    'large' => _sizeLarge,
    'huge' => _sizeHuge,
    _ => _sizeNormal,
  };

  /// 右键（长按）菜单。桌面端额外挂一个「粘贴图片」：
  /// Flutter 自带的粘贴只处理文本，从截图工具或浏览器复制的图片粘不进来。
  Widget _buildContextMenu(
    BuildContext context,
    QuillRawEditorState editorState,
  ) {
    final items = [...editorState.contextMenuButtonItems];
    if (ClipboardImage.isSupported) {
      items.add(
        ContextMenuButtonItem(
          label: '粘贴图片',
          onPressed: () {
            editorState.hideToolbar();
            unawaited(_pasteImageFromClipboard());
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editorState.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
