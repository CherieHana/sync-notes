import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/services/external_drop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = 'sync_notes/drop';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    ExternalDrop.listen();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> deliver(Object? arguments) async {
    await messenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('dropped', arguments),
      ),
      (_) {},
    );
  }

  test('原生推过来的文件和文本都会进入流', () async {
    final received = ExternalDrop.stream.first;
    await deliver({
      'files': [r'C:\图片\a.png'],
      'text': '拖过来的一段字',
    });

    final content = await received;
    expect(content.files, [r'C:\图片\a.png']);
    expect(content.text, '拖过来的一段字');
    expect(content.isEmpty, isFalse);
  });

  test('只拖文件、只拖文字都能收到', () async {
    final fileOnly = ExternalDrop.stream.first;
    await deliver({
      'files': ['x.jpg'],
    });
    expect((await fileOnly).files, ['x.jpg']);

    final textOnly = ExternalDrop.stream.first;
    await deliver({'text': '只有文字'});
    final content = await textOnly;
    expect(content.files, isEmpty);
    expect(content.text, '只有文字');
  });

  test('空内容不会污染流', () async {
    var emitted = false;
    final subscription = ExternalDrop.stream.listen((_) => emitted = true);
    addTearDown(subscription.cancel);

    await deliver({'files': <String>[], 'text': '   '});
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isFalse);
  });

  test('非桌面平台不注册接收端', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ExternalDrop.isSupported, isFalse);
  });
}
