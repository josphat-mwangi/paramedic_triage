import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
        Text('Priority level', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('1 is life-threatening — pick the level that fits now.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Column(
          children: [
            for (var p = 1; p <= 5; p++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PriorityCard(
                  priority: p,
                  isSelected: selected == p,
                  onTap: () => onChanged(p),
                ),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(errorText!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final int priority;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityCard({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? hazard.withValues(alpha: 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? hazard : AppTheme.hairline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hazard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$priority',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HazardColors.onBackground(priority),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                HazardColors.label(priority),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? hazard : AppTheme.hairline,
            ),
          ],
        ),
      ),
    );
  }
}
