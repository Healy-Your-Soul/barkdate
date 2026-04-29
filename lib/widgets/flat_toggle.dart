import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_typography.dart';

/// A flat pill-style toggle widget that replaces the standard SegmentedButton.
/// Used in onboarding and profile editing for consistent UI.
class FlatToggle extends StatelessWidget {
  final List<String> options;
  final List<String>? labels;
  final List<IconData>? icons;
  final String selected;
  final ValueChanged<String> onChanged;

  const FlatToggle({
    super.key,
    required this.options,
    this.labels,
    this.icons,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = options[index] == selected;
          final label = labels != null ? labels![index] : options[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[index]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null) ...[
                        Icon(
                          icons![index],
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: AppTypography.labelMedium(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
