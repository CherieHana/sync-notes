import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_services.dart';
import 'config.dart';
import 'services/external_drop.dart';
import 'ui/login_page.dart';
import 'ui/notes_list_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    // 用 publishableKey 传：新版 publishable key 和旧版 anon key 在这里是
    // 同一种东西（都作为请求头的 apikey），不会影响老项目。
    publishableKey: config.supabaseAnonKey,
  );
  // 拖放事件要在界面起来之前接上，免得早期的拖放被丢掉。
  ExternalDrop.listen();
  runApp(const SyncNotesApp());
}

final ThemeData _appTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFFF5C34B),
  scaffoldBackgroundColor: const Color(0xFFFDFBF5),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFDFBF5),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
);

/// 富文本工具栏的本地化。
///
/// 这三个（加上 Quill 自己的）必须给全：缺了的话正式包里工具栏不会报错，
/// 而是整条渲染成一块灰条，看起来像「工具栏没加载出来」（踩过）。
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  FlutterQuillLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const List<Locale> appSupportedLocales = [Locale('zh'), Locale('en')];

/// 根据登录状态在登录页和笔记页之间切换。
///
/// 登录态由 Supabase 持久化，重开 App 会自动恢复，不需要每次输密码。
class SyncNotesApp extends StatelessWidget {
  const SyncNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) {
          return MaterialApp(
            title: '备忘录',
            debugShowCheckedModeBanner: false,
            theme: _appTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: const LoginPage(),
          );
        }
        return AuthenticatedApp(
          key: ValueKey(session.user.id),
          userId: session.user.id,
        );
      },
    );
  }
}

/// 登录之后才有意义的一切：本地库、同步引擎、界面。
///
/// 按账号重建，退出登录时整体释放，避免上一个账号的数据串到下一个账号。
///
/// 注意 [AppScope] 必须套在 [MaterialApp] **外面**。MaterialApp 里的 Navigator
/// 会把 push 出来的页面挂在它自己的 Overlay 下、和首页平级；如果 AppScope 在
/// MaterialApp 里面，新页面就取不到它，直接白屏。
class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({
    super.key,
    required this.userId,
    this.servicesBuilder,
  });

  final String userId;

  /// 测试用：换成内存版的依赖，避免真的去建数据库和连网络。
  final AppServices Function(String userId)? servicesBuilder;

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp>
    with WidgetsBindingObserver {
  late final AppServices _services =
      widget.servicesBuilder?.call(widget.userId) ??
      AppServices.create(Supabase.instance.client, widget.userId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_services.sync.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切回前台时补一次对账，手机端不做后台常驻推送。
    if (state == AppLifecycleState.resumed) {
      unawaited(_services.sync.sync());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_services.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: MaterialApp(
        title: '备忘录',
        debugShowCheckedModeBanner: false,
        theme: _appTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const NotesListPage(),
      ),
    );
  }
}

/// 没有配置 Supabase 时给一句人能看懂的话，而不是白屏或崩溃。
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('还没有配置 Supabase', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 12),
                  Text(
                    '1. 复制项目根目录的 config.example.json 为 config.json\n'
                    '2. 把里面的 SUPABASE_URL 和 SUPABASE_ANON_KEY 换成你项目的值\n'
                    '3. 用 --dart-define-from-file=config.json 重新构建运行',
                    style: TextStyle(height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
