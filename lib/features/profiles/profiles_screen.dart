import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import 'profile_form_dialog.dart';

/// Maps a stored profile icon name to a Material Symbols glyph.
IconData profileIconData(String name) => switch (name) {
      'work' => Symbols.work,
      'business' => Symbols.business_center,
      'laptop' => Symbols.laptop_mac,
      'code' => Symbols.code,
      'person' => Symbols.person,
      'design' => Symbols.draw,
      'school' => Symbols.school,
      'home' => Symbols.home,
      'star' => Symbols.star,
      'group' => Symbols.group,
      _ => Symbols.star,
    };

/// Returns an [Icon] widget for the given profile icon name.
Widget profileIconWidget(String name,
    {double size = 18, Color color = Colors.white}) {
  return Icon(profileIconData(name), size: size, color: color, fill: 1);
}

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(activeProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add),
            tooltip: 'New profile',
            onPressed: () => _showForm(context, null),
          ),
        ],
      ),
      body: profilesAsync.when(
        data: (profiles) => profiles.isEmpty
            ? const Center(
                child: Text('No profiles yet — tap + to create one.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _ProfileCard(profile: profiles[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showForm(BuildContext context, Profile? profile) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProfileFormDialog(profile: profile),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(profile.colorHex);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color,
          child: profileIconWidget(profile.iconName),
        ),
        title: Text(profile.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Daily: ${profile.targetDailyMinutes ~/ 60}h  '
          'Weekly: ${profile.targetWeeklyMinutes ~/ 60}h',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Symbols.more_vert),
          onSelected: (v) => _onMenuSelect(context, ref, v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => ProfileFormDialog(profile: profile),
        ),
      ),
    );
  }

  Future<void> _onMenuSelect(
      BuildContext context, WidgetRef ref, String value) async {
    final repo = ref.read(profileRepositoryProvider);
    switch (value) {
      case 'edit':
        showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => ProfileFormDialog(profile: profile),
        );
      case 'archive':
        await repo.archiveProfile(profile.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${profile.name} archived')),
          );
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Profile'),
            content: Text(
                'Delete "${profile.name}"? All its shifts will also be deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await repo.deleteProfile(profile.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${profile.name} deleted')),
            );
          }
        }
    }
  }
}
