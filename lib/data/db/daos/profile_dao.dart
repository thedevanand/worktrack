import 'package:drift/drift.dart';
import '../app_database.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Stream<List<Profile>> watchAll({bool includeArchived = false}) {
    return (select(profiles)
          ..where((p) => includeArchived
              ? const Constant(true)
              : p.isArchived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Future<List<Profile>> getAll({bool includeArchived = false}) {
    return (select(profiles)
          ..where((p) => includeArchived
              ? const Constant(true)
              : p.isArchived.equals(false)))
        .get();
  }

  Future<Profile?> getById(int id) =>
      (select(profiles)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insert(ProfilesCompanion entry) =>
      into(profiles).insert(entry);

  Future<bool> updateProfile(ProfilesCompanion entry) =>
      update(profiles).replace(entry);

  Future<int> archive(int id) => (update(profiles)
        ..where((p) => p.id.equals(id)))
      .write(const ProfilesCompanion(isArchived: Value(true)));

  Future<int> deleteById(int id) =>
      (delete(profiles)..where((p) => p.id.equals(id))).go();
}
