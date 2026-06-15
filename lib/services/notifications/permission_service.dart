import 'package:permission_handler/permission_handler.dart';

/// Requests the permissions the app needs to show reliable notifications.
class PermissionService {
  PermissionService._();

  static Future<void> requestAll() async {
    try {
      // Always call request() for notifications — it's a no-op if already
      // granted, and shows the system prompt otherwise (Android 13+).
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      // Permissions are best-effort; never let this break startup.
    }
  }
}
