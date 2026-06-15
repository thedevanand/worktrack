import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/shift_repository.dart';

class ExportService {
  ExportService._();

  static Future<void> exportCsv({
    required ShiftRepository repo,
    required List<Profile> profiles,
    required DateTime from,
    required DateTime to,
  }) async {
    final profileMap = {for (final p in profiles) p.id: p};
    final items = await repo.getAllShiftsWithBreaksInRange(from, to);

    final rows = <List<dynamic>>[
      ['Profile', 'Date', 'Clock In', 'Clock Out', 'Net Hours', 'Source'],
    ];

    for (final item in items) {
      final s = item.shift;
      final profile = profileMap[s.profileId];
      final net = ShiftRepository.netDuration(s, item.breaks);
      rows.add([
        profile?.name ?? s.profileId.toString(),
        _date(s.clockInAt),
        _time(s.clockInAt),
        s.clockOutAt != null ? _time(s.clockOutAt!) : '',
        (net.inMinutes / 60.0).toStringAsFixed(2),
        s.source.name,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final name =
        'alootrack_${_date(from).replaceAll('-', '')}_${_date(to).replaceAll('-', '')}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'AlooTrack Shift Export',
    );
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
