import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/team_rules.dart';

/// A small coloured label for a person's or an invitation's state.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.label, required this.tone});

  final String label;
  final Tone tone;

  Color _color(BuTokens bu) => switch (tone) {
        Tone.success => bu.green,
        Tone.info => bu.orangeSoft,
        Tone.warning => bu.amber,
        Tone.neutral => bu.muted,
      };

  @override
  Widget build(BuildContext context) => DeskChip(text: label, color: _color(context.bu));
}
