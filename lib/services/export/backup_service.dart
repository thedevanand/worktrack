import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';

/// Full app-data backup & restore as a single JSON file.
///
/// Captures every table so a user can move data across installs / devices and
/// survive an uninstall. Restore replaces ALL current data with the backup.
class BackupService {
  BackupService._();

  static const _magic = 'alootrack-backup';

  // ── Export ────────────────────────────────────────────────────────────────

  static Future<void> exportBackup(AppDatabase db) async {
    final data = <String, dynamic>{
      'app': _magic,
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'profiles': await _dump(db.select(db.profiles)),
        'taskTypes': await _dump(db.select(db.taskTypes)),
        'appSettings': await _dump(db.select(db.appSettings)),
        'offDayRules': await _dump(db.select(db.offDayRules)),
        'holidays': await _dump(db.select(db.holidays)),
        'workDays': await _dump(db.select(db.workDays)),
        'shifts': await _dump(db.select(db.shifts)),
        'breaks': await _dump(db.select(db.breaks)),
        'tasks': await _dump(db.select(db.tasks)),
        'taskMilestones': await _dump(db.select(db.taskMilestones)),
        'taskTimeLogs': await _dump(db.select(db.taskTimeLogs)),
        'notes': await _dump(db.select(db.notes)),
        'nfcTags': await _dump(db.select(db.nfcTags)),
      },
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final file = File('${dir.path}/alootrack_backup_$stamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'AlooTrack Backup',
    );
  }

  static Future<List<Map<String, dynamic>>> _dump(
          Selectable<dynamic> query) async =>
      (await query.get()).map((row) => row.toJson() as Map<String, dynamic>).toList();

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Replaces all data with the backup at [path]. Throws on an invalid file.
  static Future<void> importBackup(AppDatabase db, String path) async {
    final raw = await File(path).readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['app'] != _magic || map['tables'] is! Map) {
      throw const FormatException('Not a valid AlooTrack backup file.');
    }
    final t = map['tables'] as Map<String, dynamic>;

    List<Map<String, dynamic>> rows(String key) =>
        ((t[key] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();

    await db.transaction(() async {
      // Defer FK checks to commit so delete/insert order can't trip them up.
      await db.customStatement('PRAGMA defer_foreign_keys = ON');

      // Wipe everything (children first).
      await db.delete(db.taskTimeLogs).go();
      await db.delete(db.notes).go();
      await db.delete(db.taskMilestones).go();
      await db.delete(db.tasks).go();
      await db.delete(db.breaks).go();
      await db.delete(db.shifts).go();
      await db.delete(db.workDays).go();
      await db.delete(db.holidays).go();
      await db.delete(db.offDayRules).go();
      await db.delete(db.nfcTags).go();
      await db.delete(db.appSettings).go();
      await db.delete(db.taskTypes).go();
      await db.delete(db.profiles).go();

      // Restore (parents first).
      for (final r in rows('profiles')) {
        await db.into(db.profiles).insert(Profile.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('taskTypes')) {
        await db.into(db.taskTypes).insert(TaskType.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('appSettings')) {
        await db.into(db.appSettings).insert(AppSetting.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('offDayRules')) {
        await db.into(db.offDayRules).insert(OffDayRule.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('holidays')) {
        await db.into(db.holidays).insert(Holiday.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('workDays')) {
        await db.into(db.workDays).insert(WorkDay.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('shifts')) {
        await db.into(db.shifts).insert(Shift.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('breaks')) {
        await db.into(db.breaks).insert(Break.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('tasks')) {
        await db.into(db.tasks).insert(Task.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('taskMilestones')) {
        await db.into(db.taskMilestones).insert(TaskMilestone.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('taskTimeLogs')) {
        await db.into(db.taskTimeLogs).insert(TaskTimeLog.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('notes')) {
        await db.into(db.notes).insert(Note.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
      for (final r in rows('nfcTags')) {
        await db.into(db.nfcTags).insert(NfcTag.fromJson(r),
            mode: InsertMode.insertOrReplace);
      }
    });
  }
}
