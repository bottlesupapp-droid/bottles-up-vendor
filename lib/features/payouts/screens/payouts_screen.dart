import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../../workspace/models/workspace.dart';
import '../logic/payout_rules.dart';
import '../providers/payout_providers.dart';

/// Settlements and payouts (the business's owner, and an organizer): where the payout account stands, when and how BottlesUp pays out, what is waiting for the next payout, and every payout
/// with what was collected, BottlesUp's share, any adjustment, and its reference once paid. Read only: nothing is entered here. BottlesUp checks the payout details itself, sets the
/// percentage and the weekday in its CMS, makes the transfer and records it; a payout is "Paid" only once a transfer was made and a reference recorded.
class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final payouts = ref.watch(myPayoutsProvider(workspace.orgId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPayoutsProvider(workspace.orgId));
        try {
          await ref.read(myPayoutsProvider(workspace.orgId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('payouts'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          OpsAsyncView<MyPayouts>(
            value: payouts,
            what: 'your payouts',
            errorKey: const Key('payouts-error'),
            onRetry: () => ref.invalidate(myPayoutsProvider(workspace.orgId)),
            builder: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _account(theme, p),
                const SizedBox(height: 12),
                _settings(theme, p),
                if (p.waiting != null) ...[const SizedBox(height: 12), _waiting(theme, p.waiting!)],
                if (!p.isVenueBusiness) Padding(padding: const EdgeInsets.only(top: 12), child: Text(organizerNote, key: const Key('payouts-organizer-note'), style: theme.textTheme.bodySmall)),
                const SizedBox(height: 16),
                Text('Payouts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                if (p.items.isEmpty)
                  Text('No payout has been made yet.', key: const Key('payouts-none'), style: theme.textTheme.bodyMedium)
                else
                  for (final i in p.items) _item(theme, i),
                const SizedBox(height: 16),
                Text('BottlesUp checks your payout details itself; you do not enter bank details in this app. If something here looks wrong, contact BottlesUp.', key: const Key('payouts-footnote'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _account(ThemeData theme, MyPayouts p) {
    final a = p.account;
    final color = switch (a.status) {
      PayoutAccountStatus.ready => const Color(0xFF66BB6A),
      PayoutAccountStatus.underReview => const Color(0xFF42A5F5),
      PayoutAccountStatus.actionRequired => const Color(0xFFEF5350),
      PayoutAccountStatus.incomplete => const Color(0xFFFFB300),
    };
    return Card(
      key: const Key('payout-account'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text('Payout account', style: theme.textTheme.titleMedium)), DeskChip(key: const Key('payout-account-status'), text: a.status.label, color: color)]),
            const SizedBox(height: 6),
            Text(a.status.explanation, key: const Key('payout-account-explained')),
            if (a.holder != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Account holder: ${a.holder}', key: const Key('payout-holder'))),
            if (a.maskedAccount != null) Text('Account: ${a.maskedAccount}', key: const Key('payout-masked')),
            if (a.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.note!, key: const Key('payout-note'), style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget _settings(ThemeData theme, MyPayouts p) {
    final s = p.settings;
    return Card(
      key: const Key('payout-settings'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How you are paid', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final l in settingsLines(s)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l)),
            if (s.nextPayoutOn != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Next payout day: ${payoutDate(s.nextPayoutOn!)}', key: const Key('payout-next'), style: theme.textTheme.titleSmall)),
          ],
        ),
      ),
    );
  }

  Widget _waiting(ThemeData theme, PayoutWaiting w) => Card(
        key: const Key('payout-waiting'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Waiting for the next payout', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(waitingLine(w), key: const Key('payout-waiting-line')),
              const SizedBox(height: 6),
              Text(clubCashNote, key: const Key('payout-cash-note'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _item(ThemeData theme, PayoutItem i) {
    final color = switch (i.status) {
      PayoutItemStatus.paid => const Color(0xFF66BB6A),
      PayoutItemStatus.processing => const Color(0xFF42A5F5),
      PayoutItemStatus.failed => const Color(0xFFEF5350),
      PayoutItemStatus.pending => const Color(0xFFFFB300),
    };
    return Card(
      key: Key('payout-${i.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(formatDollars(i.netCents), style: theme.textTheme.titleLarge)),
                DeskChip(key: Key('payout-status-${i.id}'), text: i.status.label, color: color),
              ],
            ),
            Text(itemHeadline(i), style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(itemMoneyLine(i), key: Key('payout-money-${i.id}')),
            if (i.adjustmentNote != null) Text('Adjustment: ${i.adjustmentNote}', key: Key('payout-adjustment-${i.id}'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(itemStatusLine(i), key: Key('payout-line-${i.id}')),
          ],
        ),
      ),
    );
  }
}
