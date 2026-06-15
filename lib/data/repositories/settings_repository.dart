import '../db/app_database.dart';
import '../../core/constants/app_constants.dart';

class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository(this._db);

  SettingsDao get _dao => _db.settingsDao;

  Future<String> getThemeMode() async =>
      (await _dao.get(SettingsKeys.themeMode)) ?? 'system';

  Future<void> setThemeMode(String mode) =>
      _dao.set(SettingsKeys.themeMode, mode);

  Stream<String?> watchThemeMode() => _dao.watch(SettingsKeys.themeMode);

  Future<bool> isAttendancePromptEnabled() async =>
      (await _dao.getBool(SettingsKeys.attendancePromptEnabled)) ?? true;

  Future<void> setAttendancePromptEnabled(bool v) =>
      _dao.set(SettingsKeys.attendancePromptEnabled, v.toString());

  Future<int> getAttendancePromptHour() async =>
      (await _dao.getInt(SettingsKeys.attendancePromptHour)) ??
      AppConstants.defaultAttendancePromptHour;

  Future<int> getAttendancePromptMinute() async =>
      (await _dao.getInt(SettingsKeys.attendancePromptMinute)) ??
      AppConstants.defaultAttendancePromptMinute;

  Future<void> setAttendancePromptTime(int hour, int minute) async {
    await _dao.set(SettingsKeys.attendancePromptHour, hour.toString());
    await _dao.set(SettingsKeys.attendancePromptMinute, minute.toString());
  }

  Future<int> getStillClockedInThreshold() async =>
      (await _dao.getInt(SettingsKeys.stillClockedInThresholdHours)) ??
      AppConstants.defaultStillClockedInThresholdHours;

  Future<void> setStillClockedInThreshold(int hours) =>
      _dao.set(SettingsKeys.stillClockedInThresholdHours, hours.toString());

  Future<bool> isGeofenceEnabled() async =>
      (await _dao.getBool(SettingsKeys.geofenceEnabled)) ?? false;

  Future<void> setGeofenceEnabled(bool v) =>
      _dao.set(SettingsKeys.geofenceEnabled, v.toString());

  Future<({double lat, double lng, double radius})?> getGeofence() async {
    final lat = await _dao.getDouble(SettingsKeys.geofenceLat);
    final lng = await _dao.getDouble(SettingsKeys.geofenceLng);
    final r = await _dao.getDouble(SettingsKeys.geofenceRadius) ??
        AppConstants.defaultGeofenceRadiusMeters;
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng, radius: r);
  }

  Future<void> setGeofence(double lat, double lng, double radius) async {
    await _dao.set(SettingsKeys.geofenceLat, lat.toString());
    await _dao.set(SettingsKeys.geofenceLng, lng.toString());
    await _dao.set(SettingsKeys.geofenceRadius, radius.toString());
  }

  Future<bool> showIdleNotification() async =>
      (await _dao.getBool(SettingsKeys.showIdleNotification)) ?? true;

  Future<void> setShowIdleNotification(bool v) =>
      _dao.set(SettingsKeys.showIdleNotification, v.toString());

  // Persistent (always-on) notification
  Future<bool> isPersistentNotificationEnabled() async =>
      (await _dao.getBool(SettingsKeys.persistentNotificationEnabled)) ?? false;

  Future<void> setPersistentNotificationEnabled(bool v) =>
      _dao.set(SettingsKeys.persistentNotificationEnabled, v.toString());

  // Off-day rules
  Stream<List<OffDayRule>> watchOffDayRules() => _dao.watchOffDayRules();

  Future<OffDayRule?> getGlobalOffDayRule() =>
      _dao.getOffDayRuleForProfile(null);

  Future<void> upsertOffDayRule(OffDayRulesCompanion r) =>
      _dao.upsertOffDayRule(r);

  // Holidays
  Stream<List<Holiday>> watchHolidays({int? profileId}) =>
      _dao.watchHolidays(profileId: profileId);

  Future<int> addHoliday(HolidaysCompanion h) => _dao.insertHoliday(h);
  Future<int> deleteHoliday(int id) => _dao.deleteHoliday(id);

  // NFC tags
  Stream<List<NfcTag>> watchNfcTags() => _dao.watchNfcTags();
  Future<NfcTag?> getTagByUid(String uid) => _dao.getTagByUid(uid);
  Future<int> addNfcTag(NfcTagsCompanion t) => _dao.insertNfcTag(t);
  Future<int> deleteNfcTag(int id) => _dao.deleteNfcTag(id);
}
