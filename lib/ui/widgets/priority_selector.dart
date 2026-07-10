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
        Row(
          children: [
            for (var p = 1; p <= 5; p++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p < 5 ? 8 : 0),
                  child: _PriorityChip(
                    priority: p,
                    isSelected: selected == p,
                    onTap: () => onChanged(p),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: selected != null
              ? Row(
                  key: ValueKey(selected),
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: HazardColors.background(selected!),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      HazardColors.label(selected!),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                  ],
                )
              : const SizedBox(key: ValueKey('none'), height: 0),
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
      key: ValueKey('priority-chip-$priority'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hazard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.ink : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: hazard.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: isSelected ? 1 : 0.55,
          child: Text(
            '$priority',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: HazardColors.onBackground(priority),
            ),
          ),
        ),
      ),
    );
  }
}
