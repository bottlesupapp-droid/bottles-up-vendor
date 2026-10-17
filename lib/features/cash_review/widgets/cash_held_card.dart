import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../workspace/models/workspace.dart';
import '../logic/cash_rules.dart';
import '../providers/cash_providers.dart';

/// "You are holding $X in cash" on a server's My Tables, with the way to hand it in. Cash held is worked out by the database from the
/// payments this person recorded, so it can only be handed in once and never more than they hold. Nothing shows for a person who
/// collected no cash that night, or when the cash functions are not on this server yet.
class CashHeldCard extends ConsumerWidget {
  const CashHeldCard({super.key, required this.workspace, required this.night});

  final Workspace workspace;
  final String night;

  NightQuery get _query => NightQuery(workspace.venueId ?? '', night);

  Future<void> _handOver(BuildContext context, WidgetRef ref, CashLine mine) async {
    final messenger = ScaffoldMessenger.of(context);
    final answer = await showAmountNoteDialog(
      context,
      title: 'Hand over cash',
      message: 'You hold ${formatDollars(mine.heldCents)}. Someone else counts it and says what they received.',
      amountLabel: 'Amount you are handing over',
      noteLabel: 'Note (optional)',
      confirmLabel: 'Hand over',
      initialAmount: (mine.heldCents / 100).toStringAsFixed(2),
      validate: (amount, note) => checkHandoverAmount(amount, mine.heldCents).error ?? checkCashNote(note),
    );
    if (answer == null) return;
    final cents = checkHandoverAmount(answer.amount, mine.heldCents).cents!;
    try {
      await ref.read(cashServiceProvider).submit(_query.venueId, night, cents, note: answer.note);
      messenger.showSnackBar(const SnackBar(content: Text('Handover sent. Someone else will count it.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    // Whatever happened, read the position again: after a refusal it shows what is really held now.
    ref.invalidate(cashPositionProvider(_query));
    ref.invalidate(handoversProvider(_query));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = workspace.venueId;
    if (venueId == null || venueId.isEmpty) return const SizedBox.shrink();
    final position = ref.watch(cashPositionProvider(_query));
    return position.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) {
        final e = opsLoadFailureFor(error, 'cash figures');
        // A server without the cash functions yet simply has no card; any other failure is said, not hidden.
        if (e.unavailable) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(top: 8), child: Text(e.message, key: const Key('cash-card-error')));
      },
      data: (lines) {
        final mine = lines.where((l) => l.isMe).firstOrNull;
        if (mine == null || (mine.collectedCents == 0 && mine.handedInCents == 0)) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Card(
          key: const Key('cash-held-card'),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine.heldCents > 0 ? 'You are holding ${formatDollars(mine.heldCents)} in cash' : 'All your cash is handed in',
                  key: const Key('cash-held-title'),
                  style: theme.textTheme.titleMedium,
                ),
                Text('Collected ${formatDollars(mine.collectedCents)} · handed in ${formatDollars(mine.handedInCents)}', style: theme.textTheme.bodySmall),
                if (mine.heldCents > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(key: const Key('hand-over-cash'), onPressed: () => _handOver(context, ref, mine), child: const Text('Hand over cash')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
