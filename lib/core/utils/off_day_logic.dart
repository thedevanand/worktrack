import '../../data/db/app_database.dart';

/// Pure, unit-testable off-day/holiday logic.
class OffDayLogic {
  OffDayLogic._();

  /// Weekday bitmask: bit 0 = Monday (weekday==1) … bit 6 = Sunday (weekday==7)
  static int maskBit(int weekday) => 1 << (weekday - 1);

  static bool isWeeklyOff(DateTime date, OffDayRule rule) {
    final bit = maskBit(date.weekday);
    if (rule.weeklyOffMask & bit != 0) return true;
    // Alternate Saturday check (Saturday = weekday 6)
    if (date.weekday == 6 && rule.alternateSatOff) {
      final refDay = rule.alternateSatRefEpochDay;
      if (refDay == null) return false;
      final epochDay = date.millisecondsSinceEpoch ~/ 86400000;
      // Every 14 days from the reference Saturday is an "off" Saturday
      return (epochDay - refDay) % 14 == 0;
    }
    return false;
  }

  static bool isHoliday(DateTime date, List<Holiday> holidays) {
    final d = DateTime(date.year, date.month, date.day);
    return holidays.any((h) =>
        h.date.year == d.year &&
        h.date.month == d.month &&
        h.date.day == d.day);
  }

  static bool isOffDay(
    DateTime date,
    OffDayRule? rule,
    List<Holiday> holidays,
  ) {
    if (isHoliday(date, holidays)) return true;
    if (rule != null && isWeeklyOff(date, rule)) return true;
    return false;
  }
}
