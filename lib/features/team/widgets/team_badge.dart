import 'package:flutter/material.dart';

import '../logic/team_rules.dart';

/// A small coloured label for a person's or an invitation's state.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.label, required this.tone});

  final String label;
  final Tone tone;

  Color get _color => switch (tone) {
        Tone.success => const Color(0xFF66BB6A),
        Tone.info => const Color(0xFF42A5F5),
        Tone.warning => const Color(0xFFFFB300),
        Tone.neutral => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: _color.withValues(alpha: 0.6)),
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _color)),
      );
}
