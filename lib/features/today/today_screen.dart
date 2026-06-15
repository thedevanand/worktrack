import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/shift_repository.dart';
import '../../services/notifications/notification_core.dart';
import '../../services/widget/home_widget_service.dart';
import '../profiles/profiles_screen.dart';
import 'today_providers.dart';

// ── Day type helpers (shared) ────────────────────────────────────────────────

String dayTypeLabel(DayType t) => switch (t) {
      DayType.fullDay => 'Full Day',
      DayType.wfh => 'WFH',
      DayType.halfDay => 'Half Day',
      DayType.leave => 'Leave',
      DayType.officialOff => 'Official Off',
      DayType.weeklyOff => 'Weekly Off',
    };

IconData dayTypeIcon(DayType t) => switch (t) {
      DayType.fullDay => Symbols.work,
      DayType.wfh => Symbols.house,
      DayType.halfDay => Symbols.timelapse,
      DayType.leave => Symbols.beach_access,
      DayType.officialOff => Symbols.flag,
      DayType.weeklyOff => Symbols.weekend,
    };

bool isOffDayType(DayType t) =>
    t == DayType.leave || t == DayType.officialOff || t == DayType.weeklyOff;

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _syncOutputs() async {
    final db = ref.read(databaseProvider);
    await ShiftNotification.refresh(db);
    await HomeWidgetService.refresh(db);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileNotifierProvider);
    final activeShift = ref.watch(activeShiftProvider).valueOrNull;
    final activeBreak = ref.watch(activeBreakProvider).valueOrNull;
    final todayShifts = ref.watch(todayShiftsProvider).valueOrNull ?? [];
    final workDay = ref.watch(todayWorkDayProvider).valueOrNull;
    final dayType = workDay?.dayType ?? DayType.fullDay;
    final isOffDay = isOffDayType(dayType);

    final profileColor =
        profile != null ? colorFromHex(profile.colorHex) : Colors.blue;

    Duration elapsed = Duration.zero;
    bool isPaused = false;
    if (activeShift != null) {
      isPaused = activeBreak != null;
      final breakList = activeBreak != null ? [activeBreak] : <Break>[];
      elapsed = ShiftRepository.netDuration(activeShift, breakList);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, d MMM').format(_now)),
        centerTitle: false,
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: profileColor,
                  radius: 10,
                  child: profileIconWidget(profile.iconName, size: 11),
                ),
                label: Text(profile.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () => _showProfilePicker(context),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _TimerCard(
            elapsed: elapsed,
            isPaused: isPaused,
            isActive: activeShift != null,
            profileColor: profileColor,
            now: _now,
          ),
          const SizedBox(height: 12),
          if (profile != null && !isOffDay)
            _ProfileProgressCard(
              profile: profile,
              todayShifts: todayShifts,
              activeShift: activeShift,
              activeBreak: activeBreak,
              now: _now,
              dayType: dayType,
            ),
          const SizedBox(height: 12),
          if (profile != null) _DayTypeSelector(profile: profile, current: dayType),
          const SizedBox(height: 16),
          if (activeShift == null)
            isOffDay
                ? _DayOffCard(
                    dayType: dayType,
                    profileColor: profileColor,
                    profile: profile,
                    onClockIn: () => _clockIn(profile),
                  )
                : _ClockInButton(
                    profile: profile,
                    profileColor: profileColor,
                    onClockIn: () => _clockIn(profile),
                  )
          else
            _ActiveShiftButtons(
              shift: activeShift,
              isPaused: isPaused,
              onClockOut: () => _clockOut(activeShift),
              onPauseResume: () =>
                  isPaused ? _resume(activeShift) : _pause(activeShift),
            ),
          if (activeShift != null && profile != null) ...[
            const SizedBox(height: 12),
            _CurrentTaskCard(
              profile: profile,
              shift: activeShift,
              now: _now,
              onChanged: _syncOutputs,
            ),
          ],
          const SizedBox(height: 24),
          if (todayShifts.isNotEmpty) ...[
            Text(
              "Today's Shifts",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...todayShifts.map((s) => _ShiftTile(shift: s)),
          ],
        ],
      ),
    );
  }

  Future<void> _clockIn(Profile? profile) async {
    if (profile == null) return;
    final repo = ref.read(shiftRepositoryProvider);
    await repo.clockIn(profileId: profile.id, at: DateTime.now());
    await _syncOutputs();
  }

  Future<void> _clockOut(Shift shift) async {
    final repo = ref.read(shiftRepositoryProvider);
    await repo.clockOut(shift: shift);
    await ref.read(databaseProvider).taskDao.closeOpenLogs();
    await _syncOutputs();
  }

  Future<void> _pause(Shift shift) async {
    await ref.read(shiftRepositoryProvider).pauseShift(shift);
    await _syncOutputs();
  }

  Future<void> _resume(Shift shift) async {
    await ref.read(shiftRepositoryProvider).resumeShift(shift);
    await _syncOutputs();
  }

  void _showProfilePicker(BuildContext context) {
    final profiles = ref.read(activeProfilesProvider).valueOrNull ?? [];
    final activeShift = ref.read(activeShiftProvider).valueOrNull;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProfilePickerSheet(
        profiles: profiles,
        onSelect: (p) => _selectProfile(context, p, activeShift),
      ),
    );
  }

  Future<void> _selectProfile(
      BuildContext context, Profile newProfile, Shift? activeShift) async {
    final current = ref.read(activeProfileNotifierProvider);
    if (current?.id == newProfile.id) return;

    if (activeShift != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Switch Profile?'),
          content: Text(
            'This will clock out "${current?.name}" and clock in "${newProfile.name}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final repo = ref.read(shiftRepositoryProvider);
      await repo.switchProfile(newProfile.id);
      await ref.read(databaseProvider).taskDao.closeOpenLogs();
      await _syncOutputs();
    }

    ref.read(activeProfileNotifierProvider.notifier).set(newProfile);
  }
}

// ── Current task tracker (shown while clocked in) ─────────────────────────────

class _CurrentTaskCard extends ConsumerWidget {
  const _CurrentTaskCard({
    required this.profile,
    required this.shift,
    required this.now,
    required this.onChanged,
  });

  final Profile profile;
  final Shift shift;
  final DateTime now;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final log = ref.watch(openTaskLogProvider).valueOrNull;
    final task = log != null
        ? ref.watch(taskByIdProvider(log.taskId)).valueOrNull
        : null;

    final elapsed = log != null ? now.difference(log.startAt) : Duration.zero;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Symbols.timer, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Working on',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      task?.task.title ?? 'No task — tap to choose',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (log != null) ...[
                Text(DurationFormatter.hhmmss(elapsed),
                    style: TextStyle(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: cs.primary,
                        fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: 'Stop tracking task',
                  icon: const Icon(Symbols.stop_circle, size: 20),
                  onPressed: () async {
                    await ref
                        .read(databaseProvider)
                        .taskDao
                        .switchActiveTask(null);
                    await onChanged();
                  },
                ),
              ] else
                Icon(Symbols.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final tasks = ref.read(pickableTasksProvider(profile.id)).valueOrNull ?? [];
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: tasks.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No open tasks for this profile. Add tasks in the '
                    'Calendar tab.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('What are you working on?',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ...tasks.map((t) => ListTile(
                        leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: colorFromHex(t.taskType.colorHex)),
                        title: Text(t.task.title),
                        subtitle: Text(t.taskType.name),
                        onTap: () => Navigator.pop(context, t.task.id),
                      )),
                ],
              ),
      ),
    );
    if (selected != null) {
      await ref
          .read(databaseProvider)
          .taskDao
          .switchActiveTask(selected, shiftId: shift.id);
      await onChanged();
    }
  }
}

// ── Timer card ───────────────────────────────────────────────────────────────

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.elapsed,
    required this.isPaused,
    required this.isActive,
    required this.profileColor,
    required this.now,
  });

  final Duration elapsed;
  final bool isPaused;
  final bool isActive;
  final Color profileColor;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String timerText;
    String label;
    Color bgColor;

    if (!isActive) {
      timerText = DateFormat('HH:mm').format(now);
      label = 'Tap Clock In to start';
      bgColor = cs.surfaceContainerLow;
    } else if (isPaused) {
      timerText = DurationFormatter.hhmmss(elapsed);
      label = 'Paused';
      bgColor = cs.tertiaryContainer;
    } else {
      timerText = DurationFormatter.hhmmss(elapsed);
      label = 'Net worked';
      bgColor = profileColor.withValues(alpha: 0.12);
    }

    return Card(
      color: bgColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Text(
              timerText,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w300,
                    color: isActive && !isPaused ? profileColor : cs.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

// ── Profile progress card ─────────────────────────────────────────────────────

class _ProfileProgressCard extends StatelessWidget {
  const _ProfileProgressCard({
    required this.profile,
    required this.todayShifts,
    required this.activeShift,
    required this.activeBreak,
    required this.now,
    required this.dayType,
  });

  final Profile profile;
  final List<Shift> todayShifts;
  final Shift? activeShift;
  final Break? activeBreak;
  final DateTime now;
  final DayType dayType;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(profile.colorHex);
    final rawTarget = profile.targetDailyMinutes;
    final effectiveMinutes =
        dayType == DayType.halfDay ? rawTarget ~/ 2 : rawTarget;
    final target = Duration(minutes: effectiveMinutes);

    Duration total = Duration.zero;
    for (final s in todayShifts) {
      final breakList = (s.id == activeShift?.id && activeBreak != null)
          ? [activeBreak!]
          : <Break>[];
      total += ShiftRepository.netDuration(s, breakList);
    }

    final progress = target.inSeconds > 0
        ? (total.inSeconds / target.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 14,
                child: profileIconWidget(profile.iconName, size: 15),
              ),
              const SizedBox(width: 10),
              Text(profile.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${DurationFormatter.hhmm(total)} / ${DurationFormatter.hhmm(target)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day type selector (bottom-sheet based, no jumpy dropdown) ─────────────────

class _DayTypeSelector extends ConsumerWidget {
  const _DayTypeSelector({required this.profile, required this.current});

  final Profile profile;
  final DayType current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(dayTypeIcon(current), size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Text('Day type', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(dayTypeLabel(current),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(width: 4),
            Icon(Symbols.expand_more, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<DayType>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in DayType.values)
              ListTile(
                leading: Icon(dayTypeIcon(t),
                    color: t == current
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                title: Text(dayTypeLabel(t)),
                trailing: t == current
                    ? Icon(Symbols.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != current) {
      await ref
          .read(shiftRepositoryProvider)
          .setDayType(profile.id, DateTime.now(), selected, '');
    }
  }
}

// ── Clock In button ───────────────────────────────────────────────────────────

class _ClockInButton extends StatelessWidget {
  const _ClockInButton({
    required this.profile,
    required this.profileColor,
    required this.onClockIn,
  });

  final Profile? profile;
  final Color profileColor;
  final VoidCallback onClockIn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: profileColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Symbols.play_arrow, fill: 1, size: 26),
        label: const Text('CLOCK IN',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        onPressed: profile != null ? onClockIn : null,
      ),
    );
  }
}

// ── Clock Out + Pause/Resume ──────────────────────────────────────────────────

class _ActiveShiftButtons extends StatelessWidget {
  const _ActiveShiftButtons({
    required this.shift,
    required this.isPaused,
    required this.onClockOut,
    required this.onPauseResume,
  });

  final Shift shift;
  final bool isPaused;
  final VoidCallback onClockOut;
  final VoidCallback onPauseResume;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Symbols.stop_circle, fill: 1, size: 24),
              label: const Text('CLOCK OUT',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              onPressed: onClockOut,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(isPaused ? Symbols.play_arrow : Symbols.pause,
                  fill: 1, size: 20),
              label: Text(isPaused ? 'RESUME' : 'PAUSE',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              onPressed: onPauseResume,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shift tile ────────────────────────────────────────────────────────────────

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final start = formatTime(shift.clockInAt);
    final end = shift.clockOutAt != null ? formatTime(shift.clockOutAt!) : '...';
    final duration = ShiftRepository.netDuration(shift, []);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: Icon(
          shift.clockOutAt == null
              ? Symbols.radio_button_checked
              : Symbols.check_circle,
          fill: 1,
          color: shift.clockOutAt == null
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          size: 22,
        ),
        title: Text('$start – $end',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(DurationFormatter.hhmm(duration),
            style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

// ── Day-off card ──────────────────────────────────────────────────────────────

class _DayOffCard extends StatelessWidget {
  const _DayOffCard({
    required this.dayType,
    required this.profileColor,
    required this.profile,
    required this.onClockIn,
  });

  final DayType dayType;
  final Color profileColor;
  final Profile? profile;
  final VoidCallback onClockIn;

  String get _label => switch (dayType) {
        DayType.leave => 'On Leave',
        DayType.officialOff => 'Official Holiday',
        DayType.weeklyOff => 'Weekly Off',
        _ => 'Day Off',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(dayTypeIcon(dayType),
                    size: 30, fill: 1, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Time tracking optional today',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Symbols.play_arrow, size: 16),
          label: const Text('Clock in anyway'),
          style: TextButton.styleFrom(
              foregroundColor: profileColor.withValues(alpha: 0.85)),
          onPressed: profile != null ? onClockIn : null,
        ),
      ],
    );
  }
}

// ── Profile picker sheet ──────────────────────────────────────────────────────

class _ProfilePickerSheet extends StatelessWidget {
  const _ProfilePickerSheet({required this.profiles, required this.onSelect});

  final List<Profile> profiles;
  final void Function(Profile) onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Switch Profile',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...profiles.map((p) {
            final color = colorFromHex(p.colorHex);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: profileIconWidget(p.iconName, size: 16),
              ),
              title: Text(p.name),
              onTap: () {
                Navigator.pop(context);
                onSelect(p);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
