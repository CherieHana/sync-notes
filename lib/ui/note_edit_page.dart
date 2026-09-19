import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'image_preview_page.dart';
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

  /// 正文四周的留白。放在外面这层滚动视图上，编辑器自己不再管边距。
  static const EdgeInsets _editorPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  /// 光标离上下边缘多近就要滚一次。
  static const double _caretMargin = 28;

  /// 拖选时边缘自动滚动：感应带宽度、每帧最多滚多远。
  static const double _edgeBand = 36;
  static const double _edgeStep = 16;

  /// 两次轻点在这个时间内算一次双击。
  static const Duration _tapTimeout = Duration(milliseconds: 320);

  /// 选区浮动菜单的尺寸。Flutter 里这些是私有常量，这里照抄一份：
  /// 菜单本身高 44，贴在上面时锚点还要再让 8（贴在下方时的间距框架自己会加）。
  static const double _menuHeight = 44;
  static const double _menuAboveGap = 8;

  /// 菜单和选区两端抓手之间要留的缝。
  static const double _menuHandleGap = 30;

  /// 菜单和上面那条格式栏之间要留的缝。
  static const double _menuToolbarGap = 8;

  final FocusNode _focus = FocusNode();

  /// 正文外面那层滚动视图的控制器。滚动由页面自己管，理由见 [_editorScroll]。
  final ScrollController _scroll = ScrollController();

  /// 交给 Quill 的控制器，故意不挂到任何滚动视图上。
  ///
  /// 编辑器自己那套「把光标滚进可视区」在长文档里是坏的：它每次选区变化都重算一遍
  /// 目标偏移，算式里又把当前偏移当成了内容坐标的一部分，于是偏移越大目标越远，
  /// 拖选的时候滚动条会来回抽。给它一个没有客户端的控制器，它内部所有滚动调用都会
  /// 自己跳过，滚动只由这一页驱动。
  final ScrollController _editorScroll = ScrollController();

  /// 用来问编辑器「光标现在在哪」，跟着滚动的时候要用。
  final GlobalKey<EditorState> _editorKey = GlobalKey<EditorState>();

  /// 可见区域（滚动视图本身），拖到它外面就自动滚。
  final GlobalKey _viewportKey = GlobalKey();

  /// 格式栏，量一下它有多高：手机上的选区浮动菜单要往下让出这个高度。
  final GlobalKey _toolbarKey = GlobalKey();

  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  AppServices? _services;
  LocalNote? _note;
  Timer? _debounce;
  Timer? _imageRetry;
  Timer? _edgeScroll;
  StreamSubscription<DroppedContent>? _dropSubscription;

  bool _loaded = false;
  bool _needsUnlock = false;

  /// 指针是不是按着。按着的时候把滚动让给边缘自动滚动，两边一起动就会打架。
  bool _pointerDown = false;
  Offset? _pointerPosition;

  /// 这一次手势从按下到现在挪了多远、按了多久。用来区分「轻点」「拖选」「滚页面」。
  double _pointerTravel = 0;
  DateTime? _pointerDownAt;

  /// 这一次手势里选区有没有变过。变了才是拖选，滚页面不算。
  bool _selectionMovedWhileDown = false;

  /// 上一次轻点的时间和位置，用来自己认双击。
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  /// 已排队的「把光标滚出来」，一帧只做一次。
  bool _revealScheduled = false;

  double _keyboardInset = 0;

  /// 手机上默认不弹输入法：点一下只放光标和选区，双击才叫出键盘。
  ///
  /// 安卓上每点一下、每拉一次选区都弹键盘，改样式和选长段都很碍事。
  bool _lazyKeyboard = false;

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
    _edgeScroll?.cancel();
    unawaited(_dropSubscription?.cancel());
    unawaited(_changes?.cancel());
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _focus.dispose();
    _scroll.dispose();
    _editorScroll.dispose();
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
    controller.addListener(_onControllerChanged);
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
  // 滚动
  // ---------------------------------------------------------------------

  void _onControllerChanged() {
    // 选字的过程中别让输入法冒出来（拖选、拖抓手、长按选词都会走到这里）。
    if (_lazyKeyboard) _suppressKeyboardWhileSelecting();

    // 拖选过程中不抢：那会儿滚动由边缘自动滚动负责。
    if (_pointerDown) {
      _selectionMovedWhileDown = true;
      // 选中范围变了，说明真的在拖选。手指/鼠标停在边缘不动的时候也要继续滚，
      // 所以顺手续上边缘自动滚动，而不是非等下一次指针移动。
      _updateEdgeScroll();
      return;
    }
    _scheduleReveal();
  }

  /// 手机上选字的时候，别让编辑器去要输入法。
  ///
  /// Quill 每次选区变化都会要一次键盘（它源码里的注释写得很明白：所有选区变化
  /// 都会弹键盘，不只是用户手势触发的），拖选和拖抓手的时候键盘就一次次往上顶。
  /// 用通道把它关掉会和它打架——关一次又弹一次，变成「弹出来又收回去」的鬼畜。
  /// 所以改成把这次请求吞掉：编辑器自带的 skipRequestKeyboard 就是干这个的，
  /// 调用后紧接着产生的那个请求会直接返回，一个通道调用都不发。
  void _suppressKeyboardWhileSelecting() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.selection.isCollapsed) return;
    controller.skipRequestKeyboard = true;
  }

  void _scheduleReveal() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted) _revealCaret();
    });
  }

  /// 光标跑出可视区时才滚一次。
  void _revealCaret({bool center = false}) {
    final editor = _editorKey.currentState;
    final selection = _controller?.selection;
    if (editor == null || selection == null || !selection.isValid) return;
    if (!_scroll.hasClients) return;

    final Rect caret;
    try {
      caret = editor.renderEditor.getLocalRectForCaret(selection.extent);
    } catch (_) {
      // 内容刚改完、还没排好版，下一帧会再来一次。
      return;
    }

    final position = _scroll.position;
    final top = _editorPadding.top + caret.top;
    final bottom = _editorPadding.top + caret.bottom;
    final visibleBottom = position.pixels + position.viewportDimension;

    if (center) {
      // 手动跳转：不管光标在不在屏幕上，都把它挪到屏幕中间，看得见才安心。
      final middle = top - (position.viewportDimension - (bottom - top)) / 2;
      _scrollTo(middle);
      return;
    }
    if (bottom + _caretMargin > visibleBottom) {
      _scrollTo(bottom + _caretMargin - position.viewportDimension);
    } else if (top - _caretMargin < position.pixels) {
      _scrollTo(top - _caretMargin);
    }
  }

  /// 「回到光标」：把焦点还给编辑器，再把光标挪到屏幕中间。
  void _jumpToCaret() {
    _focus.requestFocus();
    _revealCaret(center: true);
  }

  void _scrollTo(double target) {
    final position = _scroll.position;
    final clamped = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((clamped - position.pixels).abs() < 1) return;
    position.animateTo(
      clamped,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDown = true;
    _pointerPosition = event.position;
    _pointerTravel = 0;
    _pointerDownAt = DateTime.now();
    _selectionMovedWhileDown = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointerDown) return;
    _pointerTravel += event.delta.distance;
    _pointerPosition = event.position;
    _updateEdgeScroll();
  }

  void _handlePointerEnd() {
    final pointer = _pointerPosition;
    final held = _pointerDownAt == null
        ? Duration.zero
        : DateTime.now().difference(_pointerDownAt!);
    final wasTap = _pointerDown && _pointerTravel < 12 && held < _tapTimeout;
    final selectedSomething = _selectionMovedWhileDown;

    _pointerDown = false;
    _pointerPosition = null;
    _edgeScroll?.cancel();
    _edgeScroll = null;

    if (_lazyKeyboard) {
      _handleSoftKeyboardAfterGesture(wasTap, selectedSomething, pointer);
    }

    // 只有拖选才把光标滚回可视区；滚页面时别抢，不然一松手就弹回去。
    if (selectedSomething) _scheduleReveal();
    _selectionMovedWhileDown = false;
  }

  /// 手机上：轻点/拖选只放光标，双击才叫出输入法。
  void _handleSoftKeyboardAfterGesture(
    bool wasTap,
    bool selectedSomething,
    Offset? pointer,
  ) {
    if (wasTap && pointer != null && _isDoubleTap(pointer)) {
      _focus.requestFocus();
      _showSoftKeyboard();
      return;
    }
    // 拖选也是一次正经的选字操作：焦点要给编辑器（光标和抓手都靠它显示），
    // 但不去叫键盘——编辑器想弹的那个请求已经被 [_suppressKeyboardWhileSelecting]
    // 吞掉了，这里再动手关一次反而会变成「弹出来又收回去」。
    if (wasTap || selectedSomething) _focus.requestFocus();
  }

  /// 两次轻点挨得很近就算双击；第二次用过就清零，免得连点成两次双击。
  bool _isDoubleTap(Offset position) {
    final now = DateTime.now();
    final last = _lastTapAt;
    final lastPosition = _lastTapPosition;
    final doubled =
        last != null &&
        lastPosition != null &&
        now.difference(last) < _tapTimeout &&
        (position - lastPosition).distance < 48;

    if (doubled) {
      _lastTapAt = null;
      _lastTapPosition = null;
    } else {
      _lastTapAt = now;
      _lastTapPosition = position;
    }
    return doubled;
  }

  /// 唤出系统输入法（双击才用）。
  ///
  /// Flutter 只在 TextInputConnection 上暴露 show/hide，而那条连接在编辑器内部，
  /// 外面拿不到。这个方法名是 TextInput 通道协议的一部分，引擎自己就按它处理。
  /// 收起键盘不用这里——那会和编辑器自己的请求打架，改成吞掉它的请求
  /// （见 [_suppressKeyboardWhileSelecting]）。
  void _showSoftKeyboard() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  /// 「选择」：把选区重新点亮一次。
  ///
  /// 两端那两个拖动抓手要「编辑器有焦点 + 选区叠加层在」才会画出来。长按偶尔会
  /// 出现菜单出来了、抓手没跟上的情况，点这个按钮就把两样都补回来：先把焦点要回
  /// 编辑器，下一帧再让编辑器把工具栏和抓手一起摆一次（它的 showToolbar 会顺手
  /// 把抓手补上）。本来只有光标时，顺手把光标所在的词选上。
  void _reselectForHandles() {
    final editor = _editorKey.currentState;
    final controller = _controller;
    if (editor == null || controller == null) return;

    var selection = controller.selection;
    if (selection.isCollapsed) {
      selection = editor.renderEditor.selectWordAtPosition(
        TextPosition(offset: selection.extentOffset),
      );
    }
    final target = selection;

    _focus.requestFocus();
    // 先收成一根光标：编辑器会把选区叠加层整个销毁，抓手就挂在那上头。
    // 下一帧再把这段字选回来，叠加层会连着两个抓手一起重建——
    // 已经是「有选区但叠加层里没有抓手」的状态时，只有重建这条路能救回来。
    controller.updateSelection(
      TextSelection.collapsed(offset: target.start),
      ChangeSource.local,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.updateSelection(target, ChangeSource.local);
      _editorKey.currentState?.showToolbar();
      _scheduleReveal();
    });
  }

  /// 点完菜单里的按钮之后，把编辑器的状态收回来。
  ///
  /// 这条浮动菜单不在编辑器的点击区域内，点它会被当成「点到外面」：编辑器丢掉
  /// 焦点，两端的抓手跟着消失。这里把焦点要回来（抓手靠它显示），键盘不去碰——
  /// 要弹的那个请求会在 [_suppressKeyboardWhileSelecting] 那里被吞掉。
  void _afterMenuAction() {
    _focus.requestFocus();
  }

  /// 手机上按下的这一下先别让编辑器去要输入法，等抬起时看是不是双击。
  /// 返回 false 表示照常走编辑器自己的按下处理（放光标、拖选都要用）。
  bool _handleTapDown(
    TapDownDetails details,
    TextPosition Function(Offset offset) positionOf,
  ) {
    if (_lazyKeyboard) _controller?.skipRequestKeyboard = true;
    return false;
  }

  /// 拖着选到可视区边缘以外时自动滚动，和别的编辑器一致。
  void _updateEdgeScroll() {
    if (_edgeStepFor(_pointerPosition) == 0) {
      _edgeScroll?.cancel();
      _edgeScroll = null;
      return;
    }
    _edgeScroll ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _edgeScrollTick(),
    );
  }

  /// 指针离边缘多远决定滚多快，正数往下、负数往上。
  double _edgeStepFor(Offset? pointer) {
    if (pointer == null || !_scroll.hasClients) return 0;
    // 只有拖着选字的时候才自动滚。单纯滚页面（手指划过文字）时插一脚，
    // 就变成一边自己滚一边跟手指较劲了。
    if (!_selectionMovedWhileDown) return 0;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;

    final viewport = box.localToGlobal(Offset.zero) & box.size;
    // 右侧那条是滚动条，别在拖它的时候插一脚，两股劲一起使就会抖。
    if (pointer.dx > viewport.right - 18) return 0;

    if (pointer.dy > viewport.bottom - _edgeBand) {
      final strength =
          ((pointer.dy - (viewport.bottom - _edgeBand)) / _edgeBand).clamp(
            0.0,
            1.0,
          );
      return strength * _edgeStep;
    }
    if (pointer.dy < viewport.top + _edgeBand) {
      final strength = (((viewport.top + _edgeBand) - pointer.dy) / _edgeBand)
          .clamp(0.0, 1.0);
      return -strength * _edgeStep;
    }
    return 0;
  }

  void _edgeScrollTick() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final step = _edgeStepFor(_pointerPosition);
    if (step == 0) return;

    final next = (position.pixels + step)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (next == position.pixels) return;
    position.jumpTo(next);

    // 画面滚了，选中范围也得跟着指针走，不然只是内容在动。
    final pointer = _pointerPosition;
    final editor = _editorKey.currentState;
    if (pointer == null || editor == null) return;
    try {
      editor.renderEditor.extendSelection(
        pointer,
        cause: SelectionChangedCause.drag,
      );
    } catch (_) {
      // 手势还没被编辑器认成「拖选」时它内部没有起点，跳过就好，
      // 下一个指针移动事件会补上。
    }
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
      // 选图会把窗口让给系统相册/相机，回来的时候别让编辑器自动拿回焦点，
      // 否则输入法会跟着一起弹出来。
      _focus.unfocus();
      final picked = await ImagePipeline.pickMany(fromCamera: fromCamera);
      if (picked.isEmpty || !mounted) return;
      // 按选中的顺序一张一张插：每张自己占一行，插完光标落到它下面，
      // 所以下一张正好接在后面。
      for (final prepared in picked.images) {
        if (!mounted) return;
        await _storeImage(prepared);
      }
      if (picked.failed.isNotEmpty) {
        _toast('有 ${picked.failed.length} 张没插进来：${picked.failed.first}');
      }
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

    _focus.unfocus();
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
        // 跟新建笔记一样要打上「服务端还没有这条」：少了它，推送时会走成
        // 「更新一条不存在的记录」，同步引擎查不到就当成被别的设备删了，
        // 刚画好的画会被本地一起抹掉（老版本就是这么丢的）。
        isNew: true,
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
    if (!mounted) return;
    if (ink == null) {
      // 老版本的一个同步 bug 会把没上传成功的手写当垃圾删掉，笔迹找不回来了。
      _toast('这块手写的内容已经丢了，重新画一块吧');
      return;
    }

    // 从整页画布回来时不让编辑器自动拿回焦点，省得输入法跟着弹出来。
    _focus.unfocus();
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

  /// 点正文里的图片，打开大图预览（可以滚轮或双指放大）。
  Future<void> _openImagePreview(String imageId) async {
    final info = _imageInfo[imageId];
    final path = info?.path;
    if (path == null) {
      _toast('这张图还没同步下来，稍等一下再点');
      return;
    }
    // 看大图的时候编辑器先松手：回来不会自动拿回焦点，输入法也就不会弹。
    _focus.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImagePreviewPage(path: path, title: p.basename(path)),
      ),
    );
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
    _moveCaretTo(caret);
    unawaited(_save());
  }

  /// 把光标放到 [offset]，并顺手把焦点还给编辑器。
  ///
  /// 插图片前弹了系统的文件框、插手写前推了画布页，这趟来回之后焦点和选区都可能
  /// 不在编辑器身上——光标看不见、接着打字也不知道会落到哪儿。这里明确再要一次
  /// 焦点，并在这一帧结束后再对一遍选区，免得刚设好又被别的回调改回去。
  void _moveCaretTo(int offset) {
    final controller = _controller;
    if (controller == null) return;

    controller.updateSelection(
      TextSelection.collapsed(offset: offset),
      ChangeSource.local,
    );
    _focus.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safe = offset.clamp(0, controller.document.length - 1);
      if (controller.selection.baseOffset != safe ||
          controller.selection.extentOffset != safe) {
        controller.updateSelection(
          TextSelection.collapsed(offset: safe),
          ChangeSource.local,
        );
      }
      _scheduleReveal();
    });
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
          IconButton(
            tooltip: '回到光标',
            icon: const Icon(Icons.my_location),
            onPressed: _jumpToCaret,
          ),
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

    // 键盘弹起或收起之后把光标重新露出来一次：可视区矮了一截，
    // 之前露在外面的光标可能被挡住了。
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset != _keyboardInset) {
      _keyboardInset = keyboardInset;
      _scheduleReveal();
    }

    // 手机和平板才用「双击才弹键盘」这套；桌面上键盘本来就不用管。
    final platform = Theme.of(context).platform;
    _lazyKeyboard =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return SafeArea(
      child: Column(
        children: [
          _buildToolbar(controller),
          const Divider(height: 1),
          Expanded(
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: (_) => _handlePointerEnd(),
              onPointerCancel: (_) => _handlePointerEnd(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 正文至少铺满一屏，点空白处也能落光标；太长的正文按实际高度走，
                  // 滚动交给外面这层滚动视图。
                  final minHeight = constraints.maxHeight.isFinite
                      ? (constraints.maxHeight - _editorPadding.vertical).clamp(
                          0.0,
                          double.infinity,
                        )
                      : null;
                  return SingleChildScrollView(
                    key: _viewportKey,
                    controller: _scroll,
                    padding: _editorPadding,
                    child: QuillEditor.basic(
                      controller: controller,
                      focusNode: _focus,
                      scrollController: _editorScroll,
                      config: QuillEditorConfig(
                        // 自己滚：编辑器内部那个滚动容器关掉。
                        scrollable: false,
                        minHeight: minHeight,
                        autoFocus: true,
                        placeholder: '写点什么…',
                        editorKey: _editorKey,
                        onTapDown: _handleTapDown,
                        embedBuilders: [
                          NoteImageEmbedBuilder(
                            infoOf: _imageInfoOf,
                            onTap: (id) {
                              unawaited(_openImagePreview(id));
                            },
                          ),
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
                  );
                },
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
      key: _toolbarKey,
      controller: controller,
      config: const QuillSimpleToolbarConfig(
        // 按钮收紧一点：一排要塞下字号加六种样式，默认尺寸在窄屏手机上会顶到边框。
        iconTheme: QuillIconTheme(
          iconButtonUnselectedData: IconButtonData(
            iconSize: 20,
            padding: EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
          ),
          iconButtonSelectedData: IconButtonData(
            iconSize: 20,
            padding: EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
          ),
        ),
        showFontFamily: false,
        showFontSize: true,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showColorButton: true,
        showBackgroundColorButton: true,
        // 选中一段花里胡哨的文字点它，就退回纯文本的样子。
        showClearFormat: true,
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
    var items = [...editorState.contextMenuButtonItems];
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

    if (_lazyKeyboard) {
      // 菜单里的每一项点完都把编辑器状态收回来（详见 [_afterMenuAction]）。
      items = [
        for (final item in items)
          ContextMenuButtonItem(
            type: item.type,
            label: item.label,
            onPressed: () {
              item.onPressed?.call();
              _afterMenuAction();
            },
          ),
      ];
      // 手机上补一个「选择」：长按偶尔只弹出菜单、不给两端的拖动抓手，
      // 点它一下就把抓手叫回来。放在最前面，最好按。
      items.insert(
        0,
        ContextMenuButtonItem(
          label: '选择',
          onPressed: () {
            editorState.hideToolbar();
            _reselectForHandles();
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: _menuAnchorsFor(editorState),
      buttonItems: items,
    );
  }

  /// 算选区浮动菜单该待在哪儿。
  ///
  /// 这条菜单贴着锚点画：默认贴选区上沿往上长，上面放不下时才翻到选区下方。
  /// 系统判断「放不放得下」只看屏幕顶边——它不知道我们头顶还有一条格式栏，
  /// 也不管选区两端的抓手，于是要么压住工具栏，要么压住抓手。
  ///
  /// 这里自己算：上方够放，就放在格式栏和选区之间，并给起始抓手留出一截；
  /// 不够放，就把主锚点扔到屏幕顶上，逼它翻到选区下方去——那边的间距框架
  /// 自己会算，正好躲开结束抓手。
  TextSelectionToolbarAnchors _menuAnchorsFor(QuillRawEditorState editorState) {
    final anchors = editorState.contextMenuAnchors;
    final secondary = anchors.secondaryAnchor;
    final toolbar =
        _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (secondary == null || toolbar == null || !toolbar.hasSize) {
      return anchors;
    }

    final toolbarBottom = toolbar
        .localToGlobal(Offset(0, toolbar.size.height))
        .dy;
    final above = anchors.primaryAnchor;
    // 菜单底边落在选区上沿之上，中间空出起始抓手的位置。
    final menuBottom = above.dy - _menuHandleGap;
    final fitsAbove =
        menuBottom - _menuHeight >= toolbarBottom + _menuToolbarGap;

    if (fitsAbove) {
      return TextSelectionToolbarAnchors(
        // 框架会在锚点基础上再往上抬 8，这里补回来，让底边正好落在 menuBottom。
        primaryAnchor: Offset(above.dx, menuBottom + _menuAboveGap),
        secondaryAnchor: secondary,
      );
    }
    return TextSelectionToolbarAnchors(
      // dy 给 0，框架一定判定「上面放不下」，于是改用下面那条锚点。
      primaryAnchor: Offset(above.dx, 0),
      secondaryAnchor: Offset(secondary.dx, secondary.dy + _menuToolbarGap),
    );
  }
}
