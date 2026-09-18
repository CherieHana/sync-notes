import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 笔记加锁的口令处理。
///
/// 说明清楚这套东西的边界：正文在服务端始终是明文，这里算出来的摘要
/// 只是让客户端知道「口令对不对」，它挡的是拿到手机的人，不是能读数据库的人。
/// 所以迭代次数选的是「够挡住随手试」而不是「抵抗专业破解」的量级。
class NoteLock {
  const NoteLock._();

  /// PBKDF2 迭代次数。纯 Dart 实现，太高会让解锁明显卡顿。
  static const int iterations = 100000;

  static const int _saltBytes = 16;

  static final Random _random = Random.secure();

  /// 口令最少几位。太短的话这道门形同虚设。
  static const int minLength = 4;

  static String newSalt() {
    final bytes = Uint8List.fromList(
      List<int>.generate(_saltBytes, (_) => _random.nextInt(256)),
    );
    return _hex(bytes);
  }

  /// 由口令和盐算出十六进制摘要。
  static Future<String> hash(String passphrase, String salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: _unhex(salt),
    );
    return _hex(Uint8List.fromList(await key.extractBytes()));
  }

  static Future<bool> verify({
    required String passphrase,
    required String? hash,
    required String? salt,
  }) async {
    if (hash == null || salt == null) return false;
    final actual = await NoteLock.hash(passphrase, salt);
    return _constantTimeEquals(actual, hash);
  }

  /// 逐位比较，不因为前缀相同就提前返回。
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _unhex(String value) {
    final result = Uint8List(value.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
