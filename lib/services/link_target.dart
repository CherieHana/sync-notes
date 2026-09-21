import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// 链接指向哪里。
enum LinkKind {
  /// 网址，交给浏览器。
  http,

  /// 本机文件，交给系统默认程序打开。
  file,

  /// 别的协议（tg:// 之类），原样交给系统，打不开就算了。
  other,
}

final RegExp _windowsPath = RegExp(r'^[a-zA-Z]:[\\/]');

/// 判断一个链接指向什么。抽出来是为了能单测，也让「打开」这一步好替换。
LinkKind classifyLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return LinkKind.other;

  // Windows 的盘符路径要最先认出来：`C:\...` 里的 `C:` 会被 Uri 当成协议名
  // （scheme = 'c'），先按协议走就会掉进「别的协议」里去。
  if (_windowsPath.hasMatch(value)) return LinkKind.file;

  final scheme = Uri.tryParse(value)?.scheme.toLowerCase() ?? '';
  if (scheme == 'http' || scheme == 'https') return LinkKind.http;
  if (scheme == 'file') return LinkKind.file;
  if (scheme.isEmpty) {
    // 裸的绝对路径也算文件链接（/Users/... 这种）。
    if (value.startsWith('/')) return LinkKind.file;
  }
  return LinkKind.other;
}

/// 绝对路径 → 链接里存的形式。
String fileLinkUrl(String path) => Uri.file(path).toString();

/// 从链接里取回本机路径。不是文件链接就返回 null。
String? filePathFromLink(String raw) {
  final value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.scheme == 'file') {
    try {
      return uri.toFilePath();
    } catch (_) {
      return null;
    }
  }
  return classifyLink(value) == LinkKind.file ? value : null;
}

/// 打开链接的实现。返回 null 表示成功，否则是给用户看的一句话。
///
/// 做成可替换的全局，是因为「真去调浏览器 / 系统程序」在自动化测试里没法验证，
/// 测试会换成桩函数；正式运行就是 [defaultLinkOpener]。
typedef LinkOpener = Future<String?> Function(String url);

LinkOpener linkOpener = defaultLinkOpener;

/// 编辑器要把链接交给系统之前问一句：这串文字该怎么补全。
///
/// Quill 默认会给「看着不像链接」的文字前面补 `https://`，本机文件链接
/// （`file:///C:/...` 或裸的盘符路径）会被改成 `https://file:///...`，
/// 点开当然打不开。所以这里的规则是：认得出来的（网页、文件、别的协议）
/// 一律原样放行，只有光秃秃的域名才补协议。
String normalizeLink(String link) {
  final value = link.trim();
  if (value.isEmpty) return value;
  if (classifyLink(value) != LinkKind.other) return value;
  if (Uri.tryParse(value)?.scheme.isNotEmpty ?? false) return value;
  return 'https://$value';
}

Future<String?> defaultLinkOpener(String url) async {
  switch (classifyLink(url)) {
    case LinkKind.http:
    case LinkKind.other:
      try {
        final ok = await launchUrl(
          Uri.parse(url.trim()),
          mode: LaunchMode.externalApplication,
        );
        return ok ? null : '打不开这个链接';
      } catch (_) {
        return '打不开这个链接';
      }

    case LinkKind.file:
      final path = filePathFromLink(url);
      if (path == null) return '这个文件链接看不懂';
      if (!File(path).existsSync()) return '这个文件只在那台设备上有';

      if (!kIsWeb && Platform.isWindows) {
        // Windows 上交给 ShellExecute，不会闪一下黑窗口。
        try {
          final ok = await launchUrl(
            Uri.file(path),
            mode: LaunchMode.externalApplication,
          );
          if (ok) return null;
        } catch (_) {
          // 落到下面的 OpenFilex 再试一次。
        }
      }

      // 安卓走 OpenFilex：那边它用 FileProvider，
      // 直接把 file:// 丢给别的应用会被系统拦下来。
      try {
        final result = await OpenFilex.open(path);
        return result.type == ResultType.done
            ? null
            : '打不开这个文件：${result.message}';
      } catch (error) {
        return '打不开这个文件：$error';
      }
  }
}
