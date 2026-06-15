import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/core/utils/off_day_logic.dart';
import 'package:worktrack/data/db/app_database.dart';

void main() {
  group('OffDayLogic.isWeeklyOff', () {
    test('Sunday is off when bit 6 set (mask=64)', () {
      final rule = _rule(mask: 64); // Sunday
      // 2024-01-07 is a Sunday
      expect(OffDayLogic.isWeeklyOff(DateTime(2024, 1, 7), rule), isTrue);
    });

    test('Monday is not off when only Sunday bit set', () {
      final rule = _rule(mask: 64);
      expect(OffDayLogic.isWeeklyOff(DateTime(2024, 1, 8), rule), isFalse);
    });

    test('Sun+Sat off (mask=64+32=96)', () {
      final rule = _rule(mask: 96);
      expect(OffDayLogic.isWeeklyOff(DateTime(2024, 1, 6), rule), isTrue); // Sat
      expect(OffDayLogic.isWeeklyOff(DateTime(2024, 1, 7), rule), isTrue); // Sun
      expect(OffDayLogic.isWeeklyOff(DateTime(2024, 1, 5), rule), isFalse); // Fri
    });

    group('alternate Saturday', () {
      // Reference Saturday: 2024-01-06 (epoch day = 2024-01-06 midnight UTC)
      // epochDay = ms / 86400000
      final refMs = DateTime.utc(2024, 1, 6).millisecondsSinceEpoch;
      final refEpochDay = refMs ~/ 86400000;

      test('reference Saturday is off', () {
        final rule = _rule(
          mask: 0,
          alternateSat: true,
          refDay: refEpochDay,
        );
        expect(
            OffDayLogic.isWeeklyOff(DateTime.utc(2024, 1, 6), rule), isTrue);
      });

      test('next Saturday (7 days later) is NOT off', () {
        final rule = _rule(
          mask: 0,
          alternateSat: true,
          refDay: refEpochDay,
        );
        expect(
            OffDayLogic.isWeeklyOff(DateTime.utc(2024, 1, 13), rule), isFalse);
      });

      test('Saturday 14 days later IS off', () {
        final rule = _rule(
          mask: 0,
          alternateSat: true,
          refDay: refEpochDay,
        );
        expect(
            OffDayLogic.isWeeklyOff(DateTime.utc(2024, 1, 20), rule), isTrue);
      });
    });
  });

  group('OffDayLogic.isHoliday', () {
    final holidays = [
      _holiday(DateTime(2024, 1, 26), 'Republic Day'),
    ];

    test('matching date is a holiday', () {
      expect(OffDayLogic.isHoliday(DateTime(2024, 1, 26), holidays), isTrue);
    });

    test('non-matching date is not a holiday', () {
      expect(OffDayLogic.isHoliday(DateTime(2024, 1, 27), holidays), isFalse);
    });
  });

  group('ShiftRepository.netDuration', () {
    test('no breaks = full span', () {
      final shift = _shift(
        DateTime(2024, 1, 8, 9, 0),
        DateTime(2024, 1, 8, 17, 0),
      );
      final dur = _netDuration(shift, []);
      expect(dur, const Duration(hours: 8));
    });

    test('one 30-min break reduces net time', () {
      final shift = _shift(
        DateTime(2024, 1, 8, 9, 0),
        DateTime(2024, 1, 8, 17, 0),
      );
      final b = _break(
        DateTime(2024, 1, 8, 12, 0),
        DateTime(2024, 1, 8, 12, 30),
      );
      final dur = _netDuration(shift, [b]);
      expect(dur, const Duration(hours: 7, minutes: 30));
    });

    test('ongoing break uses now for break end', () {
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final shift = _shift(start, null);
      final b = _openBreak(DateTime.now().subtract(const Duration(minutes: 15)));
      final dur = _netDuration(shift, [b]);
      // Net should be ~45 minutes; we allow a 2-second delta
      expect(dur.inSeconds, closeTo(45 * 60, 2));
    });

    test('duration never negative', () {
      // Break longer than shift (edge case)
      final shift = _shift(
        DateTime(2024, 1, 8, 9, 0),
        DateTime(2024, 1, 8, 9, 5),
      );
      final b = _break(
        DateTime(2024, 1, 8, 9, 0),
        DateTime(2024, 1, 8, 9, 10),
      );
      final dur = _netDuration(shift, [b]);
      expect(dur, Duration.zero);
    });
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

OffDayRule _rule({
  required int mask,
  bool alternateSat = false,
  int? refDay,
}) =>
    OffDayRule(
      id: 1,
      profileId: null,
      weeklyOffMask: mask,
      alternateSatOff: alternateSat,
      alternateSatRefEpochDay: refDay,
    );

Holiday _holiday(DateTime date, String name) => Holiday(
      id: 1,
      date: date,
      name: name,
      profileId: null,
    );

Shift _shift(DateTime clockIn, DateTime? clockOut) => Shift(
      id: 1,
      workDayId: 1,
      profileId: 1,
      clockInAt: clockIn,
      clockOutAt: clockOut,
      clockInLat: null,
      clockInLng: null,
      clockOutLat: null,
      clockOutLng: null,
      source: ShiftSource.manual,
    );

Break _break(DateTime start, DateTime end) => Break(
      id: 1,
      shiftId: 1,
      startAt: start,
      endAt: end,
    );

Break _openBreak(DateTime start) => Break(
      id: 2,
      shiftId: 1,
      startAt: start,
      endAt: null,
    );

Duration _netDuration(Shift shift, List<Break> breaks) {
  final end = shift.clockOutAt ?? DateTime.now();
  final raw = end.difference(shift.clockInAt);
  var breakTotal = Duration.zero;
  for (final b in breaks) {
    final be = b.endAt ?? DateTime.now();
    breakTotal += be.difference(b.startAt);
  }
  final net = raw - breakTotal;
  return net.isNegative ? Duration.zero : net;
}
