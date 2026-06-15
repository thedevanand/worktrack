import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:file_selector/file_selector.dart';

import '../../data/providers.dart';
import '../../services/export/backup_service.dart';
import '../../services/export/export_service.dart';
import '../../services/notifications/attendance_notification_service.dart';
import '../../services/notifications/notification_core.dart';
import '../../services/widget/home_widget_service.dart';
import '../today/today_providers.dart';
import '../profiles/profiles_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _SectionHeader('Profiles'),
          _ProfilesTile(),
          Divider(height: 1),
          _SectionHeader('Appearance'),
          _ThemeTile(),
          Divider(height: 1),
          _SectionHeader('Notifications'),
          _PersistentNotificationTile(),
          _ReminderSection(),
          Divider(height: 1),
          _SectionHeader('Data'),
          _BackupTile(),
          _RestoreTile(),
          _ExportTile(),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

// ── Profiles tile ─────────────────────────────────────────────────────────────

class _ProfilesTile extends StatelessWidget {
  const _ProfilesTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Symbols.group),
      title: const Text('Manage Profiles'),
      subtitle: const Text('Add, edit, or archive work profiles'),
      trailing: const Icon(Symbols.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilesScreen()),
      ),
    );
  }
}

// ── Theme tile ────────────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).valueOrNull ?? 'system';
    final label = switch (mode) {
      'light' => 'Light',
      'dark' => 'Dark',
      _ => 'System Default',
    };

    return ListTile(
      leading: const Icon(Symbols.palette),
      title: const Text('Theme'),
      subtitle: Text(label),
      trailing: const Icon(Symbols.chevron_right),
      onTap: () => _showPicker(context, ref, mode),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, l, icon) in [
              ('light', 'Light', Symbols.light_mode),
              ('dark', 'Dark', Symbols.dark_mode),
              ('system', 'System Default', Symbols.brightness_auto),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(l),
                trailing: current == v
                    ? Icon(Symbols.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ref.read(settingsRepositoryProvider).setThemeMode(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Persistent notification tile ──────────────────────────────────────────────

class _PersistentNotificationTile extends ConsumerStatefulWidget {
  const _PersistentNotificationTile();

  @override
  ConsumerState<_PersistentNotificationTile> createState() =>
      _PersistentNotificationTileState();
}

class _PersistentNotificationTileState
    extends ConsumerState<_PersistentNotificationTile> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .isPersistentNotificationEnabled();
    if (mounted) {
      setState(() {
        _enabled = v;
        _loaded = true;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await ref
        .read(settingsRepositoryProvider)
        .setPersistentNotificationEnabled(v);
    final db = ref.read(databaseProvider);
    await ShiftNotification.refresh(db);
    await HomeWidgetService.refresh(db);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Symbols.notifications_active),
      title: const Text('Persistent Notification'),
      subtitle: Text(_enabled
          ? 'Always-on notification with quick Clock In / Out'
          : 'Shown only while a shift is running'),
      value: _enabled,
      onChanged: _loaded ? _toggle : null,
    );
  }
}

// ── Reminder section ──────────────────────────────────────────────────────────

class _ReminderSection extends ConsumerStatefulWidget {
  const _ReminderSection();

  @override
  ConsumerState<_ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends ConsumerState<_ReminderSection> {
  bool _enabled = true;
  int _hour = 9;
  int _minute = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final enabled = await repo.isAttendancePromptEnabled();
    final hour = await repo.getAttendancePromptHour();
    final minute = await repo.getAttendancePromptMinute();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _hour = hour;
        _minute = minute;
      });
    }
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    await ref.read(settingsRepositoryProvider).setAttendancePromptEnabled(v);
    if (v) {
      await AttendanceNotificationService.scheduleDaily(
          hour: _hour, minute: _minute);
    } else {
      await AttendanceNotificationService.cancelAll();
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await ref
        .read(settingsRepositoryProvider)
        .setAttendancePromptTime(_hour, _minute);
    if (_enabled) {
      await AttendanceNotificationService.scheduleDaily(
          hour: _hour, minute: _minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Symbols.notifications),
          title: const Text('Attendance Reminder'),
          subtitle: Text(_enabled ? 'Daily at $timeStr' : 'Disabled'),
          value: _enabled,
          onChanged: _toggleEnabled,
        ),
        if (_enabled)
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(72, 0, 16, 0),
            title: Text('Reminder time: $timeStr'),
            trailing: const Icon(Symbols.schedule, size: 20),
            onTap: () => _pickTime(context),
          ),
      ],
    );
  }
}

// ── Full backup tile ──────────────────────────────────────────────────────────

class _BackupTile extends ConsumerStatefulWidget {
  const _BackupTile();

  @override
  ConsumerState<_BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends ConsumerState<_BackupTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Symbols.backup),
      title: const Text('Back Up All Data'),
      subtitle: const Text('Save everything to a file you can keep'),
      trailing: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Symbols.chevron_right),
      onTap: _busy ? null : _backup,
    );
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportBackup(ref.read(databaseProvider));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Restore tile ────────────────────────────────────────────────────────────

class _RestoreTile extends ConsumerStatefulWidget {
  const _RestoreTile();

  @override
  ConsumerState<_RestoreTile> createState() => _RestoreTileState();
}

class _RestoreTileState extends ConsumerState<_RestoreTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Symbols.restore),
      title: const Text('Restore From Backup'),
      subtitle: const Text('Replace all data with a backup file'),
      trailing: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Symbols.chevron_right),
      onTap: _busy ? null : _restore,
    );
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text(
            'This replaces ALL current data with the contents of the backup '
            'file. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    const group = XTypeGroup(
      label: 'AlooTrack backup',
      extensions: ['json'],
      mimeTypes: ['application/json'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    final path = file?.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await BackupService.importBackup(db, path);
      // Re-resolve the active profile and refresh outputs against new data.
      ref.invalidate(activeProfileNotifierProvider);
      await ShiftNotification.refresh(db);
      await HomeWidgetService.refresh(db);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Data restored. Restart the app if anything looks off.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Export tile ───────────────────────────────────────────────────────────────

class _ExportTile extends ConsumerStatefulWidget {
  const _ExportTile();

  @override
  ConsumerState<_ExportTile> createState() => _ExportTileState();
}

class _ExportTileState extends ConsumerState<_ExportTile> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Symbols.ios_share),
      title: const Text('Export Shifts'),
      subtitle: const Text('Share as CSV file'),
      trailing: _exporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Symbols.chevron_right),
      onTap: _exporting ? null : _export,
    );
  }

  Future<void> _export() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );
    if (range == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      await ExportService.exportCsv(
        repo: ref.read(shiftRepositoryProvider),
        profiles: ref.read(activeProfilesProvider).valueOrNull ?? [],
        from: range.start,
        to: range.end,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
