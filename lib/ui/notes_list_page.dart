import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app_services.dart';
import '../data/local/local_store.dart';
import '../data/sync/sync_controller.dart';
import '../services/file_import.dart';
import '../util/note_text.dart';
import 'note_edit_page.dart';
import 'widgets/folder_picker.dart';
import 'widgets/text_prompt_dialog.dart';

/// 顶部目录标签里代表「全部」和「未分类」的两个固定项。
const String _allTab = '__all__';
const String _uncategorizedTab = '__none__';

/// 笔记列表。数据源是本地库的 watch 流，所以断网也有完整内容，
/// 远端变化会在同步写入本地后自动反映到这里。
class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  /// 当前选中的目录标签：[_allTab]、[_uncategorizedTab] 或某个目录 id。
  String _tab = _allTab;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AppServices get _services => AppScope.of(context);

  // ---------------------------------------------------------------------
  // 笔记
  // ---------------------------------------------------------------------

  Future<void> _createNote() async {
    final services = _services;
    final now = DateTime.now();
    final id = const Uuid().v4();

    await services.local.createNote(
      LocalNote(
        id: id,
        body: '',
        version: 1,
        baseVersion: 0,
        createdAt: now,
        updatedAt: now,
        folderId: _folderForNewNote,
        dirty: true,
        isNew: true,
      ),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditPage(noteId: id)),
    );
    if (!mounted) return;
    unawaited(services.sync.sync());
  }

  /// 在某个目录标签下新建的笔记直接落进那个目录。
  String? get _folderForNewNote {
    if (_tab == _allTab || _tab == _uncategorizedTab) return null;
    return _tab;
  }

  Future<void> _open(LocalNote note) async {
    final services = _services;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditPage(noteId: note.id)),
    );
    if (!mounted) return;
    unawaited(services.sync.sync());
  }

  /// 左滑删除，底部给 5 秒的反悔机会。
  Future<void> _delete(LocalNote note) async {
    final services = _services;
    final messenger = ScaffoldMessenger.of(context);
    await services.local.softDelete(id: note.id, now: DateTime.now());

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${noteTitle(note.body)}」'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              unawaited(() async {
                await services.local.restore(
                  id: note.id,
                  now: DateTime.now(),
                );
                unawaited(services.sync.sync());
              }());
            },
          ),
        ),
      );
    unawaited(services.sync.sync());
  }

  Future<void> _moveNote(LocalNote note, List<LocalFolder> folders) async {
    final services = _services;
    final chosen = await showFolderPicker(
      context,
      folders: folders,
      currentFolderId: note.folderId,
    );
    if (chosen == null || !mounted) return;

    await services.local.setNoteFolder(
      id: note.id,
      folderId: chosen == pickUncategorized ? null : chosen,
      now: DateTime.now(),
    );
    unawaited(services.sync.sync());
  }

  /// 桌面端的右键菜单。
  ///
  /// 「把笔记换个目录」这件事本来只有长按才触发，触屏上没问题，
  /// 但用鼠标长按（按住不放）不是个自然的动作，等于藏起来了。
  /// 这里补一个右键入口，和长按走同一套逻辑。
  Future<void> _showNoteMenu(
    LocalNote note,
    List<LocalFolder> folders,
    Offset position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(value: 'move', child: Text('移动到…')),
        PopupMenuItem<String>(value: 'delete', child: Text('删除')),
      ],
    );
    if (!mounted || action == null) return;

    if (action == 'move') {
      await _moveNote(note, folders);
    } else if (action == 'delete') {
      await _delete(note);
    }
  }

  // ---------------------------------------------------------------------
  // 目录
  // ---------------------------------------------------------------------

  Future<void> _createFolder() async {
    final services = _services;
    final name = await _askFolderName(title: '新建目录');
    if (name == null || !mounted) return;

    final now = DateTime.now();
    final id = const Uuid().v4();
    await services.local.createFolder(
      LocalFolder(
        id: id,
        name: name,
        version: 1,
        baseVersion: 0,
        createdAt: now,
        updatedAt: now,
        dirty: true,
        isNew: true,
      ),
    );
    if (mounted) setState(() => _tab = id);
    unawaited(services.sync.sync());
  }

  Future<void> _folderActions(LocalFolder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                folder.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除目录'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'rename') {
      final name = await _askFolderName(title: '重命名目录', initial: folder.name);
      if (name == null || !mounted) return;
      await _services.local.renameFolder(
        id: folder.id,
        name: name,
        now: DateTime.now(),
      );
      unawaited(_services.sync.sync());
      return;
    }

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('删除「${folder.name}」？'),
          content: const Text('目录里的笔记不会被删掉，会回到「未分类」。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await _services.local.softDeleteFolder(
        id: folder.id,
        now: DateTime.now(),
      );
      if (mounted && _tab == folder.id) setState(() => _tab = _allTab);
      unawaited(_services.sync.sync());
    }
  }

  Future<String?> _askFolderName({required String title, String? initial}) {
    return TextPromptDialog.show(
      context,
      title: title,
      confirmLabel: '确定',
      hint: '目录名称',
      initial: initial,
    ).then((value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    });
  }

  // ---------------------------------------------------------------------
  // 导入
  // ---------------------------------------------------------------------

  Future<void> _importFiles() async {
    final services = _services;
    final List<PlatformFile> files;
    try {
      files = await FileImport.pickFiles();
    } catch (error) {
      _toast('打不开文件选择器：$error');
      return;
    }
    if (files.isEmpty || !mounted) return;

    var imported = 0;
    var hasLarge = false;
    final failed = <String>[];

    for (final file in files) {
      try {
        final document = await FileImport.parse(file);
        if (document.byteSize > FileImport.largeFileBytes) hasLarge = true;

        final now = DateTime.now();
        await services.local.createNote(
          LocalNote(
            id: const Uuid().v4(),
            body: document.body,
            version: 1,
            baseVersion: 0,
            createdAt: now,
            updatedAt: now,
            folderId: _folderForNewNote,
            dirty: true,
            isNew: true,
          ),
        );
        imported++;
      } catch (_) {
        failed.add(file.name);
      }
    }

    unawaited(services.sync.sync());

    final parts = <String>[];
    if (imported > 0) parts.add('导入了 $imported 篇');
    if (failed.isNotEmpty) parts.add('${failed.length} 个文件读不了');
    if (hasLarge) parts.add('大文件同步会慢一些');
    _toast(parts.isEmpty ? '没有导入任何内容' : parts.join('，'));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSignOut() async {
    final services = _services;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: Text(
          services.accountEmail.isEmpty
              ? '本地已经写好的内容不会丢，重新登录就能接着用。'
              : '当前账号：${services.accountEmail}\n\n'
                    '本地已经写好的内容不会丢，重新登录同一个账号就能接着用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await services.signOut?.call();
  }

  // ---------------------------------------------------------------------
  // 界面
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索笔记',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('备忘录'),
        actions: [
          IconButton(
            tooltip: _searching ? '取消搜索' : '搜索',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'folder':
                  unawaited(_createFolder());
                case 'import':
                  unawaited(_importFiles());
                case 'signOut':
                  unawaited(_confirmSignOut());
              }
            },
            itemBuilder: (context) => [
              if (services.accountEmail.isNotEmpty)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    services.accountEmail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'folder', child: Text('新建目录')),
              const PopupMenuItem(value: 'import', child: Text('导入文件')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'signOut', child: Text('退出登录')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: SyncStatusBar(controller: services.sync),
        ),
      ),
      body: StreamBuilder<List<LocalFolder>>(
        stream: services.local.watchVisibleFolders(),
        builder: (context, folderSnapshot) {
          final folders = folderSnapshot.data ?? const <LocalFolder>[];
          return StreamBuilder<List<LocalNote>>(
            stream: services.local.watchVisibleNotes(),
            builder: (context, noteSnapshot) {
              if (noteSnapshot.hasError) {
                return _CenteredHint(
                  text: '读取本地数据出错：${noteSnapshot.error}',
                );
              }
              final notes = noteSnapshot.data;
              if (notes == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final visible = _filterNotes(notes, folders);
              return Column(
                children: [
                  _FolderTabs(
                    folders: folders,
                    selected: _tab,
                    onSelect: (tab) => setState(() => _tab = tab),
                    onLongPress: (folder) => unawaited(_folderActions(folder)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: visible.isEmpty
                        ? _CenteredHint(text: _emptyHint(notes))
                        : _buildList(visible, folders),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建笔记',
        onPressed: _createNote,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  String _emptyHint(List<LocalNote> all) {
    if (_query.isNotEmpty) return '没有匹配「$_query」的笔记';
    if (all.isEmpty) return '还没有笔记，点右下角写一条';
    return '这个目录下还没有笔记';
  }

  List<LocalNote> _filterNotes(
    List<LocalNote> notes,
    List<LocalFolder> folders,
  ) {
    // 目录可能已经被别的设备删掉了，那种笔记一律按未分类算。
    final aliveFolderIds = folders.map((f) => f.id).toSet();

    var result = notes;
    if (_tab == _uncategorizedTab) {
      result = result
          .where(
            (n) => n.folderId == null || !aliveFolderIds.contains(n.folderId),
          )
          .toList();
    } else if (_tab != _allTab) {
      result = result.where((n) => n.folderId == _tab).toList();
    }

    if (_query.isEmpty) return result;
    final query = _query.toLowerCase();
    return result.where((note) {
      // 加锁且还没解锁的笔记只按标题匹配，避免搜索把正文内容漏出去。
      final locked =
          note.locked && !(_services.isUnlocked(note.id));
      if (locked) return noteTitle(note.body).toLowerCase().contains(query);
      return note.body.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildList(List<LocalNote> notes, List<LocalFolder> folders) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: notes.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final note = notes[index];
        final locked = note.locked && !_services.isUnlocked(note.id);
        return Dismissible(
          key: ValueKey(note.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => _delete(note),
          child: GestureDetector(
            // 鼠标右键；触屏上仍然用长按。
            onSecondaryTapDown: (details) =>
                unawaited(_showNoteMenu(note, folders, details.globalPosition)),
            child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Row(
              children: [
                if (locked) ...[
                  const Icon(Icons.lock_outline, size: 14),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    noteTitle(note.body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                locked ? '已加密，打开需要口令' : notePreview(note.body),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                ),
              ),
            ),
            trailing: Text(
              formatListTime(note.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _open(note),
            onLongPress: () => unawaited(_moveNote(note, folders)),
            ),
          ),
        );
      },
    );
  }
}

/// 顶部那一排目录标签。
class _FolderTabs extends StatelessWidget {
  const _FolderTabs({
    required this.folders,
    required this.selected,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<LocalFolder> folders;
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<LocalFolder> onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip(context, _allTab, '全部'),
          _chip(context, _uncategorizedTab, '未分类'),
          for (final folder in folders)
            GestureDetector(
              onLongPress: () => onLongPress(folder),
              child: _chip(context, folder.id, folder.name),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String value, String label) {
    final isSelected = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        // 长按由外层的 GestureDetector 处理，点击走这里。
        onSelected: (_) => onSelect(value),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// 顶部那条细状态栏：让人一眼看出现在是已同步、同步中还是离线。
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key, required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final (IconData icon, String label, Color color) = switch (
          controller.status
        ) {
          SyncStatus.syncing => (
            Icons.cloud_sync_outlined,
            '同步中…',
            Theme.of(context).colorScheme.primary,
          ),
          SyncStatus.offline => (
            Icons.cloud_off_outlined,
            '离线，改动会在联网后上传',
            Theme.of(context).colorScheme.error,
          ),
          SyncStatus.error => (
            Icons.error_outline,
            '同步出错：${controller.lastError ?? '未知原因'}',
            Theme.of(context).colorScheme.error,
          ),
          SyncStatus.idle => controller.pendingCount > 0
              ? (
                  Icons.cloud_upload_outlined,
                  '${controller.pendingCount} 条待同步',
                  Theme.of(context).colorScheme.primary,
                )
              : (
                  Icons.cloud_done_outlined,
                  '已同步',
                  Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                ),
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
