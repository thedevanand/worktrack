import 'package:drift/drift.dart';
import '../db/app_database.dart';

class ProfileRepository {
  final AppDatabase _db;

  ProfileRepository(this._db);

  ProfileDao get _dao => _db.profileDao;
  SettingsDao get _settings => _db.settingsDao;

  Stream<List<Profile>> watchActiveProfiles() =>
      _dao.watchAll(includeArchived: false);

  Future<List<Profile>> getActiveProfiles() =>
      _dao.getAll(includeArchived: false);

  Future<Profile?> getById(int id) => _dao.getById(id);

  Future<Profile?> getDefaultProfile() async {
    final idStr =
        await _settings.get(SettingsKeys.defaultProfileId);
    if (idStr == null) return null;
    final id = int.tryParse(idStr);
    if (id == null) return null;
    return _dao.getById(id);
  }

  Stream<Profile?> watchDefaultProfile() {
    return _settings.watch(SettingsKeys.defaultProfileId).asyncMap((idStr) {
      final id = int.tryParse(idStr ?? '');
      if (id == null) return Future.value(null);
      return _dao.getById(id);
    });
  }

  Future<void> setDefaultProfile(int profileId) =>
      _settings.set(SettingsKeys.defaultProfileId, profileId.toString());

  Future<int> createProfile({
    required String name,
    required String colorHex,
    required String iconName,
    int targetDailyMinutes = 480,
    int targetWeeklyMinutes = 2400,
  }) async {
    final id = await _dao.insert(ProfilesCompanion.insert(
      name: name,
      colorHex: Value(colorHex),
      iconName: Value(iconName),
      targetDailyMinutes: Value(targetDailyMinutes),
      targetWeeklyMinutes: Value(targetWeeklyMinutes),
    ));
    // Ensure there's always a valid default profile (e.g. profiles created
    // from Settings before any default was set).
    final existing = await _settings.get(SettingsKeys.defaultProfileId);
    if (existing == null || int.tryParse(existing) == null) {
      await setDefaultProfile(id);
    }
    return id;
  }

  Future<void> updateProfile(Profile profile) =>
      _dao.updateProfile(profile.toCompanion(true));

  Future<void> archiveProfile(int id) => _dao.archive(id);

  Future<void> deleteProfile(int id) => _dao.deleteById(id);
}
