import 'package:drift/drift.dart';
import '../app_database.dart';

part 'shift_dao.g.dart';

/// Combined result of a shift with its breaks.
class ShiftWithBreaks {
  final Shift shift;
  final List<Break> breaks;
  const ShiftWithBreaks(this.shift, this.breaks);
}

@DriftAccessor(tables: [WorkDays, Shifts, Breaks])
class ShiftDao extends DatabaseAccessor<AppDatabase> with _$ShiftDaoMixin {
  ShiftDao(super.db);

  // ── WorkDays ──────────────────────────────────────────────────────────────

  Future<WorkDay?> getWorkDay(int profileId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return (select(workDays)
          ..where((w) =>
              w.profileId.equals(profileId) & w.date.equals(d)))
        .getSingleOrNull();
  }

  Stream<WorkDay?> watchWorkDay(int profileId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return (select(workDays)
          ..where((w) =>
              w.profileId.equals(profileId) & w.date.equals(d)))
        .watchSingleOrNull();
  }

  Future<int> upsertWorkDay(WorkDaysCompanion entry) =>
      into(workDays).insertOnConflictUpdate(entry);

  Future<List<WorkDay>> getWorkDaysInRange(
      int profileId, DateTime from, DateTime to) {
    return (select(workDays)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.date.isBiggerOrEqualValue(DateTime(from.year, from.month, from.day)) &
              w.date.isSmallerOrEqualValue(DateTime(to.year, to.month, to.day)))
          ..orderBy([(w) => OrderingTerm.asc(w.date)]))
        .get();
  }

  Stream<List<WorkDay>> watchWorkDaysInRange(
      int profileId, DateTime from, DateTime to) {
    return (select(workDays)
          ..where((w) =>
              w.profileId.equals(profileId) &
              w.date.isBiggerOrEqualValue(DateTime(from.year, from.month, from.day)) &
              w.date.isSmallerOrEqualValue(DateTime(to.year, to.month, to.day)))
          ..orderBy([(w) => OrderingTerm.asc(w.date)]))
        .watch();
  }

  // ── Shifts ─────────────────────────────────────────────────────────────────

  Future<Shift?> getActiveShift() =>
      (select(shifts)..where((s) => s.clockOutAt.isNull())).getSingleOrNull();

  Stream<Shift?> watchActiveShift() =>
      (select(shifts)..where((s) => s.clockOutAt.isNull()))
          .watchSingleOrNull();

  Future<int> insertShift(ShiftsCompanion entry) =>
      into(shifts).insert(entry);

  Future<bool> updateShift(ShiftsCompanion entry) =>
      shifts.update().replace(entry);

  Future<List<Shift>> getShiftsForWorkDay(int workDayId) =>
      (select(shifts)
            ..where((s) => s.workDayId.equals(workDayId))
            ..orderBy([(s) => OrderingTerm.asc(s.clockInAt)]))
          .get();

  Stream<List<Shift>> watchShiftsForDate(int profileId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final query = select(shifts).join([
      innerJoin(workDays, workDays.id.equalsExp(shifts.workDayId)),
    ])
      ..where(workDays.profileId.equals(profileId) & workDays.date.equals(d))
      ..orderBy([OrderingTerm.asc(shifts.clockInAt)]);
    return query.map((row) => row.readTable(shifts)).watch();
  }

  Future<List<Shift>> getShiftsInRange(
      int profileId, DateTime from, DateTime to) async {
    final query = select(shifts).join([
      innerJoin(workDays, workDays.id.equalsExp(shifts.workDayId)),
    ])
      ..where(workDays.profileId.equals(profileId) &
          workDays.date.isBiggerOrEqualValue(
              DateTime(from.year, from.month, from.day)) &
          workDays.date.isSmallerOrEqualValue(
              DateTime(to.year, to.month, to.day)));
    final rows = await query.get();
    return rows.map((r) => r.readTable(shifts)).toList();
  }

  // ── Breaks ─────────────────────────────────────────────────────────────────

  Future<Break?> getActiveBreak(int shiftId) =>
      (select(breaks)
            ..where((b) => b.shiftId.equals(shiftId) & b.endAt.isNull()))
          .getSingleOrNull();

  Stream<Break?> watchActiveBreak(int shiftId) =>
      (select(breaks)
            ..where((b) => b.shiftId.equals(shiftId) & b.endAt.isNull()))
          .watchSingleOrNull();

  Future<int> insertBreak(BreaksCompanion entry) =>
      into(breaks).insert(entry);

  Future<bool> updateBreak(BreaksCompanion entry) =>
      breaks.update().replace(entry);

  Future<List<Break>> getBreaksForShift(int shiftId) =>
      (select(breaks)..where((b) => b.shiftId.equals(shiftId))).get();

  Stream<List<Break>> watchBreaksForShift(int shiftId) =>
      (select(breaks)..where((b) => b.shiftId.equals(shiftId))).watch();

  // ── Combined ───────────────────────────────────────────────────────────────

  Future<ShiftWithBreaks?> getActiveShiftWithBreaks() async {
    final shift = await getActiveShift();
    if (shift == null) return null;
    final shiftBreaks = await getBreaksForShift(shift.id);
    return ShiftWithBreaks(shift, shiftBreaks);
  }

  Future<List<ShiftWithBreaks>> getShiftsWithBreaksInRange(
      int profileId, DateTime from, DateTime to) async {
    final shiftList = await getShiftsInRange(profileId, from, to);
    final result = <ShiftWithBreaks>[];
    for (final s in shiftList) {
      final b = await getBreaksForShift(s.id);
      result.add(ShiftWithBreaks(s, b));
    }
    return result;
  }

  // ── All-profile history / stats queries ────────────────────────────────────

  Future<List<WorkDay>> getAllWorkDaysInRange(DateTime from, DateTime to) {
    return (select(workDays)
          ..where((w) =>
              w.date.isBiggerOrEqualValue(
                  DateTime(from.year, from.month, from.day)) &
              w.date.isSmallerOrEqualValue(
                  DateTime(to.year, to.month, to.day)))
          ..orderBy([(w) => OrderingTerm.asc(w.date)]))
        .get();
  }

  Future<List<Shift>> getAllShiftsInRange(DateTime from, DateTime to) async {
    final query = select(shifts).join([
      innerJoin(workDays, workDays.id.equalsExp(shifts.workDayId)),
    ])
      ..where(workDays.date.isBiggerOrEqualValue(
              DateTime(from.year, from.month, from.day)) &
          workDays.date.isSmallerOrEqualValue(
              DateTime(to.year, to.month, to.day)));
    return (await query.get()).map((r) => r.readTable(shifts)).toList();
  }

  Future<List<ShiftWithBreaks>> getAllShiftsWithBreaksInRange(
      DateTime from, DateTime to) async {
    final shiftList = await getAllShiftsInRange(from, to);
    final result = <ShiftWithBreaks>[];
    for (final s in shiftList) {
      final b = await getBreaksForShift(s.id);
      result.add(ShiftWithBreaks(s, b));
    }
    return result;
  }

  Stream<List<Shift>> watchAllShiftsForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final query = select(shifts).join([
      innerJoin(workDays, workDays.id.equalsExp(shifts.workDayId)),
    ])
      ..where(workDays.date.equals(d))
      ..orderBy([OrderingTerm.asc(shifts.clockInAt)]);
    return query.map((r) => r.readTable(shifts)).watch();
  }

  Future<void> updateShiftTimes(
      int id, DateTime clockIn, DateTime? clockOut) async {
    await (update(shifts)..where((s) => s.id.equals(id))).write(
      ShiftsCompanion(
        clockInAt: Value(clockIn),
        clockOutAt: Value(clockOut),
      ),
    );
  }

  Future<int> deleteShift(int id) =>
      (delete(shifts)..where((s) => s.id.equals(id))).go();
}
