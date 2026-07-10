import 'package:flutter/material.dart';

/// High-visibility hazard coding. Priority 1 & 2 use deep reds/oranges so
/// critical cases jump out under pressure; lower priorities calm down.
class HazardColors {
  static Color background(int priority) => switch (priority) {
        1 => const Color(0xFFB00020), // deep red — life-threatening
        2 => const Color(0xFFD84315), // deep orange
        3 => const Color(0xFFF9A825), // amber
        4 => const Color(0xFF2E7D32), // green
        _ => const Color(0xFF546E7A), // blue-grey (P5, least urgent)
      };

  static Color onBackground(int priority) =>
      priority == 3 ? const Color(0xFF3E2723) : Colors.white;

  static bool isCritical(int priority) => priority <= 2;

  static String label(int priority) => switch (priority) {
        1 => 'P1 · CRITICAL',
        2 => 'P2 · URGENT',
        3 => 'P3 · MODERATE',
        4 => 'P4 · MINOR',
        _ => 'P5 · NON-URGENT',
      };
}
