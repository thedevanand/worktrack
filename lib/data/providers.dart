import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'repositories/profile_repository.dart';
import 'repositories/shift_repository.dart';
import 'repositories/settings_repository.dart';

// ── Database ───────────────────────────────────────────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Repositories ───────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(databaseProvider));
});

// ── Common streams ─────────────────────────────────────────────────────────

final activeProfilesProvider = StreamProvider<List<Profile>>((ref) {
  return ref.watch(profileRepositoryProvider).watchActiveProfiles();
});

final defaultProfileProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchDefaultProfile();
});

final activeShiftProvider = StreamProvider<Shift?>((ref) {
  return ref.watch(shiftRepositoryProvider).watchActiveShift();
});

final themeModeProvider = StreamProvider<String?>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchThemeMode();
});
