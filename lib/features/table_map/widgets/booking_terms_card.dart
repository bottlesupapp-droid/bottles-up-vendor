import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';
import 'move_booking_sheet.dart';

/// What this booking was sold under, on its page: the deposit and who it goes to, the admissions the table includes and the refund policy that applied when it was made.
/// A change to the club's terms later never rewrites these. For a manager or owner it also lists where the booking has been moved, and offers the move.
class BookingTermsCard extends ConsumerWidget {
  const BookingTermsCard({super.key, required this.bookingId, required this.canMove, this.onMoved});

  final String bookingId;

  /// A manager or owner, on a confirmed booking whose night is not closed out.
  final bool canMove;

  /// Called after a move, so the page reads the booking again.
  final VoidCallback? onMoved;

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<MoveResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MoveBookingSheet(bookingId: bookingId),
    );
    ref.invalidate(bookingMovesProvider(bookingId));
    ref.invalidate(moveOptionsProvider(bookingId));
    if (result == null || !context.mounted) return;
    onMoved?.call();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moveMessage(result))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terms = ref.watch(bookingTermsProvider(bookingId));
    final moves = canMove ? ref.watch(bookingMovesProvider(bookingId)).asData?.value ?? const <BookingMove>[] : const <BookingMove>[];
    return Card(
      key: const Key('terms-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms of this booking', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            terms.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opsLoadFailureFor(error, 'the terms').message, key: const Key('terms-error')),
                  if (!opsLoadFailureFor(error, 'the terms').unavailable)
                    TextButton(key: const Key('terms-retry'), onPressed: () => ref.invalidate(bookingTermsProvider(bookingId)), child: const Text('Try again')),
                ],
              ),
              data: (t) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in bookingTermsLines(t)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(line)),
                ],
              ),
            ),
            if (moves.isNotEmpty) ...[
              const Divider(),
              Text('Moved', style: theme.textTheme.titleSmall),
              for (var i = 0; i < moves.length; i++)
                Padding(
                  key: Key('move-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${moves[i].from} → ${moves[i].to}${moves[i].priceDifferenceCents == null || moves[i].priceDifferenceCents == 0 ? '' : ' (deposits differ by ${formatDollars(moves[i].priceDifferenceCents!.abs())})'}\n'
                    '${moves[i].by} · ${DateFormat('MMM d, HH:mm').format(moves[i].movedAt)} · ${moves[i].reason}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (canMove) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(key: const Key('move-booking'), onPressed: () => _move(context, ref), icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Move to another table')),
            ],
          ],
        ),
      ),
    );
  }
}
