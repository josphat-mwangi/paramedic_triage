import 'package:flutter/material.dart';

import '../theme/hazard_colors.dart';

class PrioritySelector extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onChanged;
  final String? errorText;

  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Priority level',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var p = 1; p <= 5; p++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _PriorityChip(
                    priority: p,
                    isSelected: selected == p,
                    onTap: () => onChanged(p),
                  ),
                ),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final int priority;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.priority,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hazard = HazardColors.background(priority);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? hazard : hazard.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hazard, width: isSelected ? 0 : 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$priority',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isSelected ? HazardColors.onBackground(priority) : hazard,
          ),
        ),
      ),
    );
  }
}
