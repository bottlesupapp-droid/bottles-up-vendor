import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../../workspace/models/workspace.dart';
import '../logic/cash_rules.dart';
import '../providers/cash_providers.dart';

/// The payment verifier's Cash tab (and the manager's, opened from Tonight): who holds how much cash, and the handovers waiting for
/// someone to count them. Counting says what was actually there; a difference is kept as a shortage or an overage, with its reason.
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  late String _night = currentNight(widget.clock());

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);

  void _refresh() {
    ref.invalidate(cashPositionProvider(_query));
    ref.invalidate(handoversProvider(_query));
    ref.invalidate(verifierSummaryProvider(_query));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _count(Handover h) async {
    final answer = await showAmountNoteDialog(
      context,
      title: 'Count the cash',
      message: '${h.collectorName} handed in ${formatDollars(h.claimedCents)}. Enter what you actually counted.',
      amountLabel: 'Amount counted',
      noteLabel: 'Note (needed if it is different)',
      confirmLabel: 'Save count',
      initialAmount: (h.claimedCents / 100).toStringAsFixed(2),
      validate: (amount, note) {
        final counted = checkCountedAmount(amount);
        if (counted.error != null) return counted.error;
        return checkCountReason(claimedCents: h.claimedCents, countedCents: counted.cents!, note: note);
      },
    );
    if (answer == null) return;
    final counted = checkCountedAmount(answer.amount).cents!;
    try {
      final difference = await ref.read(cashServiceProvider).receive(h.id, counted, note: answer.note);
      _say('Counted: ${differenceLabel(difference)}.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there is no cash to show.', key: Key('cash-no-venue'), textAlign: TextAlign.center)),
      );
    }
    final position = ref.watch(cashPositionProvider(_query));
    final handovers = ref.watch(handoversProvider(_query));

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Cash', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: 8),
          Text('Cash held', style: theme.textTheme.titleMedium),
          OpsAsyncView<List<CashLine>>(
            value: position,
            what: 'cash figures',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No cash was recorded for this night.',
            emptyKey: const Key('cash-empty'),
            errorKey: const Key('cash-error'),
            onRetry: _refresh,
            builder: (lines) => Column(
              children: [
                for (final (i, l) in lines.indexed)
                  Card(
                    key: Key('cash-line-$i'),
                    child: ListTile(
                      title: Text(l.isMe ? '${l.collectorName} (you)' : l.collectorName),
                      subtitle: Text('Collected ${formatDollars(l.collectedCents)} · handed in ${formatDollars(l.handedInCents)}'),
                      trailing: Text(formatDollars(l.heldCents), style: theme.textTheme.titleMedium),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Handovers', style: theme.textTheme.titleMedium),
          OpsAsyncView<List<Handover>>(
            value: handovers,
            what: 'handovers',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'Nothing has been handed in for this night.',
            emptyKey: const Key('handovers-empty'),
            errorKey: const Key('handovers-error'),
            onRetry: _refresh,
            builder: (list) => Column(
              children: [
                for (final h in list)
                  Card(
                    key: Key('handover-${h.id}'),
                    child: ListTile(
                      title: Text('${h.collectorName} · ${formatDollars(h.claimedCents)}'),
                      subtitle: Text(_handoverSubtitle(h)),
                      isThreeLine: h.acknowledged || (h.note != null),
                      trailing: _trailing(h),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _handoverSubtitle(Handover h) {
    final lines = <String>[
      if (h.submittedAt != null) 'Handed in ${DateFormat('HH:mm').format(h.submittedAt!.toLocal())}',
      if (h.note != null) 'Note: ${h.note}',
      if (h.acknowledged)
        'Counted ${formatDollars(h.countedCents ?? 0)}${h.receivedByName == null ? '' : ' by ${h.receivedByName}'}'
            '${h.receiveNote == null ? '' : ' (${h.receiveNote})'}',
    ];
    return lines.join('\n');
  }

  Widget? _trailing(Handover h) {
    if (h.acknowledged) {
      return Text(differenceLabel(h.differenceCents ?? 0), key: Key('difference-${h.id}'));
    }
    if (h.isMine) return const SizedBox(width: 110, child: Text('Someone else must count it', textAlign: TextAlign.end));
    return FilledButton(key: Key('count-${h.id}'), onPressed: () => _count(h), child: const Text('Count'));
  }
}
