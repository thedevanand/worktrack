import 'package:drift/drift.dart';
import '../app_database.dart';

part 'task_dao.g.dart';

class TaskWithType {
  final Task task;
  final TaskType taskType;
  const TaskWithType(this.task, this.taskType);
}

@DriftAccessor(tables: [Tasks, TaskTypes, TaskMilestones, TaskTimeLogs])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  // ── Task types ─────────────────────────────────────────────────────────────

  Stream<List<TaskType>> watchAllTaskTypes() =>
      (select(taskTypes)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<List<TaskType>> getAllTaskTypes() => select(taskTypes).get();

  Future<int> insertTaskType(TaskTypesCompanion entry) =>
      into(taskTypes).insert(entry);

  Future<bool> updateTaskType(TaskTypesCompanion entry) =>
      taskTypes.update().replace(entry);

  Future<int> deleteTaskType(int id) =>
      (delete(taskTypes)..where((t) => t.id.equals(id))).go();

  // ── Tasks ──────────────────────────────────────────────────────────────────

  Stream<List<TaskWithType>> watchTasksForDate(
      int profileId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final query = select(tasks).join([
      innerJoin(taskTypes, taskTypes.id.equalsExp(tasks.taskTypeId)),
    ])
      ..where(tasks.profileId.equals(profileId) & tasks.date.equals(d))
      ..orderBy([OrderingTerm.asc(tasks.createdAt)]);
    return query
        .map((row) => TaskWithType(
              row.readTable(tasks),
              row.readTable(taskTypes),
            ))
        .watch();
  }

  Stream<List<TaskWithType>> watchTasksInRange(
      int profileId, DateTime from, DateTime to) {
    final query = select(tasks).join([
      innerJoin(taskTypes, taskTypes.id.equalsExp(tasks.taskTypeId)),
    ])
      ..where(tasks.profileId.equals(profileId) &
          tasks.date
              .isBiggerOrEqualValue(DateTime(from.year, from.month, from.day)) &
          tasks.date.isSmallerOrEqualValue(
              DateTime(to.year, to.month, to.day)));
    return query
        .map((row) => TaskWithType(
              row.readTable(tasks),
              row.readTable(taskTypes),
            ))
        .watch();
  }

  Future<int> insertTask(TasksCompanion entry) =>
      into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) =>
      tasks.update().replace(entry);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<Task?> getTaskById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ── All tasks / backlog (cross-profile) ──────────────────────────────────────

  Stream<List<TaskWithType>> watchAllTasksForDateAllProfiles(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final query = select(tasks).join([
      innerJoin(taskTypes, taskTypes.id.equalsExp(tasks.taskTypeId)),
    ])
      ..where(tasks.date.equals(d))
      ..orderBy([OrderingTerm.asc(tasks.createdAt)]);
    return query
        .map((row) =>
            TaskWithType(row.readTable(tasks), row.readTable(taskTypes)))
        .watch();
  }

  Stream<List<TaskWithType>> watchAllTasks() {
    final query = select(tasks).join([
      innerJoin(taskTypes, taskTypes.id.equalsExp(tasks.taskTypeId)),
    ])
      ..orderBy([
        OrderingTerm.desc(tasks.date),
        OrderingTerm.asc(tasks.createdAt),
      ]);
    return query
        .map((row) =>
            TaskWithType(row.readTable(tasks), row.readTable(taskTypes)))
        .watch();
  }

  Future<List<TaskWithType>> searchTasks(String query) async {
    final like = '%${query.toLowerCase()}%';
    final q = select(tasks).join([
      innerJoin(taskTypes, taskTypes.id.equalsExp(tasks.taskTypeId)),
    ])
      ..where(tasks.title.lower().like(like))
      ..orderBy([OrderingTerm.desc(tasks.date)])
      ..limit(30);
    final rows = await q.get();
    return rows
        .map((row) =>
            TaskWithType(row.readTable(tasks), row.readTable(taskTypes)))
        .toList();
  }

  // ── Milestones ───────────────────────────────────────────────────────────────

  Stream<List<TaskMilestone>> watchMilestones(int taskId) =>
      (select(taskMilestones)
            ..where((m) => m.taskId.equals(taskId))
            ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
          .watch();

  Future<List<TaskMilestone>> getMilestones(int taskId) =>
      (select(taskMilestones)
            ..where((m) => m.taskId.equals(taskId))
            ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
          .get();

  Future<int> insertMilestone(TaskMilestonesCompanion entry) =>
      into(taskMilestones).insert(entry);

  Future<bool> updateMilestone(TaskMilestonesCompanion entry) =>
      taskMilestones.update().replace(entry);

  Future<void> setMilestoneDone(int id, bool done) =>
      (update(taskMilestones)..where((m) => m.id.equals(id)))
          .write(TaskMilestonesCompanion(isDone: Value(done)));

  Future<int> deleteMilestone(int id) =>
      (delete(taskMilestones)..where((m) => m.id.equals(id))).go();

  // ── Per-task time logs ───────────────────────────────────────────────────────

  /// The currently running task log (endAt == null), if any.
  Stream<TaskTimeLog?> watchOpenLog() =>
      (select(taskTimeLogs)..where((l) => l.endAt.isNull()))
          .watchSingleOrNull();

  Future<TaskTimeLog?> getOpenLog() =>
      (select(taskTimeLogs)..where((l) => l.endAt.isNull()))
          .getSingleOrNull();

  /// Close any open log, then (optionally) start a new one for [taskId].
  Future<void> switchActiveTask(int? taskId, {int? shiftId}) async {
    final now = DateTime.now();
    await (update(taskTimeLogs)..where((l) => l.endAt.isNull()))
        .write(TaskTimeLogsCompanion(endAt: Value(now)));
    if (taskId != null) {
      await into(taskTimeLogs).insert(TaskTimeLogsCompanion.insert(
        taskId: taskId,
        shiftId: Value(shiftId),
        startAt: now,
      ));
    }
  }

  Future<void> closeOpenLogs() async {
    await (update(taskTimeLogs)..where((l) => l.endAt.isNull()))
        .write(TaskTimeLogsCompanion(endAt: Value(DateTime.now())));
  }

  Future<List<TaskTimeLog>> getLogsForTask(int taskId) =>
      (select(taskTimeLogs)..where((l) => l.taskId.equals(taskId))).get();

  Stream<List<TaskTimeLog>> watchLogsForTask(int taskId) =>
      (select(taskTimeLogs)..where((l) => l.taskId.equals(taskId))).watch();

  static Duration totalLogged(List<TaskTimeLog> logs) {
    var total = Duration.zero;
    for (final l in logs) {
      total += (l.endAt ?? DateTime.now()).difference(l.startAt);
    }
    return total.isNegative ? Duration.zero : total;
  }
}
