import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import 'markdown_highlight.dart';

const _noteColors = [
  '#FBBF24', '#34D399', '#60A5FA', '#F472B6',
  '#A78BFA', '#FB923C', '#94A3B8', '#F87171',
];

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen(
      {super.key, this.note, this.initialProfileId, this.initialTaskId});

  final Note? note;
  final int? initialProfileId;
  final int? initialTaskId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String _colorHex;
  int? _profileId;
  int? _taskId;
  // Notes render (compile) by default; "Raw" reveals the markdown source.
  // New/empty notes open straight into raw so you can start typing.
  late bool _raw;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _raw = widget.note == null;
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _bodyCtrl = TextEditingController(text: n?.body ?? '');
    _colorHex = n?.colorHex ?? _noteColors.first;
    _profileId = n?.profileId ?? widget.initialProfileId;
    _taskId = n?.taskId ?? widget.initialTaskId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _isEmpty =>
      _titleCtrl.text.trim().isEmpty && _bodyCtrl.text.trim().isEmpty;

  Future<void> _save() async {
    if (_saved) return;
    if (_isEmpty && widget.note == null) return; // don't save empty new notes
    final dao = ref.read(databaseProvider).noteDao;
    final now = DateTime.now();
    if (widget.note == null) {
      await dao.insertNote(NotesCompanion.insert(
        profileId: Value(_profileId),
        taskId: Value(_taskId),
        title: Value(_titleCtrl.text.trim()),
        body: Value(_bodyCtrl.text),
        colorHex: Value(_colorHex),
      ));
    } else {
      await dao.updateNote(widget.note!.toCompanion(true).copyWith(
            title: Value(_titleCtrl.text.trim()),
            body: Value(_bodyCtrl.text),
            colorHex: Value(_colorHex),
            profileId: Value(_profileId),
            taskId: Value(_taskId),
            updatedAt: Value(now),
          ));
    }
    _saved = true;
  }

  // ── Markdown insertion helpers ─────────────────────────────────────────────

  void _wrap(String left, String right) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid) {
      _bodyCtrl.text = '$text$left$right';
      return;
    }
    final selected = sel.textInside(text);
    final newText = text.replaceRange(
        sel.start, sel.end, '$left$selected$right');
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: sel.start + left.length + selected.length),
    );
  }

  void _linePrefix(String prefix) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final pos = sel.isValid ? sel.start : text.length;
    var lineStart = pos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _save();
        nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New Note' : 'Note'),
          actions: [
            IconButton(
              tooltip: _raw ? 'Rendered' : 'Raw',
              icon: Icon(_raw ? Symbols.visibility : Symbols.code),
              onPressed: () => setState(() => _raw = !_raw),
            ),
            IconButton(
              tooltip: 'Options',
              icon: const Icon(Symbols.more_vert),
              onPressed: () => _showOptions(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _titleCtrl,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                cursorColor: colorFromHex(_colorHex),
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
            Expanded(
              child: _raw ? _buildEditor() : _buildRendered(),
            ),
            if (_raw) _toolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: TextField(
        controller: _bodyCtrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        cursorColor: colorFromHex(_colorHex),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        decoration: InputDecoration(
          hintText: 'Start writing…  Markdown supported',
          border: InputBorder.none,
          hintStyle:
              TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildRendered() {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      return InkWell(
        onTap: () => setState(() => _raw = true),
        child: Center(
          child: Text('Tap to start writing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }
    // Tap anywhere on the rendered note to jump into raw editing.
    return GestureDetector(
      onTap: () => setState(() => _raw = true),
      child: Markdown(
        data: body,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        inlineSyntaxes: [HighlightSyntax()],
        builders: {
          'highlight': HighlightBuilder(colorFromHex(_colorHex)),
        },
        onTapLink: (text, href, title) {
          // Offline app: links render but aren't opened (stays sandboxed).
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              _tb(Symbols.format_bold, () => _wrap('**', '**')),
              _tb(Symbols.format_italic, () => _wrap('*', '*')),
              _tb(Symbols.format_ink_highlighter, () => _wrap('==', '==')),
              _tb(Symbols.title, () => _linePrefix('# ')),
              _tb(Symbols.format_list_bulleted, () => _linePrefix('- ')),
              _tb(Symbols.checklist, () => _linePrefix('- [ ] ')),
              _tb(Symbols.format_quote, () => _linePrefix('> ')),
              _tb(Symbols.code, () => _wrap('`', '`')),
              _tb(Symbols.link, () => _wrap('[', '](https://)')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tb(IconData icon, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, size: 22), onPressed: onTap);
  }

  void _showOptions(BuildContext context) {
    final profiles = ref.read(activeProfilesProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _noteColors.map((hex) {
                  final selected = hex == _colorHex;
                  return GestureDetector(
                    onTap: () {
                      setLocal(() {});
                      setState(() => _colorHex = hex);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(ctx).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Symbols.check,
                              size: 16, color: Colors.black)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (profiles.length > 1) ...[
                Text('Profile', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('None'),
                      selected: _profileId == null,
                      onSelected: (_) {
                        setLocal(() {});
                        setState(() => _profileId = null);
                      },
                    ),
                    ...profiles.map((p) => ChoiceChip(
                          label: Text(p.name),
                          selected: _profileId == p.id,
                          avatar: CircleAvatar(
                              backgroundColor: colorFromHex(p.colorHex),
                              radius: 7),
                          onSelected: (_) {
                            setLocal(() {});
                            setState(() => _profileId = p.id);
                          },
                        )),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.link),
                title: const Text('Attach task'),
                subtitle: _AttachedTaskLabel(taskId: _taskId),
                trailing: _taskId != null
                    ? IconButton(
                        icon: const Icon(Symbols.close),
                        onPressed: () {
                          setLocal(() {});
                          setState(() => _taskId = null);
                        },
                      )
                    : const Icon(Symbols.chevron_right),
                onTap: () async {
                  final picked = await _pickTask(ctx);
                  if (picked != null) {
                    setLocal(() {});
                    setState(() => _taskId = picked);
                  }
                },
              ),
              if (widget.note != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(widget.note!.isArchived
                      ? Symbols.unarchive
                      : Symbols.archive),
                  title: Text(
                      widget.note!.isArchived ? 'Unarchive' : 'Archive'),
                  onTap: () async {
                    final sheetNav = Navigator.of(ctx);
                    final pageNav = Navigator.of(context);
                    await ref
                        .read(databaseProvider)
                        .noteDao
                        .setArchived(widget.note!.id, !widget.note!.isArchived);
                    _saved = true;
                    sheetNav.pop();
                    pageNav.pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _pickTask(BuildContext context) async {
    final tasks =
        await ref.read(databaseProvider).taskDao.watchAllTasks().first;
    if (!context.mounted) return null;
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ListView(
        children: tasks
            .map((t) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: colorFromHex(t.taskType.colorHex),
                      radius: 6),
                  title: Text(t.task.title),
                  onTap: () => Navigator.pop(context, t.task.id),
                ))
            .toList(),
      ),
    );
  }
}

class _AttachedTaskLabel extends ConsumerWidget {
  const _AttachedTaskLabel({required this.taskId});

  final int? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (taskId == null) return const Text('Optional');
    final tasksAsync = ref.watch(_attachTaskProvider(taskId!));
    return Text(tasksAsync.valueOrNull ?? '…');
  }
}

final _attachTaskProvider =
    FutureProvider.autoDispose.family<String, int>((ref, id) async {
  final all = await ref.watch(databaseProvider).taskDao.watchAllTasks().first;
  final match = all.where((t) => t.task.id == id).firstOrNull;
  return match?.task.title ?? 'Task #$id';
});
