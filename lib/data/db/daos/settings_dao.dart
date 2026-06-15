import 'package:drift/drift.dart';
import '../app_database.dart';

part 'settings_dao.g.dart';

// Well-known settings keys
class SettingsKeys {
  SettingsKeys._();
  static const defaultProfileId = 'default_profile_id';
  static const dayStartHour = 'day_start_hour';
  static const dayStartMinute = 'day_start_minute';
  static const dayEndHour = 'day_end_hour';
  static const dayEndMinute = 'day_end_minute';
  static const attendancePromptHour = 'attendance_prompt_hour';
  static const attendancePromptMinute = 'attendance_prompt_minute';
  static const stillClockedInThresholdHours = 'still_clocked_in_hours';
  static const geofenceLat = 'geofence_lat';
  static const geofenceLng = 'geofence_lng';
  static const geofenceRadius = 'geofence_radius';
  static const geofenceEnabled = 'geofence_enabled';
  static const attendancePromptEnabled = 'attendance_prompt_enabled';
  static const showIdleNotification = 'show_idle_notification';
  static const themeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const homeWidgetEnabled = 'home_widget_enabled';
  static const persistentNotificationEnabled = 'persistent_notification_enabled';
}

@DriftAccessor(tables: [AppSettings, OffDayRules, Holidays, NfcTags])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) => into(appSettings)
      .insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  Future<int?> getInt(String key) async {
    final v = await get(key);
    return v == null ? null : int.tryParse(v);
  }

  Future<double?> getDouble(String key) async {
    final v = await get(key);
    return v == null ? null : double.tryParse(v);
  }

  Future<bool?> getBool(String key) async {
    final v = await get(key);
    return v == null ? null : v == 'true';
  }

  Stream<String?> watch(String key) {
    return (select(appSettings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((r) => r?.value);
  }

  // ── Off-day rules ──────────────────────────────────────────────────────────

  Stream<List<OffDayRule>> watchOffDayRules() =>
      select(offDayRules).watch();

  Future<OffDayRule?> getOffDayRuleForProfile(int? profileId) async {
    if (profileId == null) {
      return (select(offDayRules)
            ..where((r) => r.profileId.isNull()))
          .getSingleOrNull();
    }
    return (select(offDayRules)
          ..where((r) => r.profileId.equals(profileId)))
        .getSingleOrNull();
  }

  Future<int> upsertOffDayRule(OffDayRulesCompanion entry) =>
      into(offDayRules).insertOnConflictUpdate(entry);

  // ── Holidays ───────────────────────────────────────────────────────────────

  Stream<List<Holiday>> watchHolidays({int? profileId}) {
    return (select(holidays)
          ..where((h) => profileId == null
              ? h.profileId.isNull() | const Constant(true)
              : h.profileId.isNull() | h.profileId.equals(profileId))
          ..orderBy([(h) => OrderingTerm.asc(h.date)]))
        .watch();
  }

  Future<int> insertHoliday(HolidaysCompanion entry) =>
      into(holidays).insert(entry);

  Future<int> deleteHoliday(int id) =>
      (delete(holidays)..where((h) => h.id.equals(id))).go();

  // ── NFC tags ───────────────────────────────────────────────────────────────

  Stream<List<NfcTag>> watchNfcTags() => select(nfcTags).watch();

  Future<NfcTag?> getTagByUid(String uid) =>
      (select(nfcTags)..where((t) => t.tagUid.equals(uid)))
          .getSingleOrNull();

  Future<int> insertNfcTag(NfcTagsCompanion entry) =>
      into(nfcTags).insert(entry);

  Future<int> deleteNfcTag(int id) =>
      (delete(nfcTags)..where((t) => t.id.equals(id))).go();
}
