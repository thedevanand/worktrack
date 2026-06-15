import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';
import 'notification_core.dart';

class AttendanceNotificationService {
  AttendanceNotificationService._();

  static Future<void> scheduleDaily({int hour = 9, int minute = 30}) async {
    await localNotifications.cancel(AppConstants.attendanceNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await localNotifications.zonedSchedule(
      AppConstants.attendanceNotificationId,
      'Have you clocked in?',
      "Tap to log today's attendance.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          attendanceChannelId,
          'Attendance Reminder',
          channelDescription: 'Daily attendance reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() =>
      localNotifications.cancel(AppConstants.attendanceNotificationId);
}
