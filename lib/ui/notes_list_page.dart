import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app_services.dart';
import '../data/local/local_store.dart';
import '../data/sync/sync_controller.dart';
import '../util/note_text.dart';
import 'note_edit_page.dart';

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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createNote() async {
    final services = AppScope.of(context);
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

  Future<void> _delete(LocalNote note) async {
    final services = AppScope.of(context);
    await services.local.softDelete(id: note.id, now: DateTime.now());
    unawaited(services.sync.sync());
  }

  Future<void> _open(LocalNote note) async {
    final services = AppScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditPage(noteId: note.id)),
    );
    if (!mounted) return;
    unawaited(services.sync.sync());
  }

  Future<void> _confirmSignOut() async {
    final services = AppScope.of(context);
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
              if (value == 'signOut') unawaited(_confirmSignOut());
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
              const PopupMenuItem<String>(
                value: 'signOut',
                child: Text('退出登录'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: SyncStatusBar(controller: services.sync),
        ),
      ),
      body: StreamBuilder<List<LocalNote>>(
        stream: services.local.watchVisibleNotes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredHint(text: '读取本地数据出错：${snapshot.error}');
          }
          final notes = snapshot.data;
          if (notes == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _query.isEmpty
              ? notes
              : notes
                    .where(
                      (n) =>
                          n.body.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();

          if (filtered.isEmpty) {
            return _CenteredHint(
              text: notes.isEmpty
                  ? '还没有笔记，点右下角写一条'
                  : '没有匹配「$_query」的笔记',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final note = filtered[index];
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    noteTitle(note.body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      notePreview(note.body),
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
                ),
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
