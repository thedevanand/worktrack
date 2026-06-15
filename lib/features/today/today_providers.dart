import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// ── Active profile for the session ────────────────────────────────────────

class ActiveProfileNotifier extends StateNotifier<Profile?> {
  ActiveProfileNotifier(this._ref) : super(null) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    // If a shift is currently running, the active profile MUST be that shift's
    // profile — otherwise on relaunch we'd show the default profile (DAPS) and
    // wrongly attribute the running shift's time to it.
    final shift = await _ref.read(shiftRepositoryProvider).getActiveShift();
    final profileRepo = _ref.read(profileRepositoryProvider);
    final p = shift != null
        ? await profileRepo.getById(shift.profileId)
        : await profileRepo.getDefaultProfile();
    if (mounted) state = p;
  }

  void set(Profile profile) => state = profile;
}

final activeProfileNotifierProvider =
    StateNotifierProvider<ActiveProfileNotifier, Profile?>((ref) {
  return ActiveProfileNotifier(ref);
});

// ── Today's shifts for the active profile ─────────────────────────────────

final todayShiftsProvider = StreamProvider.autoDispose<List<Shift>>((ref) {
  final profile = ref.watch(activeProfileNotifierProvider);
  if (profile == null) return const Stream.empty();
  return ref
      .watch(shiftRepositoryProvider)
      .watchShiftsForDate(profile.id, DateTime.now());
});

// ── Work day record for today ──────────────────────────────────────────────

final todayWorkDayProvider = StreamProvider.autoDispose<WorkDay?>((ref) {
  final profile = ref.watch(activeProfileNotifierProvider);
  if (profile == null) return const Stream.empty();
  return ref
      .watch(shiftRepositoryProvider)
      .watchWorkDay(profile.id, DateTime.now());
});

// ── Active break (exists only when shift is paused) ───────────────────────

final activeBreakProvider = StreamProvider.autoDispose<Break?>((ref) {
  final shift = ref.watch(activeShiftProvider).valueOrNull;
  if (shift == null) return const Stream.empty();
  return ref.watch(shiftRepositoryProvider).watchActiveBreak(shift.id);
});

// ── Current task being worked on (open time log) ───────────────────────────

final openTaskLogProvider = StreamProvider.autoDispose<TaskTimeLog?>((ref) {
  return ref.watch(databaseProvider).taskDao.watchOpenLog();
});

/// Not-done tasks for a profile (today first, then other dates) — for the
/// "what are you working on" picker.
final pickableTasksProvider =
    StreamProvider.autoDispose.family<List<TaskWithType>, int>((ref, profileId) {
  return ref.watch(databaseProvider).taskDao.watchAllTasks().map((all) => all
      .where((t) => t.task.endAt == null && t.task.profileId == profileId)
      .toList());
});

final taskByIdProvider =
    FutureProvider.autoDispose.family<TaskWithType?, int>((ref, id) async {
  final all = await ref.watch(databaseProvider).taskDao.watchAllTasks().first;
  for (final t in all) {
    if (t.task.id == id) return t;
  }
  return null;
});
