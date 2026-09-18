import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';

/// 选择器里代表「未分类」的返回值。
///
/// 用哨兵字符串而不是 null，是因为 null 要留给「用户取消了」。
const String pickUncategorized = '__uncategorized__';

/// 弹出目录选择器。返回目录 id、[pickUncategorized]，或者 null（取消）。
Future<String?> showFolderPicker(
  BuildContext context, {
  required List<LocalFolder> folders,
  required String? currentFolderId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              '移动到…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('未分类'),
            selected: currentFolderId == null,
            onTap: () => Navigator.of(context).pop(pickUncategorized),
          ),
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              selected: currentFolderId == folder.id,
              onTap: () => Navigator.of(context).pop(folder.id),
            ),
        ],
      ),
    ),
  );
}
