import 'package:intl/intl.dart';

extension DateOnlyCompare on DateTime {
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  DateTime get dateOnly => DateTime(year, month, day);

  DateTime get startOfWeek {
    // Monday-based week
    final d = dateOnly;
    return d.subtract(Duration(days: d.weekday - 1));
  }

  DateTime get endOfWeek => startOfWeek.add(const Duration(days: 6));

  DateTime get startOfMonth => DateTime(year, month, 1);

  DateTime get endOfMonth => DateTime(year, month + 1, 0);
}

class DurationFormatter {
  DurationFormatter._();

  /// "8h 30m"
  static String hhmm(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// "08:30:05" — for the live timer
  static String hhmmss(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

final _timeFormat = DateFormat('HH:mm');
final _dateFormat = DateFormat('dd MMM yyyy');
final _shortDateFormat = DateFormat('dd MMM');

String formatTime(DateTime dt) => _timeFormat.format(dt);
String formatDate(DateTime dt) => _dateFormat.format(dt);
String formatShortDate(DateTime dt) => _shortDateFormat.format(dt);
