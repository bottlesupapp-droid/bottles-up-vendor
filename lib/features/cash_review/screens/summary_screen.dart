import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/widgets/ops_async_view.dart';
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../../workspace/models/workspace.dart';
import '../logic/cash_rules.dart';
import '../providers/cash_providers.dart';

/// The payment verifier's Summary tab: the night's payments, checks, flags and cash at a glance. Counts only; the lists are in Review,
/// Cash and Exceptions.
class VerifierSummaryScreen extends ConsumerStatefulWidget {
  const VerifierSummaryScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<VerifierSummaryScreen> createState() => _VerifierSummaryScreenState();
}

class _VerifierSummaryScreenState extends ConsumerState<VerifierSummaryScreen> {
  late String _night = currentNight(widget.clock());

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);

  Widget _row(String key, String label, String value, {String? note}) => Card(
        key: Key(key),
        child: ListTile(title: Text(label), subtitle: note == null ? null : Text(note), trailing: Text(value, style: Theme.of(context).textTheme.titleLarge)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there is no summary to show.', key: Key('summary-no-venue'), textAlign: TextAlign.center)),
      );
    }
    final summary = ref.watch(verifierSummaryProvider(_query));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(verifierSummaryProvider(_query)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Summary', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: 8),
          OpsAsyncView<VerifierSummary>(
            value: summary,
            what: 'the summary',
            errorKey: const Key('summary-error'),
            onRetry: () => ref.invalidate(verifierSummaryProvider(_query)),
            builder: (s) => Column(
              children: [
                _row('summary-recorded', 'Payments recorded', '${s.paymentsRecorded}'),
                _row('summary-checked', 'Checked', '${s.paymentsChecked}', note: '${s.checkedByMe} by you'),
                _row('summary-to-check', 'Still to check', '${s.paymentsToCheck}'),
                _row('summary-disputed', 'Disputed by the guest', '${s.paymentsDisputed}'),
                _row('summary-flags-open', 'Flagged, waiting for a manager', '${s.flagsOpen}'),
                _row('summary-flags-resolved', 'Flags resolved', '${s.flagsResolved}'),
                _row('summary-handovers-waiting', 'Cash handovers waiting to be counted', '${s.handoversWaiting}'),
                _row('summary-handovers-counted', 'Cash handovers counted', '${s.handoversAcknowledged}'),
                _row('summary-difference', 'Cash difference', s.cashDifferenceCents == 0 ? 'None' : differenceLabel(s.cashDifferenceCents)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('"Short" and "Over" compare what was counted with what was handed in.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
