import 'package:flutter/foundation.dart';

/// 编辑器里的撤回栈。
///
/// 按「编辑段」合并：连续输入在 [burstWindow] 之内算作一步，
/// 所以撤一次是退一整段，而不是退一个字。停手超过这个窗口、
/// 或者中间插了图片、执行过一次撤回，都会切断当前段。
///
/// 只活在内存里：离开编辑页就没了，这也是需求里说的「不退出当前笔记就能撤回」。
class UndoStack<T> extends ChangeNotifier {
  UndoStack({
    this.limit = 60,
    this.burstWindow = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 最多记多少步，超出后丢掉最早的。
  final int limit;

  /// 多久之内的连续编辑算一段。
  final Duration burstWindow;

  final DateTime Function() _clock;
  final List<T> _stack = [];

  T? _pendingText;
  DateTime? _pendingAt;

  bool get canUndo => _pendingText != null || _stack.isNotEmpty;

  /// 可撤回的步数，用来决定按钮是否置灰。
  int get depth => _stack.length + (_pendingText == null ? 0 : 1);

  /// 记下这次改动之前的文本。应该在文本已经变化之后调用，
  /// 传进来的是变化前的内容。
  void record(T previous) {
    final now = _clock();
    if (_pendingText == null) {
      _pendingText = previous;
      _pendingAt = now;
      notifyListeners();
      return;
    }
    if (now.difference(_pendingAt!) >= burstWindow) {
      // 上一段结束了，先把它落栈，再开新的一段。
      _commitPending();
      _pendingText = previous;
      _pendingAt = now;
      notifyListeners();
    }
    // 还在同一段里：保留最早的那个文本作为撤回目标，这样一次能退整段。
  }

  /// 强制结束当前段。插入图片、粘贴、执行撤回前都该调一下。
  void breakSegment() {
    _commitPending();
    notifyListeners();
  }

  /// 撤回一步。返回要恢复的文本，没有可撤回的返回 null。
  T? undo() {
    _commitPending();
    if (_stack.isEmpty) return null;
    final value = _stack.removeLast();
    notifyListeners();
    return value;
  }

  void clear() {
    _stack.clear();
    _pendingText = null;
    _pendingAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stack.clear();
    super.dispose();
  }

  void _commitPending() {
    final pending = _pendingText;
    if (pending != null) {
      _stack.add(pending);
      if (_stack.length > limit) _stack.removeAt(0);
    }
    _pendingText = null;
    _pendingAt = null;
  }
}
