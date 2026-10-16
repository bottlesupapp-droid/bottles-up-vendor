import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../floor/logic/bookings_rules.dart' show formatTimeSlot;
import '../../table_service/logic/table_service_rules.dart' show TableStatus, nextAction;
import '../logic/server_desk_rules.dart';
import 'desk_chip.dart';

/// One of the server's tables: when the party arrives, who they are, which table, whether they have arrived, what they have asked
/// for that is still open, and a way to ask for something. No contact details: a server needs the lead guest's name, not their
/// email or phone.
class TableCard extends StatelessWidget {
  const TableCard({
    super.key,
    required this.table,
    required this.openRequests,
    required this.now,
    required this.asking,
    required this.onAsk,
    this.status,
    this.onOpen,
  });

  final AssignedTable table;
  final List<ServiceRequestRow> openRequests;
  final DateTime now;

  /// A request for this table is on its way: the button waits, so a second tap cannot send it twice.
  final bool asking;
  final VoidCallback onAsk;

  /// Where the table stands (what is due, what is left to deliver). Null when it could not be loaded: no line is better than a wrong one.
  final TableStatus? status;

  /// Opens the table's orders and payments. Null for no button.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = table;
    return Card(
      key: Key('table-${t.bookingId}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(formatTimeSlot(t.startTime), style: theme.textTheme.titleSmall),
                if (t.slotLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: Text(t.slotLabel!, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                ],
                const Spacer(),
                if (t.arrived)
                  DeskChip(key: Key('arrived-${t.bookingId}'), text: 'Arrived', color: const Color(0xFF66BB6A), icon: Ionicons.checkmark_circle)
                else
                  DeskChip(key: Key('expected-${t.bookingId}'), text: 'Expected', color: const Color(0xFF9E9E9E)),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.customerName, style: theme.textTheme.titleMedium),
            Text('${t.tableName} · ${t.guestCount} ${t.guestCount == 1 ? 'guest' : 'guests'}', style: theme.textTheme.bodyMedium),
            if (t.confirmationCode != null) Text(t.confirmationCode!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
            if (nextAction(t, status) case final next?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(next, key: Key('next-${t.bookingId}'), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
            for (final r in openRequests)
              Padding(
                key: Key('open-${r.requestId}'),
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${r.kind.label} · waiting ${waitingLabel(r.createdAt, now)}', style: theme.textTheme.bodySmall)),
                    DeskChip(text: r.status.label, color: requestStatusColor(r.status)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onOpen != null)
                  FilledButton.icon(
                    key: Key('open-${t.bookingId}'),
                    onPressed: onOpen,
                    icon: const Icon(Ionicons.receipt_outline, size: 18),
                    label: const Text('Orders and payments'),
                  ),
                OutlinedButton.icon(
                  key: Key('ask-${t.bookingId}'),
                  onPressed: asking ? null : onAsk,
                  icon: const Icon(Ionicons.hand_left_outline, size: 18),
                  label: const Text('Ask for something'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
