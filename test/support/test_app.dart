// 测试里搭界面的公共脚手架。
//
// 几个界面测试都要「用内存依赖 + 本地化代理」把 App 或某一页搭起来，
// 这段代码放这里共用，免得每个测试文件各抄一份走样。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_notes/app_services.dart';
import 'package:sync_notes/data/sync/sync_controller.dart';
import 'package:sync_notes/data/sync/sync_engine.dart';
import 'package:sync_notes/main.dart';
import 'package:sync_notes/ui/notes_list_page.dart';

import 'fake_store.dart';

/// 用内存实现替换真实依赖，测试里不碰文件系统也不连网络。
AppServices buildTestServices(String userId) {
  final local = FakeLocalStore()..device = 'ui-test-device';
  final remote = FakeRemoteApi();
  final engine = SyncEngine(local: local, remote: remote);
  final sync = SyncController(engine: engine, remote: remote, local: local);
  return AppServices(
    userId: userId,
    local: local,
    remote: remote,
    engine: engine,
    sync: sync,
  );
}

/// 走和正式运行一样的 widget 树（AuthenticatedApp）。
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    AuthenticatedApp(
      userId: 'ui-test-user',
      servicesBuilder: buildTestServices,
    ),
  );
  await tester.pumpAndSettle();
}

/// 直接把依赖挂到树上，方便测试里预置数据。
Future<void> pumpWithServices(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        // 工具栏要 Quill 的本地化代理，缺了编辑页会抛异常。
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const NotesListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
