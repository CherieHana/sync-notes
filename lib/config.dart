/// 构建期注入的 Supabase 配置。
///
/// 通过 `--dart-define-from-file=config.json` 传入，不要把真实值写进源码。
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  factory AppConfig.fromEnvironment() {
    return AppConfig(supabaseUrl: _url, supabaseAnonKey: _anonKey);
  }

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
