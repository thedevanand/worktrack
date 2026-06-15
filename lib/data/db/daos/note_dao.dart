import 'package:drift/drift.dart';
import '../app_database.dart';

part 'note_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<Note>> watchNotes({bool archived = false, int? profileId}) {
    return (select(notes)
          ..where((n) {
            var cond = n.isArchived.equals(archived);
            if (profileId != null) {
              cond = cond & n.profileId.equals(profileId);
            }
            return cond;
          })
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchNotesForTask(int taskId) =>
      (select(notes)..where((n) => n.taskId.equals(taskId))).watch();

  Future<Note?> getById(int id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) => notes.update().replace(entry);

  Future<void> setArchived(int id, bool archived) =>
      (update(notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(isArchived: Value(archived)));

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<List<Note>> searchNotes(String query) {
    final like = '%${query.toLowerCase()}%';
    return (select(notes)
          ..where((n) =>
              n.title.lower().like(like) | n.body.lower().like(like))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(30))
        .get();
  }
}
