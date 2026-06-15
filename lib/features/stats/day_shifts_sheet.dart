import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_edit_dialog.dart';

final _dayShiftsProvider =
    StreamProvider.autoDispose.family<List<Shift>, String>((ref, dateKey) {
  final p = dateKey.split('-');
  final date =
      DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  return ref.watch(shiftRepositoryProvider).watchAllShiftsForDate(date);
});

/// Opens a bottom sheet listing the shifts for [date], with edit/delete.
Future<void> showDayShiftsSheet(BuildContext context, DateTime date) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DayShiftsSheet(date: date),
  );
}

class _DayShiftsSheet extends ConsumerWidget {
  const _DayShiftsSheet({required this.date});

  final DateTime date;

  String get _key =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(_dayShiftsProvider(_key));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              DateFormat('EEEE, d MMMM').format(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: shiftsAsync.when(
              data: (shifts) => shifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Symbols.event_busy,
                              size: 36,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant),
                          const SizedBox(height: 8),
                          Text('No shifts logged',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: shifts.length,
                      itemBuilder: (ctx, i) => _ShiftRow(shift: shifts[i]),
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftRow extends ConsumerWidget {
  const _ShiftRow({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = formatTime(shift.clockInAt);
    final end =
        shift.clockOutAt != null ? formatTime(shift.clockOutAt!) : '...';
    final duration = ShiftRepository.netDuration(shift, []);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          shift.clockOutAt == null
              ? Symbols.radio_button_checked
              : Symbols.schedule,
          fill: 1,
          size: 20,
          color: shift.clockOutAt == null
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text('$start – $end',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: shift.clockOutAt != null
            ? Text(DurationFormatter.hhmm(duration))
            : const Text('In progress'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Symbols.edit, size: 18),
              tooltip: 'Edit',
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => ShiftEditDialog(shift: shift),
              ),
            ),
            IconButton(
              icon: Icon(Symbols.delete,
                  size: 18, color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Shift'),
        content: const Text('Remove this shift? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(shiftRepositoryProvider).deleteShift(shift.id);
    }
  }
}
