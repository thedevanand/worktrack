import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/shift_repository.dart';

/// Shared plugin instance for the whole app.
final localNotifications = FlutterLocalNotificationsPlugin();

const shiftChannelId = 'active_shift';
const attendanceChannelId = 'attendance_channel';
const _shiftNotifId = 100;

// Action ids (shared with the background isolate).
const _actClockIn = 'clock_in';
const _actClockOut = 'clock_out';
const _actPauseResume = 'pause_resume';

/// Initialise the plugin + channels. Call once from main().
Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(android: android),
    onDidReceiveNotificationResponse: _onResponse,
    onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
  );
  final impl = localNotifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await impl?.createNotificationChannel(const AndroidNotificationChannel(
    shiftChannelId,
    'Active Shift',
    description: 'Ongoing shift timer and quick actions',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ));
  await impl?.createNotificationChannel(const AndroidNotificationChannel(
    attendanceChannelId,
    'Attendance Reminder',
    description: 'Daily attendance prompt',
    importance: Importance.high,
  ));
}

// ── Action handling ─────────────────────────────────────────────────────────

void _onResponse(NotificationResponse r) {
  _handleAction(r.actionId);
}

/// Runs in a separate background isolate when the app is not in the foreground.
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse r) async {
  // The background isolate has its own plugin instance — initialise it so we
  // can re-render the notification afterwards.
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
      const InitializationSettings(android: android));
  await _handleAction(r.actionId);
}

Future<void> _handleAction(String? actionId) async {
  if (actionId == null) return;
  final db = AppDatabase();
  try {
    final repo = ShiftRepository(db);
    final shift = await repo.getActiveShift();
    switch (actionId) {
      case _actClockIn:
        if (shift == null) {
          final idStr = await db.settingsDao.get(SettingsKeys.defaultProfileId);
          final pid = int.tryParse(idStr ?? '');
          if (pid != null) await repo.clockIn(profileId: pid, at: DateTime.now());
        }
      case _actClockOut:
        if (shift != null) {
          await repo.clockOut(shift: shift);
          await db.taskDao.closeOpenLogs();
        }
      case _actPauseResume:
        if (shift != null) {
          final active = await db.shiftDao.getActiveBreak(shift.id);
          if (active != null) {
            await repo.resumeShift(shift);
          } else {
            await repo.pauseShift(shift);
          }
        }
    }
    await ShiftNotification.refresh(db);
  } finally {
    await db.close();
  }
}

// ── Ongoing shift notification ────────────────────────────────────────────────

class ShiftNotification {
  ShiftNotification._();

  /// Render the notification to match the current DB state.
  static Future<void> refresh(AppDatabase db) async {
    final repo = ShiftRepository(db);
    final shift = await repo.getActiveShift();
    if (shift != null) {
      final breaks = await db.shiftDao.getBreaksForShift(shift.id);
      final paused = breaks.any((b) => b.endAt == null);
      final net = ShiftRepository.netDuration(shift, breaks);
      final profile = await db.profileDao.getById(shift.profileId);
      await _showActive(profile?.name ?? 'Shift', net, paused);
      return;
    }
    final persistent =
        (await db.settingsDao.getBool(SettingsKeys.persistentNotificationEnabled)) ??
            false;
    if (persistent) {
      await _showIdle();
    } else {
      await clear();
    }
  }

  static Future<void> _showActive(
      String name, Duration net, bool paused) async {
    // Setting `when` in the past and usesChronometer:true makes Android render
    // a live-ticking timer with no per-second updates needed (the ST trick).
    final whenMs = DateTime.now().millisecondsSinceEpoch - net.inMilliseconds;
    final details = AndroidNotificationDetails(
      shiftChannelId,
      'Active Shift',
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.stopwatch,
      usesChronometer: !paused,
      when: paused ? null : whenMs,
      showWhen: !paused,
      actions: [
        const AndroidNotificationAction(_actClockOut, 'Clock Out',
            showsUserInterface: false, cancelNotification: false),
        AndroidNotificationAction(_actPauseResume, paused ? 'Resume' : 'Pause',
            showsUserInterface: false, cancelNotification: false),
      ],
    );
    await localNotifications.show(
      _shiftNotifId,
      paused ? 'Paused — $name' : 'Working — $name',
      paused ? DurationFormatter.hhmmss(net) : 'In progress',
      NotificationDetails(android: details),
    );
  }

  static Future<void> _showIdle() async {
    const details = AndroidNotificationDetails(
      shiftChannelId,
      'Active Shift',
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      importance: Importance.low,
      priority: Priority.low,
      actions: [
        AndroidNotificationAction(_actClockIn, 'Clock In',
            showsUserInterface: false, cancelNotification: false),
      ],
    );
    await localNotifications.show(
      _shiftNotifId,
      'AlooTrack',
      'Not clocked in',
      const NotificationDetails(android: details),
    );
  }

  static Future<void> clear() => localNotifications.cancel(_shiftNotifId);
}
