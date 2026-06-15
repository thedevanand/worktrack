import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Branded full-screen loader, reusable for any loading/processing state.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Symbols.timer, fill: 1, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('AlooTrack',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
