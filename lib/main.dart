import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Render the first frame immediately. All startup work (timezones,
  // notifications, widget, DB restore) runs after the UI is up, from
  // TodayScreen — so a slow or failing init can never hang the splash.
  runApp(const ProviderScope(child: WorkTrackApp()));
}
