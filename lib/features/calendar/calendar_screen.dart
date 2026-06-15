import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/task_format.dart';
import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../notes/note_editor.dart';
import '../today/today_providers.dart';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

final _monthTasksProvider = StreamProvider.autoDispose
    .family<List<TaskWithType>, String>((ref, monthKey) {
  final first = _parseKey(monthKey);
  final last = DateTime(first.year, first.month + 1, 0);
  // Tasks across ALL profiles for the month (indicators show everything).
  return ref.watch(databaseProvider).taskDao.watchAllTasks().map((all) => all
      .where((t) =>
          !t.task.date.isBefore(first) &&
          !t.task.date.isAfter(DateTime(last.year, last.month, last.day)))
      .toList());
});

final _dayTasksProvider =
    StreamProvider.autoDispose.family<List<TaskWithType>, String>((ref, dateKey) {
  return ref
      .watch(databaseProvider)
      .taskDao
      .watchAllTasksForDateAllProfiles(_parseKey(dateKey));
});

final _allTasksProvider =
    StreamProvider.autoDispose<List<TaskWithType>>((ref) {
  return ref.watch(databaseProvider).taskDao.watchAllTasks();
});

final _taskTypesProvider = StreamProvider.autoDispose<List<TaskType>>((ref) {
  return ref.watch(databaseProvider).taskDao.watchAllTaskTypes();
});

final milestonesProvider = StreamProvider.autoDispose
    .family<List<TaskMilestone>, int>((ref, taskId) {
  return ref.watch(databaseProvider).taskDao.watchMilestones(taskId);
});

final _notesForTaskProvider =
    StreamProvider.autoDispose.family<List<Note>, int>((ref, taskId) {
  return ref.watch(databaseProvider).noteDao.watchNotesForTask(taskId);
});

final _taskLogsProvider =
    StreamProvider.autoDispose.family<List<TaskTimeLog>, int>((ref, taskId) {
  return ref.watch(databaseProvider).taskDao.watchLogsForTask(taskId);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calendar'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Month'), Tab(text: 'All Tasks')],
          ),
          actions: [
            IconButton(
              tooltip: 'Today',
              icon: const Icon(Symbols.today),
              onPressed: () {
                final now = DateTime.now();
                setState(() {
                  _month = DateTime(now.year, now.month, 1);
                  _selected = DateTime(now.year, now.month, now.day);
                });
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _MonthTab(
              month: _month,
              selected: _selected,
              onMonthChange: (m) => setState(() => _month = m),
              onSelect: (d) => setState(() => _selected = d),
            ),
            const _AllTasksTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_calendar',
          icon: const Icon(Symbols.add),
          label: const Text('Task'),
          onPressed: () => _addTask(context),
        ),
      ),
    );
  }

  Future<void> _addTask(BuildContext context) async {
    final activeProfile = ref.read(activeProfileNotifierProvider);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TaskFormSheet(
        date: _selected,
        initialProfileId: activeProfile?.id,
      ),
    );
  }
}

// ── Month tab ─────────────────────────────────────────────────────────────────

class _MonthTab extends ConsumerWidget {
  const _MonthTab({
    required this.month,
    required this.selected,
    required this.onMonthChange,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final void Function(DateTime) onMonthChange;
  final void Function(DateTime) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthTasks =
        ref.watch(_monthTasksProvider(_dateKey(month))).valueOrNull ?? [];
    final byDay = <String, List<TaskWithType>>{};
    for (final t in monthTasks) {
      byDay.putIfAbsent(_dateKey(t.task.date), () => []).add(t);
    }

    return Column(
      children: [
        _MonthHeader(
          month: month,
          onPrev: () =>
              onMonthChange(DateTime(month.year, month.month - 1, 1)),
          onNext: () =>
              onMonthChange(DateTime(month.year, month.month + 1, 1)),
        ),
        const _WeekdayRow(),
        _MonthGrid(
          month: month,
          selected: selected,
          tasksByDay: byDay,
          onTap: onSelect,
        ),
        const Divider(height: 1),
        Expanded(child: _DayTaskList(date: selected)),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(
      {required this.month, required this.onPrev, required this.onNext});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Symbols.chevron_left), onPressed: onPrev),
          Expanded(
            child: Text(DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
              icon: const Icon(Symbols.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.tasksByDay,
    required this.onTap,
  });

  final DateTime month;
  final DateTime selected;
  final Map<String, List<TaskWithType>> tasksByDay;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstWeekday = month.weekday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final cellCount = ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.8,
      ),
      itemCount: cellCount,
      itemBuilder: (ctx, i) {
        final dayNum = i - (firstWeekday - 2);
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, dayNum);
        final tasks = tasksByDay[_dateKey(date)] ?? const [];
        final isSelected = DateUtils.isSameDay(date, selected);
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final dotColors =
            tasks.take(3).map((t) => colorFromHex(t.taskType.colorHex)).toList();

        return GestureDetector(
          onTap: () => onTap(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isSelected
                  ? Border.all(color: cs.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$dayNum',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        )),
                const SizedBox(height: 3),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dotColors
                        .map((c) => Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                  color: c, shape: BoxShape.circle),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayTaskList extends ConsumerWidget {
  const _DayTaskList({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(_dayTasksProvider(_dateKey(date)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(DateFormat('EEEE, d MMMM').format(date),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
        ),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) return const _EmptyDay();
              final todo = tasks.where((t) => t.task.endAt == null).toList();
              final done = tasks.where((t) => t.task.endAt != null).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                children: [
                  ...todo.map((t) => _TaskTile(twt: t, date: date)),
                  if (done.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text('Completed (${done.length})',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                    ...done.map((t) =>
                        _TaskTile(twt: t, date: date, isDone: true)),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.event_available,
              size: 44, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Text('No tasks for this day',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── All Tasks tab ─────────────────────────────────────────────────────────────

class _AllTasksTab extends ConsumerStatefulWidget {
  const _AllTasksTab();

  @override
  ConsumerState<_AllTasksTab> createState() => _AllTasksTabState();
}

class _AllTasksTabState extends ConsumerState<_AllTasksTab> {
  TaskPriority? _priority;
  int? _profileId;
  // Done tasks are auto-archived: hidden by default, shown when this is on.
  bool _showArchived = false;
  int _sortByWeight = 0; // 0 = none, 1 = high→low

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(_allTasksProvider).valueOrNull ?? [];
    final profiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];

    var list = all.where((t) {
      final isDone = t.task.endAt != null;
      if (isDone != _showArchived) return false;
      if (_priority != null && t.task.priority != _priority) return false;
      if (_profileId != null && t.task.profileId != _profileId) return false;
      return true;
    }).toList();

    if (_sortByWeight == 1) {
      list.sort((a, b) => b.task.weight.compareTo(a.task.weight));
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Archived'),
                avatar: const Icon(Symbols.inventory_2, size: 16),
                selected: _showArchived,
                onSelected: (v) => setState(() => _showArchived = v),
              ),
              const SizedBox(width: 8),
              ...TaskPriority.values.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(priorityLabel(p)),
                      selected: _priority == p,
                      avatar: Icon(priorityIcon(p),
                          size: 16, color: priorityColor(p)),
                      onSelected: (v) =>
                          setState(() => _priority = v ? p : null),
                    ),
                  )),
              FilterChip(
                label: const Text('Weight ↓'),
                selected: _sortByWeight == 1,
                onSelected: (v) => setState(() => _sortByWeight = v ? 1 : 0),
              ),
              const SizedBox(width: 8),
              if (profiles.length > 1)
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
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text('No tasks match',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _TaskTile(
                    twt: list[i],
                    date: list[i].task.date,
                    showDate: true,
                    isDone: list[i].task.endAt != null,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Task tile (with inline checkable milestones) ──────────────────────────────

class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({
    required this.twt,
    required this.date,
    this.isDone = false,
    this.showDate = false,
  });

  final TaskWithType twt;
  final DateTime date;
  final bool isDone;
  final bool showDate;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.twt.task;
    final type = widget.twt.taskType;
    final typeColor = colorFromHex(type.colorHex);
    final isDone = widget.isDone;
    final milestones = ref.watch(milestonesProvider(task.id)).valueOrNull ?? [];
    final doneCount = milestones.where((m) => m.isDone).length;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Symbols.delete,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Delete "${task.title}"?'),
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
      ),
      onDismissed: (_) =>
          ref.read(databaseProvider).taskDao.deleteTask(task.id),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: isDone
            ? Theme.of(context).colorScheme.surfaceContainerLowest
            : Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              onTap: () => showTaskDetailDialog(context, widget.twt),
              leading: GestureDetector(
                onTap: () => _toggleDone(task),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isDone
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 2),
                    color: isDone ? typeColor : Colors.transparent,
                  ),
                  child: isDone
                      ? const Icon(Symbols.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              title: Text(task.title,
                  style: TextStyle(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                    fontWeight: FontWeight.w500,
                  )),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(context, color: typeColor, label: type.name),
                    _chip(context,
                        color: priorityColor(task.priority),
                        label: priorityLabel(task.priority),
                        icon: priorityIcon(task.priority)),
                    _chip(context,
                        color: Theme.of(context).colorScheme.primary,
                        label: 'w${task.weight}',
                        icon: Symbols.scale),
                    if (widget.showDate)
                      _chip(context,
                          color: Theme.of(context).colorScheme.outline,
                          label: DateFormat('d MMM').format(task.date),
                          icon: Symbols.event),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (milestones.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                                _expanded
                                    ? Symbols.expand_less
                                    : Symbols.checklist,
                                size: 18),
                            Text(' $doneCount/${milestones.length}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Symbols.edit, size: 18),
                    onPressed: () => _edit(context, milestones),
                  ),
                ],
              ),
            ),
            if (_expanded && milestones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
                child: Column(
                  children: milestones
                      .map((m) => InkWell(
                            onTap: () => ref
                                .read(databaseProvider)
                                .taskDao
                                .setMilestoneDone(m.id, !m.isDone),
                            child: Row(
                              children: [
                                Icon(
                                    m.isDone
                                        ? Symbols.check_box
                                        : Symbols.check_box_outline_blank,
                                    fill: m.isDone ? 1 : 0,
                                    size: 20,
                                    color: m.isDone
                                        ? typeColor
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(m.title,
                                        style: TextStyle(
                                            decoration: m.isDone
                                                ? TextDecoration.lineThrough
                                                : null)),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required Color color, required String label, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _toggleDone(Task task) async {
    final dao = ref.read(databaseProvider).taskDao;
    if (task.endAt == null) {
      await dao.updateTask(task.toCompanion(true).copyWith(
            startAt:
                task.startAt == null ? Value(task.createdAt) : Value(task.startAt!),
            endAt: Value(DateTime.now()),
          ));
    } else {
      await dao
          .updateTask(task.toCompanion(true).copyWith(endAt: const Value(null)));
    }
  }

  void _edit(BuildContext context, List<TaskMilestone> milestones) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TaskFormSheet(
        date: widget.date,
        initialProfileId: widget.twt.task.profileId,
        task: widget.twt,
        existingMilestones: milestones,
      ),
    );
  }
}

// ── Task detail dialog (with attached notes) ─────────────────────────────────

Future<void> showTaskDetailDialog(BuildContext context, TaskWithType twt) {
  return showDialog(
    context: context,
    builder: (_) => _TaskDetailDialog(twt: twt),
  );
}

class _TaskDetailDialog extends ConsumerWidget {
  const _TaskDetailDialog({required this.twt});

  final TaskWithType twt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = twt.task;
    final type = twt.taskType;
    final milestones = ref.watch(milestonesProvider(task.id)).valueOrNull ?? [];
    final notes = ref.watch(_notesForTaskProvider(task.id)).valueOrNull ?? [];
    final logs = ref.watch(_taskLogsProvider(task.id)).valueOrNull ?? [];
    final spent = TaskDao.totalLogged(logs);
    final done = task.endAt != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _detailChip(context, colorFromHex(type.colorHex), type.name),
                  _detailChip(context, priorityColor(task.priority),
                      priorityLabel(task.priority),
                      icon: priorityIcon(task.priority)),
                  _detailChip(context, Theme.of(context).colorScheme.primary,
                      'Weight ${task.weight}',
                      icon: Symbols.scale),
                  _detailChip(context, Theme.of(context).colorScheme.outline,
                      DateFormat('d MMM').format(task.date),
                      icon: Symbols.event),
                  if (spent.inMinutes > 0)
                    _detailChip(context, const Color(0xFF16A34A),
                        'Tracked ${_fmt(spent)}',
                        icon: Symbols.timer),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (milestones.isNotEmpty) ...[
                      Text('Milestones',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      ...milestones.map((m) => InkWell(
                            onTap: () => ref
                                .read(databaseProvider)
                                .taskDao
                                .setMilestoneDone(m.id, !m.isDone),
                            child: Row(
                              children: [
                                Icon(
                                    m.isDone
                                        ? Symbols.check_box
                                        : Symbols.check_box_outline_blank,
                                    fill: m.isDone ? 1 : 0,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(m.title,
                                        style: TextStyle(
                                            decoration: m.isDone
                                                ? TextDecoration.lineThrough
                                                : null)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Text('Notes',
                            style: Theme.of(context).textTheme.labelLarge),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Symbols.add, size: 16),
                          label: const Text('Add'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoteEditorScreen(
                                  initialProfileId: task.profileId,
                                  initialTaskId: task.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (notes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('No notes attached',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      )
                    else
                      ...notes.map((n) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(Symbols.sticky_note_2,
                                color: colorFromHex(n.colorHex)),
                            title: Text(
                              n.title.trim().isEmpty
                                  ? (n.body.trim().isEmpty
                                      ? 'Untitled'
                                      : n.body.trim())
                                  : n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => NoteEditorScreen(note: n)),
                              );
                            },
                          )),
                  ],
                ),
              ),
              const Divider(),
              Row(
                children: [
                  TextButton.icon(
                    icon: Icon(done ? Symbols.replay : Symbols.check, size: 18),
                    label: Text(done ? 'Reopen' : 'Mark done'),
                    onPressed: () {
                      final dao = ref.read(databaseProvider).taskDao;
                      if (done) {
                        dao.updateTask(task
                            .toCompanion(true)
                            .copyWith(endAt: const Value(null)));
                      } else {
                        dao.updateTask(task.toCompanion(true).copyWith(
                              startAt: task.startAt == null
                                  ? Value(task.createdAt)
                                  : Value(task.startAt!),
                              endAt: Value(DateTime.now()),
                            ));
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => TaskFormSheet(
                          date: task.date,
                          initialProfileId: task.profileId,
                          task: twt,
                          existingMilestones: milestones,
                        ),
                      );
                    },
                    child: const Text('Edit'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _detailChip(BuildContext context, Color color, String label,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Task form sheet ───────────────────────────────────────────────────────────

class _MilestoneDraft {
  final TextEditingController controller;
  bool isDone;
  _MilestoneDraft(String text, this.isDone)
      : controller = TextEditingController(text: text);
}

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({
    super.key,
    required this.date,
    this.initialProfileId,
    this.task,
    this.existingMilestones = const [],
  });

  final DateTime date;
  final int? initialProfileId;
  final TaskWithType? task;
  final List<TaskMilestone> existingMilestones;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _titleCtrl;
  late DateTime _date;
  int? _typeId;
  int? _profileId;
  TaskPriority _priority = TaskPriority.medium;
  int _weight = 1;
  late List<_MilestoneDraft> _milestones;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task?.task;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _typeId = t?.taskTypeId;
    _profileId = t?.profileId ?? widget.initialProfileId;
    _priority = t?.priority ?? TaskPriority.medium;
    _weight = t?.weight ?? 1;
    _date = t?.date ?? widget.date;
    _milestones = widget.existingMilestones
        .map((m) => _MilestoneDraft(m.title, m.isDone))
        .toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final m in _milestones) {
      m.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(_taskTypesProvider).valueOrNull ?? [];
    final profiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];
    if (_typeId == null && types.isNotEmpty) _typeId = types.first.id;
    _profileId ??= profiles.isNotEmpty ? profiles.first.id : null;
    final isEdit = widget.task != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Edit Task' : 'New Task',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            _label(context, 'Date'),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Symbols.event,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (profiles.length > 1) ...[
              _label(context, 'Profile'),
              Wrap(
                spacing: 8,
                children: profiles
                    .map((p) => ChoiceChip(
                          label: Text(p.name),
                          selected: _profileId == p.id,
                          avatar: CircleAvatar(
                              backgroundColor: colorFromHex(p.colorHex),
                              radius: 7),
                          onSelected: (_) => setState(() => _profileId = p.id),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            _label(context, 'Type'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: types.map((t) {
                final c = colorFromHex(t.colorHex);
                return ChoiceChip(
                  label: Text(t.name),
                  selected: t.id == _typeId,
                  avatar: CircleAvatar(backgroundColor: c, radius: 6),
                  selectedColor: c.withValues(alpha: 0.22),
                  onSelected: (_) => setState(() => _typeId = t.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _label(context, 'Priority'),
            Wrap(
              spacing: 8,
              children: TaskPriority.values.map((p) {
                return ChoiceChip(
                  label: Text(priorityLabel(p)),
                  selected: _priority == p,
                  avatar: Icon(priorityIcon(p),
                      size: 16, color: priorityColor(p)),
                  selectedColor: priorityColor(p).withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _priority = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _label(context, 'Weight'),
            Row(
              children: List.generate(5, (i) {
                final v = i + 1;
                final selected = _weight == v;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$v'),
                    selected: selected,
                    onSelected: (_) => setState(() => _weight = v),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _label(context, 'Milestones'),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Symbols.add, size: 18),
                  label: const Text('Add'),
                  onPressed: () =>
                      setState(() => _milestones.add(_MilestoneDraft('', false))),
                ),
              ],
            ),
            ..._milestones.asMap().entries.map((e) {
              final m = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          m.isDone
                              ? Symbols.check_box
                              : Symbols.check_box_outline_blank,
                          fill: m.isDone ? 1 : 0),
                      onPressed: () => setState(() => m.isDone = !m.isDone),
                    ),
                    Expanded(
                      child: TextField(
                        controller: m.controller,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Milestone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close, size: 18),
                      onPressed: () => setState(() {
                        m.controller.dispose();
                        _milestones.removeAt(e.key);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title cannot be empty')));
      return;
    }
    if (_typeId == null) return;
    setState(() => _saving = true);
    try {
      final dao = ref.read(databaseProvider).taskDao;
      int taskId;
      if (widget.task == null) {
        taskId = await dao.insertTask(TasksCompanion.insert(
          profileId: Value(_profileId),
          date: _date,
          taskTypeId: _typeId!,
          title: title,
          weight: Value(_weight),
          priority: Value(_priority),
        ));
      } else {
        taskId = widget.task!.task.id;
        await dao.updateTask(widget.task!.task.toCompanion(true).copyWith(
              title: Value(title),
              date: Value(_date),
              taskTypeId: Value(_typeId!),
              profileId: Value(_profileId),
              weight: Value(_weight),
              priority: Value(_priority),
            ));
      }
      // Sync milestones: replace-all strategy (lists are small).
      for (final m in widget.existingMilestones) {
        await dao.deleteMilestone(m.id);
      }
      for (var i = 0; i < _milestones.length; i++) {
        final text = _milestones[i].controller.text.trim();
        if (text.isEmpty) continue;
        await dao.insertMilestone(TaskMilestonesCompanion.insert(
          taskId: taskId,
          title: text,
          isDone: Value(_milestones[i].isDone),
          sortOrder: Value(i),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
