import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/local/local_store.dart';
import '../util/note_text.dart';
import 'note_edit_page.dart';

/// 「未完成」汇总页：把所有笔记里还没勾上的待办挑出来，按笔记分组列出来。
///
/// 点一条就打开那篇笔记，并把光标落在这一行上。
class UnfinishedPage extends StatelessWidget {
  const UnfinishedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('未完成', style: TextStyle(fontSize: 15))),
      body: StreamBuilder<List<LocalNote>>(
        stream: services.local.watchVisibleNotes(),
        builder: (context, snapshot) {
          final notes = snapshot.data;
          if (notes == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // 加锁又没解锁的笔记不看正文，免得把内容漏到这一页上。
          final groups = <({LocalNote note, List<UncheckedTodo> todos})>[];
          for (final note in notes) {
            if (note.locked && !services.isUnlocked(note.id)) continue;
            final todos = uncheckedTodos(note.body);
            if (todos.isEmpty) continue;
            groups.add((note: note, todos: todos));
          }

          if (groups.isEmpty) {
            return const _Hint(text: '没有未完成的勾选项');
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      noteTitle(group.note.body),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final todo in group.todos)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_box_outlined, size: 20),
                      title: Text(
                        todo.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NoteEditPage(
                            noteId: group.note.id,
                            focusOffset: todo.offset,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
