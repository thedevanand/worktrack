import 'package:home_widget/home_widget.dart';

import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/shift_repository.dart';
import '../notifications/notification_core.dart';

const _androidProvider = 'AlooTrackWidgetProvider';
const _qualifiedProvider = 'com.dev.alootrack.AlooTrackWidgetProvider';

class HomeWidgetService {
  HomeWidgetService._();

  static Future<void> init() async {
    HomeWidget.registerInteractivityCallback(homeWidgetBackground);
  }

  /// Push the current state into the widget and ask Android to redraw it.
  static Future<void> refresh(AppDatabase db) async {
    final repo = ShiftRepository(db);
    final shift = await repo.getActiveShift();

    String status;
    String buttonLabel;
    String profileName = '';
    String elapsed = '';

    int? profileId;
    if (shift != null) {
      final breaks = await db.shiftDao.getBreaksForShift(shift.id);
      final paused = breaks.any((b) => b.endAt == null);
      final net = ShiftRepository.netDuration(shift, breaks);
      final profile = await db.profileDao.getById(shift.profileId);
      profileName = profile?.name ?? '';
      profileId = shift.profileId;
      status = paused ? 'Paused' : 'Clocked in';
      elapsed = DurationFormatter.hhmm(net);
      buttonLabel = 'Clock Out';
    } else {
      status = 'Clocked out';
      buttonLabel = 'Clock In';
      final idStr = await db.settingsDao.get(SettingsKeys.defaultProfileId);
      profileId = int.tryParse(idStr ?? '');
    }

    // Up to three open tasks for the relevant profile, shown side by side.
    final allTasks = await db.taskDao.watchAllTasks().first;
    final tasks = allTasks
        .where((t) =>
            t.task.endAt == null &&
            (profileId == null || t.task.profileId == profileId))
        .take(3)
        .toList();

    await HomeWidget.saveWidgetData<String>('status', status);
    await HomeWidget.saveWidgetData<String>('button_label', buttonLabel);
    await HomeWidget.saveWidgetData<String>('profile', profileName);
    await HomeWidget.saveWidgetData<String>('elapsed', elapsed);
    for (var i = 0; i < 3; i++) {
      await HomeWidget.saveWidgetData<String>(
          'task${i + 1}', i < tasks.length ? tasks[i].task.title : '');
    }

    await HomeWidget.updateWidget(
      name: _androidProvider,
      androidName: _androidProvider,
      qualifiedAndroidName: _qualifiedProvider,
    );
  }
}

/// Background entry point invoked when a widget button is tapped.
@pragma('vm:entry-point')
Future<void> homeWidgetBackground(Uri? uri) async {
  if (uri == null) return;
  final db = AppDatabase();
  try {
    final repo = ShiftRepository(db);
    final shift = await repo.getActiveShift();
    if (uri.host == 'clock_toggle') {
      if (shift == null) {
        final pid =
            int.tryParse(await db.settingsDao.get(SettingsKeys.defaultProfileId) ?? '');
        if (pid != null) await repo.clockIn(profileId: pid, at: DateTime.now());
      } else {
        await repo.clockOut(shift: shift);
        await db.taskDao.closeOpenLogs();
      }
    }
    await ShiftNotification.refresh(db);
    await HomeWidgetService.refresh(db);
  } finally {
    await db.close();
  }
}
