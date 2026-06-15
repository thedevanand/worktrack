import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/date_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';

class ShiftEditDialog extends ConsumerStatefulWidget {
  const ShiftEditDialog({super.key, required this.shift});

  final Shift shift;

  @override
  ConsumerState<ShiftEditDialog> createState() => _ShiftEditDialogState();
}

class _ShiftEditDialogState extends ConsumerState<ShiftEditDialog> {
  late DateTime _clockIn;
  late DateTime? _clockOut;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clockIn = widget.shift.clockInAt;
    _clockOut = widget.shift.clockOutAt;
  }

  Future<void> _pickTime({required bool isClockIn}) async {
    final base = isClockIn ? _clockIn : (_clockOut ?? _clockIn);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      final updated = DateTime(
          base.year, base.month, base.day, picked.hour, picked.minute);
      if (isClockIn) {
        _clockIn = updated;
      } else {
        _clockOut = updated;
      }
    });
  }

  Future<void> _save() async {
    if (_clockOut != null && _clockOut!.isBefore(_clockIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clock-out must be after clock-in')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(shiftRepositoryProvider)
          .updateShiftTimes(widget.shift.id, _clockIn, _clockOut);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Shift', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _TimePickerTile(
            label: 'Clock In',
            time: _clockIn,
            onTap: () => _pickTime(isClockIn: true),
          ),
          const SizedBox(height: 12),
          _TimePickerTile(
            label: 'Clock Out',
            time: _clockOut,
            onTap: () => _pickTime(isClockIn: false),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final DateTime? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    time != null ? formatTime(time!) : '—',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Symbols.schedule, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
