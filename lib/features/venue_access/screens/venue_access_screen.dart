import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../agreements/screens/agreement_detail_screen.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../../workspace/models/workspace.dart';
import '../logic/access_rules.dart';
import '../providers/venue_access_providers.dart';
import '../widgets/grant_tile.dart';

/// Your venue access (organizer): for each event that has a club asked to host it, what that club has chosen to share, one thing at a time. The club decides; nothing here changes it.
/// Everything stays with its owner: the organizer cannot edit the club's data and the club cannot edit the organizer's tickets.
class VenueAccessScreen extends ConsumerWidget {
  const VenueAccessScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(venueAccessProvider(workspace.orgId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(venueAccessProvider(workspace.orgId)),
      child: ListView(
        key: const Key('venue-access'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text('Your venue access', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('What each club has chosen to share with you about your events. The club decides, and can change it at any time.', style: theme.textTheme.bodyMedium),
          OpsAsyncView<List<VenueAccessRow>>(
            value: rows,
            what: 'your venue access',
            errorKey: const Key('venue-access-error'),
            onRetry: () => ref.invalidate(venueAccessProvider(workspace.orgId)),
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No club is linked to your events yet. Ask a club to host an event under Venue agreements.',
            emptyKey: const Key('venue-access-empty'),
            builder: (list) => Column(
              children: [
                for (final r in list)
                  Card(
                    key: Key('access-${r.agreementId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.eventTitle, style: theme.textTheme.titleMedium),
                          Text([r.venueName, if (r.eventStart != null) DateFormat('EEE MMM d').format(r.eventStart!.toLocal())].join(' · '), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(accessStatusLine(r.status, r.inForce), key: Key('access-status-${r.agreementId}'), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          if (r.inForce) ...[
                            for (final g in r.grants) GrantLine(grant: g, idPrefix: 'access-${r.agreementId}'),
                          ] else
                            const DeskChip(text: 'Nothing shared yet', color: Color(0xFF9E9E9E)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: Key('access-open-${r.agreementId}'),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AgreementDetailScreen(agreementId: r.agreementId))),
                              child: const Text('Open the agreement'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
