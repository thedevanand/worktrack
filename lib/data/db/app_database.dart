import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// TODO: Replace sqlite3_flutter_libs with sqlcipher_flutter_libs for SQLCipher
//       encryption once the plugin's compileSdk issue is resolved upstream.
//       Android FBE (on by default since API 24) provides at-rest protection
//       for the device's app data directory in the interim.

import 'tables.dart';
import 'daos/profile_dao.dart';
import 'daos/shift_dao.dart';
import 'daos/task_dao.dart';
import 'daos/note_dao.dart';
import 'daos/settings_dao.dart';

export 'tables.dart';
export 'daos/profile_dao.dart';
export 'daos/shift_dao.dart';
export 'daos/task_dao.dart';
export 'daos/note_dao.dart';
export 'daos/settings_dao.dart';

part 'app_database.g.dart';


@DriftDatabase(
  tables: [
    Profiles,
    WorkDays,
    Shifts,
    Breaks,
    TaskTypes,
    Tasks,
    TaskMilestones,
    TaskTimeLogs,
    Notes,
    OffDayRules,
    Holidays,
    AppSettings,
    NfcTags,
  ],
  daos: [ProfileDao, ShiftDao, TaskDao, NoteDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedData();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.weight);
            await m.addColumn(tasks, tasks.priority);
            await m.createTable(taskMilestones);
            await m.createTable(notes);
          }
          if (from < 3) {
            await m.createTable(taskTimeLogs);
          }
        },
      );

  Future<void> _seedData() async {
    // No profiles are seeded — the onboarding flow creates the first profile
    // on first launch (an empty profile table == first run).

    // Seed task types
    for (final c in _seedTaskTypes) {
      await into(taskTypes).insert(c);
    }

    // Default settings
    final settingsDao = SettingsDao(this);
    await settingsDao.set(SettingsKeys.dayStartHour, '9');
    await settingsDao.set(SettingsKeys.dayStartMinute, '0');
    await settingsDao.set(SettingsKeys.dayEndHour, '18');
    await settingsDao.set(SettingsKeys.dayEndMinute, '0');
    await settingsDao.set(SettingsKeys.attendancePromptHour, '9');
    await settingsDao.set(SettingsKeys.attendancePromptMinute, '30');
    await settingsDao.set(SettingsKeys.stillClockedInThresholdHours, '10');
    await settingsDao.set(SettingsKeys.geofenceEnabled, 'false');
    await settingsDao.set(SettingsKeys.attendancePromptEnabled, 'true');
    await settingsDao.set(SettingsKeys.showIdleNotification, 'true');
    await settingsDao.set(SettingsKeys.themeMode, 'system');
    await settingsDao.set(SettingsKeys.homeWidgetEnabled, 'false');
    await settingsDao.set(SettingsKeys.persistentNotificationEnabled, 'false');

    // Global off-day rule: Sunday off
    await into(offDayRules).insert(
      const OffDayRulesCompanion(
        weeklyOffMask: Value(64), // bit 6 = Sunday
      ),
    );
  }

  static final _seedTaskTypes = [
    const TaskTypesCompanion(
      name: Value('Meeting/Discussion'),
      colorHex: Value('#F59E0B'),
    ),
    const TaskTypesCompanion(
      name: Value('Programming'),
      colorHex: Value('#6366F1'),
    ),
    const TaskTypesCompanion(
      name: Value('Other'),
      colorHex: Value('#6B7280'),
    ),
  ];
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'worktrack.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
    );
  });
}
