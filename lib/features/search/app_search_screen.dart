import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/task_format.dart';
import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../calendar/calendar_screen.dart';
import '../notes/note_editor.dart';

class AppSearchScreen extends ConsumerStatefulWidget {
  const AppSearchScreen({super.key});

  @override
  ConsumerState<AppSearchScreen> createState() => _AppSearchScreenState();
}

class _AppSearchScreenState extends ConsumerState<AppSearchScreen> {
  final _ctrl = TextEditingController();
  List<TaskWithType> _tasks = [];
  List<Note> _notes = [];
  bool _searching = false;
  int _token = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    final myToken = ++_token;
    if (q.isEmpty) {
      setState(() {
        _tasks = [];
        _notes = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final db = ref.read(databaseProvider);
    final tasks = await db.taskDao.searchTasks(q);
    final notes = await db.noteDao.searchNotes(q);
    if (!mounted || myToken != _token) return;
    setState(() {
      _tasks = tasks;
      _notes = notes;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasQuery = _ctrl.text.trim().isNotEmpty;
    final empty = hasQuery && !_searching && _tasks.isEmpty && _notes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _run,
          decoration: InputDecoration(
            hintText: 'Search tasks and notes…',
            border: InputBorder.none,
            suffixIcon: hasQuery
                ? IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () {
                      _ctrl.clear();
                      _run('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: !hasQuery
          ? _hint(context, cs)
          : empty
              ? Center(
                  child: Text('No results',
                      style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView(
                  children: [
                    if (_tasks.isNotEmpty) ...[
                      _sectionHeader(context, 'Tasks', _tasks.length),
                      ..._tasks.map(_taskTile),
                    ],
                    if (_notes.isNotEmpty) ...[
                      _sectionHeader(context, 'Notes', _notes.length),
                      ..._notes.map(_noteTile),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _hint(BuildContext context, ColorScheme cs) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.search, size: 56, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('Search across tasks and notes',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );

  Widget _sectionHeader(BuildContext context, String title, int count) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('$title · $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _taskTile(TaskWithType t) {
    final done = t.task.endAt != null;
    return ListTile(
      leading: Icon(
        done ? Symbols.check_circle : Symbols.radio_button_unchecked,
        fill: done ? 1 : 0,
        color: colorFromHex(t.taskType.colorHex),
      ),
      title: Text(t.task.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${t.taskType.name} · ${priorityLabel(t.task.priority)} · ${DateFormat('d MMM').format(t.task.date)}'),
      onTap: () async {
        final milestones =
            await ref.read(databaseProvider).taskDao.getMilestones(t.task.id);
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => TaskFormSheet(
            date: t.task.date,
            initialProfileId: t.task.profileId,
            task: t,
            existingMilestones: milestones,
          ),
        );
      },
    );
  }

  Widget _noteTile(Note n) {
    final title = n.title.trim().isEmpty
        ? (n.body.trim().isEmpty ? 'Empty note' : n.body.trim())
        : n.title;
    return ListTile(
      leading: Icon(Symbols.sticky_note_2, color: colorFromHex(n.colorHex)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: n.title.trim().isNotEmpty && n.body.trim().isNotEmpty
          ? Text(n.body.trim(), maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteEditorScreen(note: n)),
      ),
    );
  }
}
