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
    // profile — otherwise on relaunch we'd show the wrong profile and
    // wrongly attribute the running shift's time to it.
    final shift = await _ref.read(shiftRepositoryProvider).getActiveShift();
    final profileRepo = _ref.read(profileRepositoryProvider);
    Profile? p = shift != null
        ? await profileRepo.getById(shift.profileId)
        : await profileRepo.getDefaultProfile();
    // Self-heal: if no default is set (e.g. profiles were created from Settings
    // before any default existed), fall back to the first available profile so
    // the app is never stuck with a null active profile.
    if (p == null) {
      final all = await profileRepo.getActiveProfiles();
      if (all.isNotEmpty) {
        p = all.first;
        await profileRepo.setDefaultProfile(p.id);
      }
    }
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

final taskByIdProvider =
    FutureProvider.autoDispose.family<TaskWithType?, int>((ref, id) async {
  final all = await ref.watch(databaseProvider).taskDao.watchAllTasks().first;
  for (final t in all) {
    if (t.task.id == id) return t;
  }
  return null;
});
