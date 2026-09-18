import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/undo_stack.dart';

void main() {
  late DateTime now;
  late UndoStack<String> stack;

  setUp(() {
    now = DateTime(2026, 1, 1);
    stack = UndoStack<String>(
      burstWindow: const Duration(milliseconds: 1500),
      clock: () => now,
    );
  });

  test('同一段里的连续输入合并成一步', () {
    stack.record('A');
    now = now.add(const Duration(milliseconds: 200));
    stack.record('AB');
    now = now.add(const Duration(milliseconds: 200));
    stack.record('ABC');

    // 撤一次直接回到这一段的起点，而不是退一个字符。
    expect(stack.undo(), 'A');
    expect(stack.canUndo, isFalse);
  });

  test('停手超过合并窗口之后再改，算新的一段', () {
    stack.record('A');
    now = now.add(const Duration(seconds: 3));
    stack.record('AB');

    expect(stack.undo(), 'AB');
    expect(stack.undo(), 'A');
    expect(stack.undo(), isNull);
  });

  test('breakSegment 强制分段，比如插入图片前后', () {
    stack.record('A');
    stack.breakSegment();
    stack.record('AB');

    expect(stack.undo(), 'AB');
    expect(stack.undo(), 'A');
  });

  test('超过上限丢弃最早的记录', () {
    final small = UndoStack<String>(limit: 3, clock: () => now);
    for (var i = 0; i < 6; i++) {
      small.record('第 $i 次');
      small.breakSegment();
    }

    expect(small.depth, 3);
    expect(small.undo(), '第 5 次');
    expect(small.undo(), '第 4 次');
    expect(small.undo(), '第 3 次');
    expect(small.undo(), isNull);
  });

  test('没有改动时撤回是空操作', () {
    expect(stack.canUndo, isFalse);
    expect(stack.undo(), isNull);
  });

  test('clear 之后撤回栈为空，模拟离开编辑页', () {
    stack.record('A');
    stack.record('B');
    expect(stack.canUndo, isTrue);

    stack.clear();
    expect(stack.canUndo, isFalse);
    expect(stack.undo(), isNull);
  });
}
