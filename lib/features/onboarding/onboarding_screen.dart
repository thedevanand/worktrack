import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/color_utils.dart';
import '../../data/providers.dart';
import '../profiles/profiles_screen.dart';

const _colors = [
  '#2563EB', '#16A34A', '#DC2626', '#D97706', '#7C3AED',
  '#DB2777', '#0891B2', '#059669', '#EA580C', '#64748B',
];

const _icons = [
  'work', 'business', 'laptop', 'code', 'person',
  'design', 'school', 'home', 'star', 'group',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Called after the first profile is created.
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  String _colorHex = _colors.first;
  String _iconName = 'work';
  double _dailyHours = 8;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your profile a name')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final id = await repo.createProfile(
        name: name,
        colorHex: _colorHex,
        iconName: _iconName,
        targetDailyMinutes: (_dailyHours * 60).round(),
        targetWeeklyMinutes: (_dailyHours * 5 * 60).round(),
      );
      await repo.setDefaultProfile(id);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = colorFromHex(_colorHex);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(profileIconData(_iconName),
                    fill: 1, size: 38, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text('Welcome to AlooTrack',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Create your first work profile to start tracking. '
              'You can add or edit profiles anytime in Settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                hintText: 'e.g. Work, Freelance, Studies',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((hex) {
                final selected = hex == _colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? cs.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Symbols.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.map((name) {
                final selected = name == _iconName;
                return GestureDetector(
                  onTap: () => setState(() => _iconName = name),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? accent : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(profileIconData(name),
                        fill: 1,
                        size: 22,
                        color: selected ? Colors.white : cs.onSurfaceVariant),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Text('Daily target',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(
                    _dailyHours == 0
                        ? 'None'
                        : '${_dailyHours.toInt()}h',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            Slider(
              value: _dailyHours,
              min: 0,
              max: 16,
              divisions: 16,
              label: '${_dailyHours.toInt()}h',
              onChanged: (v) => setState(() => _dailyHours = v),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _finish,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Get Started',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
