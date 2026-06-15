import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../../core/utils/date_utils.dart';

/// All shift-related business operations. No UI dependencies.
class ShiftRepository {
  final AppDatabase _db;

  ShiftRepository(this._db);

  ShiftDao get _dao => _db.shiftDao;

  // ── Active shift ───────────────────────────────────────────────────────────

  Stream<Shift?> watchActiveShift() => _dao.watchActiveShift();
  Future<Shift?> getActiveShift() => _dao.getActiveShift();

  Stream<Break?> watchActiveBreak(int shiftId) =>
      _dao.watchActiveBreak(shiftId);

  // ── Clock in ───────────────────────────────────────────────────────────────

  Future<Shift> clockIn({
    required int profileId,
    required DateTime at,
    double? lat,
    double? lng,
    ShiftSource source = ShiftSource.manual,
  }) async {
    // Ensure any existing active shift is closed first (safety net)
    final active = await _dao.getActiveShift();
    if (active != null) {
      await _clockOutShift(active, at: at);
    }

    final day = at.dateOnly;
    final workDay = await _getOrCreateWorkDay(profileId, day);

    await _dao.insertShift(ShiftsCompanion.insert(
      workDayId: workDay.id,
      profileId: profileId,
      clockInAt: at,
      clockInLat: Value(lat),
      clockInLng: Value(lng),
      source: Value(source),
    ));

    return (await _dao.getActiveShift())!;
  }

  // ── Clock out ──────────────────────────────────────────────────────────────

  Future<void> clockOut({
    required Shift shift,
    DateTime? at,
    double? lat,
    double? lng,
  }) async {
    final now = at ?? DateTime.now();
    // End any active break first
    final activeBreak = await _dao.getActiveBreak(shift.id);
    if (activeBreak != null) {
      await _dao.updateBreak(activeBreak.toCompanion(true).copyWith(
            endAt: Value(now),
          ));
    }
    await _clockOutShift(shift, at: now, lat: lat, lng: lng);
  }

  Future<void> _clockOutShift(
    Shift shift, {
    required DateTime at,
    double? lat,
    double? lng,
  }) async {
    await _dao.updateShift(shift.toCompanion(true).copyWith(
          clockOutAt: Value(at),
          clockOutLat: Value(lat),
          clockOutLng: Value(lng),
        ));
  }

  // ── Pause / resume ─────────────────────────────────────────────────────────

  Future<void> pauseShift(Shift shift) async {
    final existing = await _dao.getActiveBreak(shift.id);
    if (existing != null) return; // already paused
    await _dao.insertBreak(BreaksCompanion.insert(
      shiftId: shift.id,
      startAt: DateTime.now(),
    ));
  }

  Future<void> resumeShift(Shift shift) async {
    final activeBreak = await _dao.getActiveBreak(shift.id);
    if (activeBreak == null) return;
    await _dao.updateBreak(activeBreak.toCompanion(true).copyWith(
          endAt: Value(DateTime.now()),
        ));
  }

  // ── Switch profile mid-shift ───────────────────────────────────────────────

  Future<Shift> switchProfile(int newProfileId) async {
    final active = await _dao.getActiveShift();
    final now = DateTime.now();
    if (active != null) {
      await clockOut(shift: active, at: now);
    }
    return clockIn(profileId: newProfileId, at: now);
  }

  // ── WorkDay helpers ────────────────────────────────────────────────────────

  Future<WorkDay> _getOrCreateWorkDay(int profileId, DateTime day) async {
    final existing = await _dao.getWorkDay(profileId, day);
    if (existing != null) return existing;

    await _dao.upsertWorkDay(WorkDaysCompanion.insert(
      profileId: profileId,
      date: day,
    ));
    return (await _dao.getWorkDay(profileId, day))!;
  }

  Future<void> setDayType(
      int profileId, DateTime date, DayType type, String note) async {
    final existing = await _dao.getWorkDay(profileId, date);
    if (existing != null) {
      await _dao.upsertWorkDay(existing.toCompanion(true).copyWith(
            dayType: Value(type),
            note: Value(note),
          ));
    } else {
      await _dao.upsertWorkDay(WorkDaysCompanion.insert(
        profileId: profileId,
        date: date.dateOnly,
        dayType: Value(type),
        note: Value(note),
      ));
    }
  }

  // ── Stream queries ─────────────────────────────────────────────────────────

  Stream<WorkDay?> watchWorkDay(int profileId, DateTime date) =>
      _dao.watchWorkDay(profileId, date);

  Stream<List<Shift>> watchShiftsForDate(int profileId, DateTime date) =>
      _dao.watchShiftsForDate(profileId, date);

  Stream<List<Break>> watchBreaksForShift(int shiftId) =>
      _dao.watchBreaksForShift(shiftId);

  Stream<List<WorkDay>> watchWorkDaysInRange(
          int profileId, DateTime from, DateTime to) =>
      _dao.watchWorkDaysInRange(profileId, from, to);

  // ── History / stats (all profiles) ────────────────────────────────────────

  Future<List<WorkDay>> getAllWorkDaysInRange(DateTime from, DateTime to) =>
      _dao.getAllWorkDaysInRange(from, to);

  Future<List<Shift>> getAllShiftsInRange(DateTime from, DateTime to) =>
      _dao.getAllShiftsInRange(from, to);

  Future<List<ShiftWithBreaks>> getAllShiftsWithBreaksInRange(
          DateTime from, DateTime to) =>
      _dao.getAllShiftsWithBreaksInRange(from, to);

  Stream<List<Shift>> watchAllShiftsForDate(DateTime date) =>
      _dao.watchAllShiftsForDate(date);

  Future<void> updateShiftTimes(
          int shiftId, DateTime clockIn, DateTime? clockOut) =>
      _dao.updateShiftTimes(shiftId, clockIn, clockOut);

  Future<void> deleteShift(int shiftId) => _dao.deleteShift(shiftId);

  // ── Duration math ──────────────────────────────────────────────────────────

  /// Net worked duration = (clockOut - clockIn) - sum(breaks)
  static Duration netDuration(Shift shift, List<Break> breaks) {
    final end = shift.clockOutAt ?? DateTime.now();
    final raw = end.difference(shift.clockInAt);
    var breakTotal = Duration.zero;
    for (final b in breaks) {
      final breakEnd = b.endAt ?? DateTime.now();
      breakTotal += breakEnd.difference(b.startAt);
    }
    final net = raw - breakTotal;
    return net.isNegative ? Duration.zero : net;
  }

  /// Net duration for a list of shifts with their breaks.
  static Duration totalNetDuration(List<ShiftWithBreaks> items) {
    var total = Duration.zero;
    for (final item in items) {
      total += netDuration(item.shift, item.breaks);
    }
    return total;
  }
}
