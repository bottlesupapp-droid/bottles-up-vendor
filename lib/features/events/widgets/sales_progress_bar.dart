import 'package:flutter/material.dart';

class SalesProgressBar extends StatelessWidget {
  final int sold;
  final int capacity;

  const SalesProgressBar({
    super.key,
    required this.sold,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = capacity > 0 ? sold / capacity : 0.0;

    // Determine color based on progress
    Color progressColor;
    if (progress >= 0.8) {
      progressColor = theme.colorScheme.error; // Red for > 80%
    } else if (progress >= 0.5) {
      progressColor = Colors.orange; // Orange for 50-80%
    } else {
      progressColor = theme.colorScheme.primary; // Primary for < 50%
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sales Progress',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$sold / $capacity',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(progressColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% sold',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
