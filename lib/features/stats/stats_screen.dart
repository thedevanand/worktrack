import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/shift_repository.dart';
import 'day_shifts_sheet.dart';

enum _Period { week, month }

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _Period _period = _Period.week;
  DateTime _anchor = DateTime.now();

  // Loaded data for the current range.
  Map<String, Duration> _byDay = {};
  Map<String, DayType> _typeByDay = {};
  Map<int, Duration> _byProfile = {};
  Duration _total = Duration.zero;
  int _daysActive = 0;
  bool _loading = true;

  (DateTime, DateTime) get _range {
    if (_period == _Period.week) {
      final start = _anchor.startOfWeek;
      return (start, start.add(const Duration(days: 6)));
    }
    return (_anchor.startOfMonth, _anchor.endOfMonth);
  }

  bool get _canGoNext {
    final now = DateTime.now();
    if (_period == _Period.week) {
      return _anchor.startOfWeek.isBefore(now.startOfWeek);
    }
    return DateTime(_anchor.year, _anchor.month)
        .isBefore(DateTime(now.year, now.month));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _shift(int delta) {
    setState(() {
      _anchor = _period == _Period.week
          ? _anchor.add(Duration(days: 7 * delta))
          : DateTime(_anchor.year, _anchor.month + delta, 1);
    });
    _load();
  }

  void _setPeriod(_Period p) {
    setState(() {
      _period = p;
      _anchor = DateTime.now();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range;
    final repo = ref.read(shiftRepositoryProvider);
    try {
      final items = await repo.getAllShiftsWithBreaksInRange(from, to);
      final workDays = await repo.getAllWorkDaysInRange(from, to);

      final byDay = <String, Duration>{};
      final byProfile = <int, Duration>{};
      final worked = <String>{};
      Duration total = Duration.zero;

      for (final item in items) {
        final net = ShiftRepository.netDuration(item.shift, item.breaks);
        total += net;
        byProfile[item.shift.profileId] =
            (byProfile[item.shift.profileId] ?? Duration.zero) + net;
        final k = _key(item.shift.clockInAt);
        byDay[k] = (byDay[k] ?? Duration.zero) + net;
        if (net.inMinutes > 0) worked.add(k);
      }

      // Aggregate day types across profiles. A working type (fullDay/wfh/
      // halfDay) on ANY profile wins over an off type, so a day you actually
      // worked or marked as a working day is never shown as "off".
      bool isWorking(DayType t) =>
          t == DayType.fullDay || t == DayType.wfh || t == DayType.halfDay;
      final typeByDay = <String, DayType>{};
      for (final wd in workDays) {
        final k = _key(wd.date);
        final existing = typeByDay[k];
        if (existing == null || (isWorking(wd.dayType) && !isWorking(existing))) {
          typeByDay[k] = wd.dayType;
        }
      }

      if (mounted) {
        setState(() {
          _byDay = byDay;
          _typeByDay = typeByDay;
          _byProfile = byProfile;
          _total = total;
          _daysActive = worked.length;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _rangeLabel {
    final (from, to) = _range;
    if (_period == _Period.week) {
      final sameMonth = from.month == to.month;
      final f = DateFormat(sameMonth ? 'd' : 'd MMM').format(from);
      final t = DateFormat('d MMM').format(to);
      return '$f – $t';
    }
    return DateFormat('MMMM yyyy').format(_anchor);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(activeProfilesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_Period>(
              // The default selected-check uses the built-in MaterialIcons
              // font (renders as tofu); turn it off and use Material Symbols.
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: _Period.week,
                    label: Text('Week'),
                    icon: Icon(Symbols.date_range)),
                ButtonSegment(
                    value: _Period.month,
                    label: Text('Month'),
                    icon: Icon(Symbols.calendar_month)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _setPeriod(s.first),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _PeriodNav(
            label: _rangeLabel,
            canGoNext: _canGoNext,
            onPrev: () => _shift(-1),
            onNext: _canGoNext ? () => _shift(1) : null,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _summaryRow(context),
                      const SizedBox(height: 16),
                      if (_period == _Period.week)
                        _WeekBarChart(
                          weekStart: _range.$1,
                          byDay: _byDay,
                          onTapDay: (d) => showDayShiftsSheet(context, d),
                        )
                      else
                        _MonthHeatmap(
                          month: _anchor,
                          byDay: _byDay,
                          typeByDay: _typeByDay,
                          onTapDay: (d) => showDayShiftsSheet(context, d),
                        ),
                      const SizedBox(height: 16),
                      if (_byProfile.isNotEmpty) ...[
                        Text('By Profile',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary)),
                        const SizedBox(height: 8),
                        ...profiles
                            .where((p) => _byProfile.containsKey(p.id))
                            .map((p) => _ProfileRow(
                                  profile: p,
                                  worked: _byProfile[p.id]!,
                                  fraction: _total.inSeconds > 0
                                      ? _byProfile[p.id]!.inSeconds /
                                          _total.inSeconds
                                      : 0.0,
                                )),
                      ],
                      if (_total == Duration.zero)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Center(
                            child: Text('No shifts in this period',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('Tap a day to view or edit its shifts',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Symbols.schedule,
          label: 'Total Worked',
          value: DurationFormatter.hhmm(_total),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _StatCard(
          icon: Symbols.event_available,
          label: 'Days Active',
          value: '$_daysActive',
          color: const Color(0xFF16A34A),
        ),
      ),
    ]);
  }
}

// ── Period navigation ─────────────────────────────────────────────────────────

class _PeriodNav extends StatelessWidget {
  const _PeriodNav({
    required this.label,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Symbols.chevron_left), onPressed: onPrev),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Symbols.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

// ── Week bar chart ────────────────────────────────────────────────────────────

class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({
    required this.weekStart,
    required this.byDay,
    required this.onTapDay,
  });

  final DateTime weekStart;
  final Map<String, Duration> byDay;
  final void Function(DateTime) onTapDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days =
        List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final hours = days
        .map((d) => (byDay[_key(d)] ?? Duration.zero).inMinutes / 60.0)
        .toList();
    final maxH = hours.fold(0.0, (a, b) => a > b ? a : b).clamp(1.0, 24.0);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Hours',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: cs.primary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  maxY: maxH,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchCallback: (event, resp) {
                      if (event is FlTapUpEvent &&
                          resp?.spot != null) {
                        onTapDay(days[resp!.spot!.touchedBarGroupIndex]);
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) {
                        if (rod.toY <= 0) return null;
                        final h = rod.toY.toInt();
                        final m = ((rod.toY - h) * 60).round();
                        return BarTooltipItem(
                          m == 0 ? '${h}h' : '${h}h ${m}m',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          const labels = [
                            'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'
                          ];
                          return Text(labels[i],
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant));
                        },
                      ),
                    ),
                  ),
                  barGroups: days.asMap().entries.map((e) {
                    final isToday =
                        DateUtils.isSameDay(e.value, DateTime.now());
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: hours[e.key],
                          color: isToday ? cs.primary : cs.primaryContainer,
                          width: 26,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxH,
                            color: cs.surfaceContainerLow,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Month heatmap calendar ────────────────────────────────────────────────────

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.month,
    required this.byDay,
    required this.typeByDay,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, Duration> byDay;
  final Map<String, DayType> typeByDay;
  final void Function(DateTime) onTapDay;

  Color? _cellColor(DateTime date, ColorScheme cs) {
    final worked = byDay[_key(date)] ?? Duration.zero;
    if (worked.inMinutes > 0) {
      // Heat by hours: 0–8h → light to strong green.
      final frac = (worked.inMinutes / (8 * 60)).clamp(0.15, 1.0);
      return const Color(0xFF16A34A).withValues(alpha: frac);
    }
    return switch (typeByDay[_key(date)]) {
      DayType.leave => const Color(0xFFF59E0B).withValues(alpha: 0.85),
      DayType.officialOff ||
      DayType.weeklyOff =>
        const Color(0xFF64748B).withValues(alpha: 0.7),
      _ => null,
    };
  }

  String _short(DayType? t, bool worked) {
    if (worked) return '';
    return switch (t) {
      DayType.wfh => 'WFH',
      DayType.halfDay => 'Half',
      DayType.leave => 'Leave',
      DayType.officialOff || DayType.weeklyOff => 'Off',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstWeekday = month.startOfMonth.weekday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final cellCount = ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.85,
              ),
              itemCount: cellCount,
              itemBuilder: (ctx, i) {
                final dayNum = i - (firstWeekday - 2);
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(month.year, month.month, dayNum);
                final worked = (byDay[_key(date)] ?? Duration.zero);
                final cellColor = _cellColor(date, cs);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                final hasFill = worked.inMinutes > 0;
                final short = _short(typeByDay[_key(date)], hasFill);

                return GestureDetector(
                  onTap: () => onTapDay(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor ?? cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: cs.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$dayNum',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: cellColor != null
                                      ? Colors.white
                                      : cs.onSurface,
                                )),
                        if (hasFill)
                          Text(DurationFormatter.hhmm(worked),
                              style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600))
                        else if (short.isNotEmpty)
                          Text(short,
                              style: TextStyle(
                                  fontSize: 8,
                                  color: cellColor != null
                                      ? Colors.white
                                      : cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile row ───────────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.worked,
    required this.fraction,
  });

  final Profile profile;
  final Duration worked;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(profile.colorHex);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(profile.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                  Text(DurationFormatter.hhmm(worked),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('${(fraction * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
