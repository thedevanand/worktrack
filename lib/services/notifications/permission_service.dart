import 'package:permission_handler/permission_handler.dart';

/// Requests the permissions the app needs to show reliable notifications.
class PermissionService {
  PermissionService._();

  static Future<void> requestAll() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
