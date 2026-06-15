import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import 'profiles_screen.dart';

const _presetColors = [
  '#2563EB', '#16A34A', '#DC2626', '#D97706', '#7C3AED',
  '#DB2777', '#0891B2', '#059669', '#EA580C', '#64748B',
];

const _presetIconNames = <String>[
  'work', 'business', 'laptop', 'code', 'person',
  'design', 'school', 'home', 'star', 'group',
];

class ProfileFormDialog extends ConsumerStatefulWidget {
  const ProfileFormDialog({super.key, this.profile});

  final Profile? profile;

  @override
  ConsumerState<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends ConsumerState<ProfileFormDialog> {
  late final TextEditingController _nameCtrl;
  late String _colorHex;
  late String _iconName;
  late double _dailyHours;
  late double _weeklyHours;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _colorHex = p?.colorHex ?? _presetColors.first;
    _iconName = p?.iconName ?? 'work';
    _dailyHours = (p?.targetDailyMinutes ?? 480) / 60.0;
    _weeklyHours = (p?.targetWeeklyMinutes ?? 2400) / 60.0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              isEdit ? 'Edit Profile' : 'New Profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Name field
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: !isEdit,
            ),
            const SizedBox(height: 20),

            // Color picker
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((hex) {
                final selected = hex == _colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Symbols.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Icon picker
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetIconNames.map((name) {
                final selected = name == _iconName;
                return GestureDetector(
                  onTap: () => setState(() => _iconName = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorFromHex(_colorHex)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        profileIconData(name),
                        size: 22,
                        fill: 1,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Daily target slider
            _HourSlider(
              label: 'Daily target',
              value: _dailyHours,
              max: 16,
              onChanged: (v) => setState(() => _dailyHours = v),
            ),
            const SizedBox(height: 12),

            // Weekly target slider
            _HourSlider(
              label: 'Weekly target',
              value: _weeklyHours,
              max: 80,
              onChanged: (v) => setState(() => _weeklyHours = v),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      if (widget.profile == null) {
        await repo.createProfile(
          name: name,
          colorHex: _colorHex,
          iconName: _iconName,
          targetDailyMinutes: (_dailyHours * 60).round(),
          targetWeeklyMinutes: (_weeklyHours * 60).round(),
        );
      } else {
        await repo.updateProfile(
          widget.profile!.copyWith(
            name: name,
            colorHex: _colorHex,
            iconName: _iconName,
            targetDailyMinutes: (_dailyHours * 60).round(),
            targetWeeklyMinutes: (_weeklyHours * 60).round(),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _HourSlider extends StatelessWidget {
  const _HourSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final h = value.toInt();
    final m = ((value - h) * 60).round();
    final display = m == 0 ? '${h}h' : '${h}h ${m}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(display, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: (max * 2).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
