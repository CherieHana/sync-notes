import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/ui/note_edit_page.dart';

import 'support/fake_store.dart';

/// 编辑器里图片的排版测试。
///
/// 这里出过一次很难看的 bug：图片往上溢出一大截，把上面几行文字整个盖住。
/// 原因是 EditableText 在没收到 strutStyle 时会自己造一个强制固定行高的
/// strut，图片占位符撑不开所在行——而同样内容放在普通 Text 里是正常的，
/// 所以光看代码不容易想到。
void main() {
  const imageId = '55555555-5555-5555-5555-555555555555';

  /// 编辑器的正文行高：字号 16 乘 1.6。
  const lineHeight = 16 * 1.6;

  Future<void> pumpEditor(WidgetTester tester, String body) async {
    final local = FakeLocalStore()..device = 'layout-test';
    final at = DateTime.now();
    local.notes['n1'] = LocalNote(
      id: 'n1',
      body: body,
      version: 1,
      baseVersion: 1,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );
    // 图片文件不存在，会渲染成按宽高比算出的占位框，尺寸是确定的。
    local.images[imageId] = LocalImage(
      id: imageId,
      storagePath: 'demo/$imageId.jpg',
      byteSize: 1024,
      width: 900,
      height: 600,
      createdAt: at,
      updatedAt: at,
      dirty: false,
    );

    final remote = FakeRemoteApi();
    final engine = SyncEngine(local: local, remote: remote);
    await tester.pumpWidget(
      AppScope(
        services: AppServices(
          userId: 'layout-test',
          local: local,
          remote: remote,
          engine: engine,
          sync: SyncController(engine: engine, remote: remote, local: local),
        ),
        child: const MaterialApp(home: NoteEditPage(noteId: 'n1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('图片会撑开所在行，不会盖住上面的文字', (tester) async {
    await pumpEditor(tester, '第一行\n[[img:$imageId]]\n第二行');

    final image = tester.getRect(find.byKey(const ValueKey(imageId)));
    final field = tester.getRect(find.byType(TextField));

    expect(
      image.top,
      greaterThanOrEqualTo(field.top + lineHeight),
      reason: '图片必须整体排在第一行下面，不能压在第一行上',
    );
    expect(image.height, greaterThan(100), reason: '图片占位框应该按比例撑开');
  });

  testWidgets('图片后面的文字排在图片下方，不会被盖住', (tester) async {
    await pumpEditor(tester, '[[img:$imageId]]\n后面的文字');

    final image = tester.getRect(find.byKey(const ValueKey(imageId)));
    final field = tester.getRect(find.byType(TextField));

    // 占位框从输入框顶部开始，后面的文字要被推到它下面去。
    expect(image.top, lessThan(field.top + lineHeight + 1));
    expect(
      image.bottom,
      greaterThan(field.top + lineHeight),
      reason: '图片占位框应该占满自己的高度',
    );
  });
}
