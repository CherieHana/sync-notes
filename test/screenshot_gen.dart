// 生成 README 用的界面截图。
//
// 文件名不带 _test 后缀，所以 `flutter test` 不会自动跑它，需要显式执行：
//
//   flutter test test/screenshot_gen.dart --update-goldens
//
// 它渲染的是真实界面代码，只是把数据和字体换成可控的：笔记是编的，
// 字体用系统里的思源黑体，否则测试环境默认字体会把中文画成方块。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/local/local_store.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
import 'package:sync_notes/ui/note_edit_page.dart';
import 'package:sync_notes/ui/notes_list_page.dart';

import 'support/fake_store.dart';

const String _fontFamily = 'ScreenshotFont';

Future<bool> _loadFontFile(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    return true;
  }
  return false;
}

Future<void> _loadFonts() async {
  // 测试环境默认字体会把中文画成方块，得手动喂一个系统中文字体。
  final loaded = await _loadFontFile(_fontFamily, const [
    r'C:\Windows\Fonts\NotoSansSC-VF.ttf',
    r'C:\Windows\Fonts\Deng.ttf',
    r'C:\Windows\Fonts\simhei.ttf',
  ]);
  if (!loaded) {
    throw StateError('没找到可用的中文字体，截图会是一堆方块');
  }
  // 图标字体同理，不加载的话所有图标都是空方框。
  await _loadFontFile('MaterialIcons', const [
    r'D:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ]);
}

ThemeData get _theme => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFFF5C34B),
  scaffoldBackgroundColor: const Color(0xFFFDFBF5),
  fontFamily: _fontFamily,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFDFBF5),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
);

AppServices _services({
  List<LocalNote> notes = const [],
  List<LocalFolder> folders = const [],
  List<LocalImage> images = const [],
  Map<String, String> imagePaths = const {},
}) {
  final local = FakeLocalStore()..device = 'screenshot';
  local.imageRealPaths.addAll(imagePaths);
  for (final image in images) {
    local.images[image.id] = image;
  }
  for (final folder in folders) {
    local.folders[folder.id] = folder;
  }
  for (final note in notes) {
    local.notes[note.id] = note;
  }
  final remote = FakeRemoteApi();
  final engine = SyncEngine(local: local, remote: remote);
  return AppServices(
    userId: 'demo',
    local: local,
    remote: remote,
    engine: engine,
    sync: SyncController(engine: engine, remote: remote, local: local),
    accountEmail: 'you@example.com',
  );
}

LocalNote _note(
  String id,
  String body, {
  required Duration ago,
  String? device,
  String? folderId,
}) {
  final at = DateTime.now().subtract(ago);
  return LocalNote(
    id: id,
    body: body,
    version: 3,
    baseVersion: 3,
    createdAt: at,
    updatedAt: at,
    serverUpdatedAt: at,
    dirty: false,
    lastDeviceId: device,
    folderId: folderId,
  );
}

LocalFolder _folder(String id, String name, {required Duration ago}) {
  final at = DateTime.now().subtract(ago);
  return LocalFolder(
    id: id,
    name: name,
    version: 2,
    baseVersion: 2,
    createdAt: at,
    updatedAt: at,
    dirty: false,
  );
}

/// 造一张真实的 PNG 放到临时目录，截图里就能看到真图片而不是占位框。
String _writeSampleImage(String name, int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      // 画一个横向渐变，方便看出图片有没有被拉伸变形。
      image.setPixelRgb(
        x,
        y,
        150 + (x * 100 ~/ width),
        60,
        60 + (y * 80 ~/ height),
      );
    }
  }
  final file = File(p.join(Directory.systemTemp.path, name));
  file.writeAsBytesSync(img.encodePng(image));
  return file.path;
}

LocalImage _image(String id, {required int width, required int height}) {
  final at = DateTime.now();
  return LocalImage(
    id: id,
    storagePath: 'demo/$id.jpg',
    byteSize: 1024,
    width: width,
    height: height,
    createdAt: at,
    updatedAt: at,
    dirty: false,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(home);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('列表页', (tester) async {
    final services = _services(
      folders: [
        _folder('work', '工作', ago: const Duration(days: 30)),
        _folder('life', '生活', ago: const Duration(days: 30)),
        _folder('read', '读书', ago: const Duration(days: 20)),
      ],
      notes: [
        _note(
          '1',
          '周五的采购清单\n牛奶、鸡蛋、面包\n顺便带一袋咖啡豆',
          ago: const Duration(minutes: 12),
          device: 'phone',
          folderId: 'life',
        ),
        _note(
          '2',
          '出差要带的东西\n充电器、转换头、耳机\n身份证放外套口袋',
          ago: const Duration(hours: 3),
          device: 'laptop',
          folderId: 'work',
        ),
        _note(
          '3',
          '读书笔记：《人月神话》\n加人不能解决进度问题，只会让事情更慢',
          ago: const Duration(days: 1),
          folderId: 'read',
        ),
        _note(
          '4',
          '给房东的维修清单\n厨房水龙头一直滴水\n卧室窗户关不严，晚上漏风',
          ago: const Duration(days: 4),
          folderId: 'life',
        ),
        _note(
          '5',
          '面试要问的问题\n团队现在最头疼的事是什么\n上线流程走几步',
          ago: const Duration(days: 11),
          folderId: 'work',
        ),
        _note(
          '6',
          '路由器后台密码\n在抽屉里的便签上',
          ago: const Duration(days: 18),
          folderId: 'work',
        ),
        _note(
          '7',
          '想看的电影\n一一、海边的曼彻斯特、燃烧',
          ago: const Duration(days: 26),
          folderId: 'read',
        ),
        _note(
          '8',
          '搬家清单\n宽带要提前一周预约移机',
          ago: const Duration(days: 40),
          folderId: 'life',
        ),
      ],
    );

    await _pump(
      tester,
      AppScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          // 截图上要显示中文界面，测试环境的默认语言是英文。
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NotesListPage(),
        ),
      ),
    );

    await expectLater(
      find.byType(NotesListPage),
      matchesGoldenFile('goldens/notes_list.png'),
    );
  });

  testWidgets('编辑页', (tester) async {
    final body = '周五的采购清单\n牛奶、鸡蛋、面包\n顺便带一袋咖啡豆';
    final services = _services(
      notes: [_note('1', body, ago: const Duration(minutes: 12))],
    );

    await _pump(
      tester,
      AppScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NoteEditPage(noteId: '1'),
        ),
      ),
    );

    await expectLater(
      find.byType(NoteEditPage),
      matchesGoldenFile('goldens/note_edit.png'),
    );
  });

  testWidgets('带图片的笔记', (tester) async {
    const imageId = '55555555-5555-5555-5555-555555555555';
    final path = _writeSampleImage('sync-notes-sample.png', 900, 600);
    final services = _services(
      notes: [
        _note(
          '1',
          '测试\n图片\n[[img:$imageId]]\n图片下面还有一行字',
          ago: const Duration(minutes: 5),
        ),
      ],
      images: [_image(imageId, width: 900, height: 600)],
      imagePaths: {imageId: path},
    );

    await _pump(
      tester,
      AppScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NoteEditPage(noteId: '1'),
        ),
      ),
    );

    await expectLater(
      find.byType(NoteEditPage),
      matchesGoldenFile('goldens/note_with_image.png'),
    );
  });

  testWidgets('富文本笔记', (tester) async {
    // 直接把带样式的文档塞进正文，截图里就能看出六种格式的实际效果。
    final body = jsonEncode([
      {
        'insert': '周五的采购清单\n',
        'attributes': {'bold': true, 'size': 'huge'},
      },
      {'insert': '牛奶、鸡蛋、面包\n'},
      {
        'insert': '顺便带一袋咖啡豆',
        'attributes': {'background': '#fffff176'},
      },
      {
        'insert': '（上次又忘了）',
        'attributes': {'color': '#ffd32f2f'},
      },
      {'insert': '\n'},
      {
        'insert': '过期新闻不要买',
        'attributes': {'italic': true, 'underline': true},
      },
      {'insert': '，看保质期。\n'},
    ]);
    final services = _services(
      notes: [_note('1', body, ago: const Duration(minutes: 12))],
    );

    await _pump(
      tester,
      AppScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const NoteEditPage(noteId: '1'),
        ),
      ),
    );

    await expectLater(
      find.byType(NoteEditPage),
      matchesGoldenFile('goldens/note_rich_text.png'),
    );
  });
}
