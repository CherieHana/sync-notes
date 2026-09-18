import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/note_lock.dart';

void main() {
  test('同一个口令和盐算出来的摘要稳定', () async {
    const salt = '00112233445566778899aabbccddeeff';
    final first = await NoteLock.hash('我的口令', salt);
    final second = await NoteLock.hash('我的口令', salt);
    expect(first, second);
    // SHA-256 的输出，十六进制 64 个字符。
    expect(first.length, 64);
  });

  test('盐不同，同一个口令的摘要也不同', () async {
    final a = await NoteLock.hash('同样的口令', NoteLock.newSalt());
    final b = await NoteLock.hash('同样的口令', NoteLock.newSalt());
    expect(a, isNot(b));
  });

  test('口令对得上就通过，对不上就不通过', () async {
    final salt = NoteLock.newSalt();
    final hash = await NoteLock.hash('correct-horse', salt);

    expect(
      await NoteLock.verify(
        passphrase: 'correct-horse',
        hash: hash,
        salt: salt,
      ),
      isTrue,
    );
    expect(
      await NoteLock.verify(
        passphrase: 'correct-horsf',
        hash: hash,
        salt: salt,
      ),
      isFalse,
    );
  });

  test('没设过口令的笔记永远验证不过', () async {
    expect(
      await NoteLock.verify(passphrase: 'x', hash: null, salt: null),
      isFalse,
    );
  });

  test('盐是 16 字节的十六进制', () {
    final salt = NoteLock.newSalt();
    expect(salt.length, 32);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(salt), isTrue);
  });

  test('口令最短长度是 4', () {
    expect(NoteLock.minLength, 4);
  });

  test('一次派生耗时在可接受范围内', () async {
    final salt = NoteLock.newSalt();
    final stopwatch = Stopwatch()..start();
    await NoteLock.hash('benchmark', salt);
    stopwatch.stop();

    // 纯 Dart 的 PBKDF2，太慢会让解锁明显卡顿。
    // 这里只是留个记录，失败说明该调低迭代次数了。
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
  });
}
