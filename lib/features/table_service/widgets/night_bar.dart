import 'package:flutter/material.dart';

import '../../floor/logic/bookings_rules.dart' show addDays, formatNight;

/// Previous / next night with the night's name between, and a way back to tonight. The night is a business night (a slot before 06:00
/// belongs to the night before), as the database counts it.
class NightBar extends StatelessWidget {
  const NightBar({
    super.key,
    required this.night,
    required this.tonight,
    required this.onChanged,
  });

  final String night;
  final String tonight;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('night-prev'),
              tooltip: 'The night before',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onChanged(addDays(night, -1)),
            ),
            Expanded(
              child: Text(
                formatNight(night),
                key: const Key('night-label'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('night-next'),
              tooltip: 'The next night',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onChanged(addDays(night, 1)),
            ),
          ],
        ),
        if (night != tonight)
          TextButton(
            key: const Key('night-tonight'),
            onPressed: () => onChanged(tonight),
            child: const Text('Back to tonight'),
          ),
      ],
    );
  }
}
