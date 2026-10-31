import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/owner_rules.dart' show OrgVenue;
import '../../owner/providers/owner_providers.dart';
import '../../workspace/models/workspace.dart';
import '../widgets/report_button.dart';
import 'consolidated_report_screen.dart';
import 'night_screen.dart';

/// Reports (owner): for each club of the business, the nightly report and the controls to prepare, close and (only here) reopen a night.
class OwnerReportsScreen extends ConsumerWidget {
  const OwnerReportsScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final venues = ref.watch(ownerVenuesProvider(workspace.orgId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ownerVenuesProvider(workspace.orgId)),
      child: ListView(
        key: const Key('owner-reports'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
        children: [
          Text('Reports', style: theme.textTheme.headlineSmall),
          Text(workspace.orgName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          OpsAsyncView<List<OrgVenue>>(
            value: venues,
            what: 'your venues',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No venues yet. Add one in Venues, then its reports appear here.',
            emptyKey: const Key('owner-reports-empty'),
            errorKey: const Key('owner-reports-error'),
            onRetry: () => ref.invalidate(ownerVenuesProvider(workspace.orgId)),
            builder: (list) => Column(
              children: [
                // Two or more clubs: the whole business for one night. (With one club its own report is the whole business.)
                if (list.length > 1)
                  Card(
                    key: const Key('owner-report-all'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All venues together', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Every club\'s report side by side, with the totals when they can be added.', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('consolidated-open'),
                            icon: const Icon(Icons.stacked_bar_chart_outlined, size: 18),
                            label: const Text('Combined report'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('All venues')),
                                body: SafeArea(child: ConsolidatedReportScreen(orgId: workspace.orgId, orgName: workspace.orgName, clock: clock)),
                              ),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final v in list)
                  Card(
                    key: Key('owner-report-${v.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ReportButton(venueId: v.id, venueName: v.name, clock: clock),
                              OutlinedButton.icon(
                                key: Key('owner-night-${v.id}'),
                                icon: const Icon(Icons.nightlight_outlined, size: 18),
                                label: const Text('Close the night'),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(title: Text(v.name)),
                                    body: SafeArea(child: NightScreen(venueId: v.id, venueName: v.name, canReopen: true, clock: clock)),
                                  ),
                                )),
                              ),
                            ],
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
