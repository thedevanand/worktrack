import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/app_database.dart';

String priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };

Color priorityColor(TaskPriority p) => switch (p) {
      TaskPriority.low => const Color(0xFF16A34A),
      TaskPriority.medium => const Color(0xFFD97706),
      TaskPriority.high => const Color(0xFFDC2626),
    };

IconData priorityIcon(TaskPriority p) => switch (p) {
      TaskPriority.low => Symbols.keyboard_arrow_down,
      TaskPriority.medium => Symbols.drag_handle,
      TaskPriority.high => Symbols.keyboard_double_arrow_up,
    };
