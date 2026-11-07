import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../night/widgets/report_button.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../report_emails/logic/report_email_rules.dart' show emailOrgIdFor;
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

  /// One figure of the night. A figure that needs a person (a payment still to check, a flag waiting) is amber when it is not zero.
  Widget _row(String key, String label, String value, {String? note, bool attention = false}) {
    final waiting = attention && value != '0' && value != 'None';
    return KeyedSubtree(
      key: Key(key),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: BuSpace.xs),
        title: Text(label),
        subtitle: note == null ? null : Text(note),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: waiting ? context.bu.amber : null)),
      ),
    );
  }

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
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl),
        children: [
          const BuPageHeader(eyebrow: 'Payments', title: 'Summary'),
          if (widget.workspace.venueName != null) ...[
            const SizedBox(height: BuSpace.xs),
            Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium?.copyWith(color: context.bu.muted)),
          ],
          const SizedBox(height: BuSpace.l),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: BuSpace.s),
          Align(alignment: Alignment.centerLeft, child: ReportButton(venueId: venueId, venueName: widget.workspace.venueName, emailOrgId: emailOrgIdFor(widget.workspace), night: _night, clock: widget.clock)),
          const SizedBox(height: BuSpace.m),
          OpsAsyncView<VerifierSummary>(
            value: summary,
            what: 'the summary',
            errorKey: const Key('summary-error'),
            onRetry: () => ref.invalidate(verifierSummaryProvider(_query)),
            builder: (s) => BuListCard(
              children: [
                _row('summary-recorded', 'Payments recorded', '${s.paymentsRecorded}'),
                _row('summary-checked', 'Checked', '${s.paymentsChecked}', note: '${s.checkedByMe} by you'),
                _row('summary-to-check', 'Still to check', '${s.paymentsToCheck}', attention: true),
                _row('summary-disputed', 'Disputed by the guest', '${s.paymentsDisputed}', attention: true),
                _row('summary-flags-open', 'Flagged, waiting for a manager', '${s.flagsOpen}', attention: true),
                _row('summary-flags-resolved', 'Flags resolved', '${s.flagsResolved}'),
                _row('summary-handovers-waiting', 'Cash handovers waiting to be counted', '${s.handoversWaiting}', attention: true),
                _row('summary-handovers-counted', 'Cash handovers counted', '${s.handoversAcknowledged}'),
                _row('summary-difference', 'Cash difference', s.cashDifferenceCents == 0 ? 'None' : differenceLabel(s.cashDifferenceCents), attention: true),
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
