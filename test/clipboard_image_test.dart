import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/clipboard_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sync_notes/clipboard_image');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('剪切板里没有图片时返回 null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await ClipboardImage.read(), isNull);
  });

  test('平台直接给图片文件字节时原样返回', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'format': 'file', 'bytes': bytes},
    );
    expect(await ClipboardImage.read(), bytes);
  });

  test('平台给原始像素时编码成 PNG', () async {
    // 两个像素：红、绿，各带不透明通道。
    final rgba = Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255]);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'format': 'rgba',
        'bytes': rgba,
        'width': 2,
        'height': 1,
      },
    );

    final png = await ClipboardImage.read();

    expect(png, isNotNull);
    // PNG 的固定文件头，说明确实编码成了图片而不是把原始像素丢出去。
    expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('格式不认识时返回 null，而不是抛异常', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'format': 'bmp', 'bytes': Uint8List.fromList([1])},
    );
    expect(await ClipboardImage.read(), isNull);
  });

  test('非桌面平台直接返回 null，不去打扰原生侧', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });

    expect(await ClipboardImage.read(), isNull);
    expect(called, isFalse);
  });
}
