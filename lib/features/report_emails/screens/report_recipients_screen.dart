import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/owner_rules.dart' show OrgVenue;
import '../../owner/providers/owner_providers.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/report_email_rules.dart';
import '../widgets/recipients_editor.dart';

/// Report e-mails (More): who receives each report. An owner keeps the combined list and a list for each club; a manager their club's; an organizer the event report's. Nothing is sent from here:
/// a report goes out only when someone presses E-mail this report on it.
class ReportRecipientsScreen extends ConsumerWidget {
  const ReportRecipientsScreen({super.key, required this.workspace});

  final Workspace workspace;

  Widget _card(BuildContext context, ReportListScope scope, String title, String keyPrefix) {
    final theme = Theme.of(context);
    return Card(
      key: Key('$keyPrefix-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(listExplainer(scope.kind), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            RecipientsEditor(scope: scope, keyPrefix: keyPrefix),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final children = <Widget>[
      Text('Report e-mails', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(reportEmailNote, key: const Key('report-emails-note'), style: theme.textTheme.bodyMedium),
      const SizedBox(height: 12),
    ];
    switch (workspace.role) {
      case WorkspaceRole.owner:
        children.add(_card(context, ReportListScope(kind: ReportKind.ownerCombined, orgId: workspace.orgId), listTitle(ReportKind.ownerCombined), 'list-combined'));
        children.add(
          Consumer(
            builder: (context, ref, _) {
              final venues = ref.watch(ownerVenuesProvider(workspace.orgId));
              return OpsAsyncView<List<OrgVenue>>(
                value: venues,
                what: 'your venues',
                isEmpty: (d) => d.isEmpty,
                emptyText: 'No venues yet. Add one in Venues, then its night report list appears here.',
                emptyKey: const Key('report-emails-no-venues'),
                errorKey: const Key('report-emails-venues-error'),
                onRetry: () => ref.invalidate(ownerVenuesProvider(workspace.orgId)),
                builder:
                    (list) => Column(
                      children: [
                        for (final v in list)
                          _card(
                            context,
                            ReportListScope(kind: ReportKind.venueNight, orgId: workspace.orgId, venueId: v.id),
                            listTitle(ReportKind.venueNight, venueName: v.name),
                            'list-venue-${v.id}',
                          ),
                      ],
                    ),
              );
            },
          ),
        );
      case WorkspaceRole.manager:
        final venueId = workspace.venueId;
        if (venueId != null) {
          children.add(
            _card(
              context,
              ReportListScope(kind: ReportKind.venueNight, orgId: workspace.orgId, venueId: venueId),
              listTitle(ReportKind.venueNight, venueName: workspace.venueName),
              'list-venue-$venueId',
            ),
          );
        }
      case WorkspaceRole.organizer:
        children.add(_card(context, ReportListScope(kind: ReportKind.organizerSales, orgId: workspace.orgId), listTitle(ReportKind.organizerSales), 'list-events'));
      default:
        children.add(const Text('There is nothing to set up for your role.', key: Key('report-emails-none')));
    }
    return ListView(key: const Key('report-emails'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: children);
  }
}
