import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
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
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl),
        children: [
          const BuPageHeader(eyebrow: 'Nightly', title: 'Reports'),
          const SizedBox(height: BuSpace.xs),
          Text(workspace.orgName, style: theme.textTheme.bodyMedium?.copyWith(color: context.bu.muted)),
          const SizedBox(height: BuSpace.xl),
          OpsAsyncView<List<OrgVenue>>(
            value: venues,
            what: 'your venues',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No venues yet. Add one in Venues, then its reports appear here.',
            emptyKey: const Key('owner-reports-empty'),
            errorKey: const Key('owner-reports-error'),
            onRetry: () => ref.invalidate(ownerVenuesProvider(workspace.orgId)),
            builder: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Two or more clubs: the whole business for one night. (With one club its own report is the whole business.)
                if (list.length > 1)
                  BuCard(
                    key: const Key('owner-report-all'),
                    highlight: true,
                    margin: const EdgeInsets.only(bottom: BuSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('All venues together', style: theme.textTheme.titleMedium),
                        const SizedBox(height: BuSpace.xs),
                        Text('Every club\'s report side by side, with the totals when they can be added.', style: theme.textTheme.bodySmall),
                        const SizedBox(height: BuSpace.m),
                        FilledButton.icon(
                          key: const Key('consolidated-open'),
                          icon: const Icon(Ionicons.stats_chart_outline, size: 18),
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
                for (final v in list)
                  BuCard(
                    key: Key('owner-report-${v.id}'),
                    margin: const EdgeInsets.only(bottom: BuSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: BuSpace.m),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ReportButton(venueId: v.id, venueName: v.name, emailOrgId: workspace.orgId, clock: clock),
                            const SizedBox(height: BuSpace.s),
                            OutlinedButton.icon(
                              key: Key('owner-night-${v.id}'),
                              icon: const Icon(Ionicons.moon_outline, size: 18),
                              label: const Text('Close the night'),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(v.name)),
                                  body: SafeArea(child: NightScreen(venueId: v.id, venueName: v.name, emailOrgId: workspace.orgId, canReopen: true, clock: clock)),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ],
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
