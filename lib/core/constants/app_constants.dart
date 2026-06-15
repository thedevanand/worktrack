class AppConstants {
  AppConstants._();

  static const appName = 'WorkTrack';
  static const dbName = 'worktrack.db';

  // Notification channels
  static const shiftChannelId = 'shift_channel';
  static const shiftChannelName = 'Active Shift';
  static const attendanceChannelId = 'attendance_channel';
  static const attendanceChannelName = 'Attendance Reminder';
  static const reminderChannelId = 'reminder_channel';
  static const reminderChannelName = 'Reminders';

  // Notification IDs
  static const shiftNotificationId = 1;
  static const attendanceNotificationId = 2;
  static const stillClockedInNotificationId = 3;

  // Foreground service notification ID
  static const foregroundNotificationId = 100;

  // Default targets
  static const defaultDailyTargetMinutes = 480; // 8 hours
  static const defaultWeeklyTargetMinutes = 2400; // 5 × 8h

  // Default settings
  static const defaultDayStartHour = 9;
  static const defaultDayStartMinute = 0;
  static const defaultDayEndHour = 18;
  static const defaultDayEndMinute = 0;
  static const defaultAttendancePromptHour = 9;
  static const defaultAttendancePromptMinute = 30;
  static const defaultStillClockedInThresholdHours = 10;
  static const defaultGeofenceRadiusMeters = 200.0;
}
