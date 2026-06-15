import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/common/loading_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/today/today_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/search/app_search_screen.dart';
import 'services/notifications/attendance_notification_service.dart';
import 'services/notifications/notification_core.dart';
import 'services/notifications/permission_service.dart';
import 'services/widget/home_widget_service.dart';

class WorkTrackApp extends ConsumerWidget {
  const WorkTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final themeMode = themeModeAsync.valueOrNull == 'light'
        ? ThemeMode.light
        : themeModeAsync.valueOrNull == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    return MaterialApp(
      title: 'AlooTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _StartupGate(),
    );
  }
}

// ── Startup gate: loading → onboarding (first run) → main ─────────────────────

enum _GateState { loading, onboarding, ready }

class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate();

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  _GateState _state = _GateState.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    try {
      tz.initializeTimeZones();
      await initLocalNotifications();
      await AttendanceNotificationService.scheduleDaily(hour: 9, minute: 30);
      await HomeWidgetService.init();

      final profiles =
          await ref.read(profileRepositoryProvider).getActiveProfiles();

      final db = ref.read(databaseProvider);
      await ShiftNotification.refresh(db);
      await HomeWidgetService.refresh(db);
      unawaited(PermissionService.requestAll());

      if (mounted) {
        setState(() => _state =
            profiles.isEmpty ? _GateState.onboarding : _GateState.ready);
      }
    } catch (e, st) {
      debugPrint('AlooTrack startup failed: $e\n$st');
      if (mounted) setState(() => _state = _GateState.ready);
    }
  }

  Future<void> _onOnboardingDone() async {
    final db = ref.read(databaseProvider);
    await ShiftNotification.refresh(db);
    await HomeWidgetService.refresh(db);
    if (mounted) setState(() => _state = _GateState.ready);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GateState.loading => const LoadingScreen(message: 'Getting things ready…'),
      _GateState.onboarding => OnboardingScreen(onDone: _onOnboardingDone),
      _GateState.ready => const _MainShell(),
    };
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    CalendarScreen(),
    NotesScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      // Global spotlight search — bottom-left so it never collides with the
      // per-screen add buttons (bottom-right).
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'global_search',
        tooltip: 'Search',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppSearchScreen()),
        ),
        child: const Icon(Symbols.search),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.today),
            selectedIcon: Icon(Symbols.today, fill: 1),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Symbols.calendar_month),
            selectedIcon: Icon(Symbols.calendar_month, fill: 1),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Symbols.sticky_note_2),
            selectedIcon: Icon(Symbols.sticky_note_2, fill: 1),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Symbols.bar_chart),
            selectedIcon: Icon(Symbols.bar_chart, fill: 1),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Symbols.settings),
            selectedIcon: Icon(Symbols.settings, fill: 1),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
