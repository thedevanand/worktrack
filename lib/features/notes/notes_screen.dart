import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import 'note_editor.dart';

final _notesProvider = StreamProvider.autoDispose
    .family<List<Note>, ({bool archived, int? profileId})>((ref, args) {
  return ref
      .watch(databaseProvider)
      .noteDao
      .watchNotes(archived: args.archived, profileId: args.profileId);
});

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool _showArchived = false;
  int? _profileId;

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];
    final notesAsync = ref.watch(
        _notesProvider((archived: _showArchived, profileId: _profileId)));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Archived Notes' : 'Notes'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Active notes' : 'Archived notes',
            icon: Icon(_showArchived ? Symbols.notes : Symbols.inventory_2),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          if (profiles.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _profileId == null,
                    onSelected: (_) => setState(() => _profileId = null),
                  ),
                  const SizedBox(width: 8),
                  ...profiles.map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(p.name),
                          selected: _profileId == p.id,
                          avatar: CircleAvatar(
                              backgroundColor: colorFromHex(p.colorHex),
                              radius: 7),
                          onSelected: (v) =>
                              setState(() => _profileId = v ? p.id : null),
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: notesAsync.when(
              data: (notes) => notes.isEmpty
                  ? _empty(context)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) =>
                          _NoteCard(note: notes[i], archivedView: _showArchived),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_notes',
              icon: const Icon(Symbols.add),
              label: const Text('Note'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        NoteEditorScreen(initialProfileId: _profileId)),
              ),
            ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_showArchived ? Symbols.inventory_2 : Symbols.sticky_note_2,
                size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(_showArchived ? 'No archived notes' : 'No notes yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.archivedView});

  final Note note;
  final bool archivedView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(note.colorHex);
    final preview = note.body.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
      ),
      onLongPress: () => _menu(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.title.trim().isNotEmpty)
              Text(note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            if (note.title.trim().isNotEmpty) const SizedBox(height: 6),
            Expanded(
              child: Text(
                preview.isEmpty ? 'Empty note' : preview,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _menu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(archivedView ? Symbols.unarchive : Symbols.archive),
              title: Text(archivedView ? 'Unarchive' : 'Archive'),
              onTap: () {
                ref
                    .read(databaseProvider)
                    .noteDao
                    .setArchived(note.id, !archivedView);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Symbols.delete,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Delete'),
              onTap: () {
                ref.read(databaseProvider).noteDao.deleteNote(note.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
