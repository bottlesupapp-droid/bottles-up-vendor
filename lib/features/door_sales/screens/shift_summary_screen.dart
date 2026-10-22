import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../door/logic/door_rules.dart';
import '../../door/providers/door_providers.dart';
import '../../door/services/door_service.dart';
import '../../door/widgets/door_event_bar.dart';
import '../../door/widgets/door_message.dart';
import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../logic/door_sales_rules.dart';
import '../providers/door_sales_providers.dart';

/// Shift summary (door role, More): this person's own night at the selected event. The guests they let in by scanning, and the tickets they sold, with the cash and the card machine
/// kept apart (the brief: "record cash and external-terminal methods separately"). Only their own figures: the database never shows another door person's. It can still be read after the
/// event has ended, while the person still has the door role.
class ShiftSummaryScreen extends ConsumerWidget {
  const ShiftSummaryScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(doorEventsProvider(membershipId));
    return events.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DoorMessage(
        text: error is DoorLoadException ? error.message : doorLoadMessage(unavailable: false, accessEnded: false),
        onRetry: error is DoorLoadException && error.unavailable ? null : () => ref.invalidate(doorEventsProvider(membershipId)),
      ),
      data: (list) {
        final event = resolveEvent(list, ref.watch(selectedDoorEventProvider(membershipId)));
        if (event == null) return DoorMessage(text: 'No event to show a shift for right now.', onRetry: () => ref.invalidate(doorEventsProvider(membershipId)));
        return _Body(membershipId: membershipId, events: list, event: event);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.membershipId, required this.events, required this.event});

  final String membershipId;
  final List<DoorEvent> events;
  final DoorEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(shiftSummaryProvider(event.eventId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        DoorEventBar(
          events: events,
          selected: event,
          onSelect: (id) => ref.read(selectedDoorEventProvider(membershipId).notifier).state = id,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('shift-refresh'),
            onPressed: () => ref.invalidate(shiftSummaryProvider(event.eventId)),
            icon: const Icon(Ionicons.refresh_outline, size: 18),
            label: const Text('Refresh'),
          ),
        ),
        summary.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (error, _) {
            final e = opsLoadFailureFor(error, 'your shift');
            return Column(children: [
              Text(e.message, key: const Key('shift-error'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (!e.unavailable) OutlinedButton(key: const Key('shift-retry'), onPressed: () => ref.invalidate(shiftSummaryProvider(event.eventId)), child: const Text('Try again')),
            ]);
          },
          data: (s) => _Figures(summary: s, theme: theme),
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.summary, required this.theme});

  final ShiftSummary summary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cash = summary.cash;
    final terminal = summary.terminal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Checked in by you', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        _Line(label: 'Guests you let in by scanning', value: '${summary.guestsAdmitted}', valueKey: const Key('shift-guests')),
        _Line(label: 'Scans accepted', value: '${summary.scansAccepted}', valueKey: const Key('shift-scans')),
        const SizedBox(height: 20),
        Text('Sold by you at the door', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (!summary.hasSales)
          Text('You have not sold a ticket at this event.', key: const Key('shift-no-sales'), style: theme.textTheme.bodyMedium)
        else ...[
          _Line(label: 'Tickets sold', value: salesTicketsLine(summary.salesCount, summary.ticketsSold), valueKey: const Key('shift-sold')),
          _Line(label: 'Cash', value: cash == null ? formatDollars(0) : '${formatDollars(cash.amountCents)} · ${salesTicketsLine(cash.sales, cash.tickets)}', valueKey: const Key('shift-cash')),
          _Line(
            label: 'Card machine',
            value: terminal == null ? formatDollars(0) : '${formatDollars(terminal.amountCents)} · ${salesTicketsLine(terminal.sales, terminal.tickets)}',
            valueKey: const Key('shift-terminal'),
          ),
          const Divider(),
          _Line(label: 'Recorded in all', value: formatDollars(summary.totalCents), valueKey: const Key('shift-total'), bold: true),
          if (summary.firstSaleAt != null && summary.lastSaleAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('First sale ${shiftTime(summary.firstSaleAt!)} · last sale ${shiftTime(summary.lastSaleAt!)}', key: const Key('shift-times'), style: theme.textTheme.bodySmall),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'These are the sales you recorded. BottlesUp did not take this money: count your cash against the cash figure, and match the card machine\'s receipts to the numbers you entered, before you hand over.',
          key: const Key('shift-note'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, required this.valueKey, this.bold = false});

  final String label;
  final String value;
  final Key valueKey;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, key: valueKey, textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }
}
