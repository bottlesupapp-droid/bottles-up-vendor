import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/access_rules.dart';

Color accessColor(AccessGrant g) => !g.allowed ? BuTokens.dark.muted : (g.available ? BuTokens.dark.green : BuTokens.dark.amber);

/// One of the six things with where it stands: Shared, Allowed but not available yet, or Not shared. Read only; the club's switches are in [AgreementGrantsCard].
class GrantLine extends StatelessWidget {
  const GrantLine({super.key, required this.grant, required this.idPrefix});

  final AccessGrant grant;
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(grant.key.label, style: theme.textTheme.bodyMedium)),
          DeskChip(key: Key('$idPrefix-${grant.key.value}'), text: grant.stateLabel, color: accessColor(grant)),
        ],
      ),
    );
  }
}
