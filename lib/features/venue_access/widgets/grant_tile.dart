import 'package:flutter/material.dart';

import '../../server_desk/widgets/desk_chip.dart';
import '../logic/access_rules.dart';

Color accessColor(AccessGrant g) => !g.allowed ? const Color(0xFF9E9E9E) : (g.available ? const Color(0xFF66BB6A) : const Color(0xFFFFB300));

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
