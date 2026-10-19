import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../workspace/models/workspace.dart';
import '../logic/money_rules.dart';
import '../providers/money_providers.dart';

/// Money (owner): what each club of the business took, for tonight, the last 7 nights or the last 30. Read-only. "Collected" is what was
/// recorded at the club in cash and by card; "still due" is what tables owe; shortages and overages come from counted cash handovers.
class OwnerMoneyScreen extends ConsumerStatefulWidget {
  const OwnerMoneyScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<OwnerMoneyScreen> createState() => _OwnerMoneyScreenState();
}

class _OwnerMoneyScreenState extends ConsumerState<OwnerMoneyScreen> {
  MoneyRange _range = moneyRanges.first;

  ({String orgId, String from, String to}) get _key {
    final r = _range.resolve(widget.clock());
    return (orgId: widget.workspace.orgId, from: r.from, to: r.to);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider(_key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(moneyProvider(_key)),
      child: ListView(
        key: const Key('money-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
        children: [
          Text('Money', style: theme.textTheme.headlineSmall),
          Text(widget.workspace.orgName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [for (final r in moneyRanges) ChoiceChip(key: Key('money-range-${r.id}'), label: Text(r.label), selected: _range.id == r.id, onSelected: (_) => setState(() => _range = r))],
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_range.describe(widget.clock()), key: const Key('money-nights'), style: theme.textTheme.bodySmall)),
          OpsAsyncView<List<VenueMoney>>(
            value: money,
            what: 'the money figures',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No venues yet. Add one in Venues.',
            emptyKey: const Key('money-empty'),
            errorKey: const Key('money-error'),
            onRetry: () => ref.invalidate(moneyProvider(_key)),
            builder: (clubs) => Column(
              children: [
                if (clubs.length > 1) _MoneyCard(money: totalOf(clubs), keyPrefix: 'money-total', emphasis: true),
                for (final c in clubs) _MoneyCard(money: c, keyPrefix: 'money-${c.venueId}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.money, required this.keyPrefix, this.emphasis = false});

  final VenueMoney money;
  final String keyPrefix;
  final bool emphasis;

  Widget _row(BuildContext context, String key, String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
          Text(value, key: Key('$keyPrefix-$key'), style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = money;
    return Card(
      key: Key(keyPrefix),
      color: emphasis ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (m.quiet)
              Text('Nothing recorded.', key: Key('$keyPrefix-quiet'), style: theme.textTheme.bodySmall)
            else ...[
              _row(context, 'tables', 'Tables · guests', '${m.tables} · ${m.guests}'),
              _row(context, 'booked', 'Booked', formatDollars(m.bookedCents)),
              _row(context, 'paid', 'Paid so far', formatDollars(m.paidCents)),
              _row(context, 'due', 'Still due', formatDollars(m.balanceCents)),
              _row(context, 'collected', 'Collected at the club', formatDollars(m.collectedCents), strong: true),
              _row(context, 'cash', '   Cash', formatDollars(m.cashCents)),
              _row(context, 'card', '   Card', formatDollars(m.cardCents)),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(differenceLine(m), key: Key('$keyPrefix-differences'), style: theme.textTheme.bodySmall)),
              if (m.flagsOpen > 0) Text('${m.flagsOpen} ${m.flagsOpen == 1 ? 'payment is' : 'payments are'} flagged.', key: Key('$keyPrefix-flags'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              Text('${m.nightsClosed} ${m.nightsClosed == 1 ? 'night' : 'nights'} closed.', key: Key('$keyPrefix-closed'), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
