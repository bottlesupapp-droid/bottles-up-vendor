import 'package:flutter/material.dart';

import '../../bottle_signs/logic/sign_rules.dart' show LineSign;
import '../../bottle_signs/widgets/line_sign_bar.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/bottle_orders_rules.dart';
import '../logic/table_service_rules.dart';

Color serviceStateColor(ServiceState s) => switch (s) {
  ServiceState.awaitingPrep => const Color(0xFFFFB300),
  ServiceState.accepted => const Color(0xFFFFD54F),
  ServiceState.preparing => const Color(0xFF42A5F5),
  ServiceState.ready => const Color(0xFF26C6DA),
  ServiceState.pickedUp => const Color(0xFFAB47BC),
  ServiceState.served => const Color(0xFF66BB6A),
};

Color linePaymentColor(LinePayment p) => switch (p) {
  LinePayment.paid => const Color(0xFF66BB6A),
  LinePayment.dueAtVenue => const Color(0xFFFFB300),
  LinePayment.pendingPayment => const Color(0xFF9E9E9E),
};

/// One bottle line with where it stands, how it is paid and the move to make next. The moves offered are the ones the database would
/// accept for this person; an item to be paid at the venue says why it cannot be delivered while its table owes money.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.line,
    required this.now,
    required this.manager,
    required this.busy,
    required this.onMove,
    this.onOpenTable,
    this.showTable = true,
    this.onDeliverPart,
    this.sign,
    this.onSignChanged,
  });

  final OrderLine line;
  final DateTime now;
  final bool manager;

  /// A move for this line is on its way: the buttons wait, so a second tap cannot send it twice.
  final bool busy;
  final ValueChanged<ServiceState> onMove;

  /// Opens the table's page. Null for no link (the card already is on it).
  final VoidCallback? onOpenTable;

  /// Show which table and guest this is (a night's list); a table's own page already says.
  final bool showTable;

  /// Hand over part of the line (a table's own page only). Offered when the line allows it (see [canDeliverPart]).
  final VoidCallback? onDeliverPart;

  /// The sign on this line, when the club uses signs (see the bottle_signs feature). With review on, a waiting or declined sign stops the order being prepared or delivered, so those
  /// moves are not offered, exactly as the database would refuse them.
  final LineSign? sign;

  /// A sign was set, removed, approved or declined: the screen reads its lists again.
  final VoidCallback? onSignChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = line;
    final block = deliveryBlock(l);
    final primary = primaryMove(l, manager: manager);
    final targets = moveTargets(l, manager: manager);
    final menu = [
      for (final s in targets)
        if (s != primary) s,
    ];
    final signStops = sign?.blocksService ?? false;
    // Accepting an order is still fine while its sign waits; preparing, handing over and delivering are not.
    bool stoppedBySign(ServiceState s) => signStops && s != ServiceState.awaitingPrep && s != ServiceState.accepted;
    final tableLine = [
      if (l.tableName != null) l.tableName!,
      if (l.customerName != null) l.customerName!,
    ].join(' · ');

    return Card(
      key: Key('order-${l.lineId}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration:
                          l.cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (l.cancelled)
                  DeskChip(
                    key: Key('state-${l.lineId}'),
                    text: 'Cancelled',
                    color: const Color(0xFF9E9E9E),
                  )
                else
                  DeskChip(
                    key: Key('state-${l.lineId}'),
                    text: l.state.label,
                    color: serviceStateColor(l.state),
                  ),
              ],
            ),
            if (showTable && tableLine.isNotEmpty)
              InkWell(
                key: Key('table-link-${l.lineId}'),
                onTap: onOpenTable,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(tableLine, style: theme.textTheme.bodyMedium),
                ),
              ),
            if (showTable && l.confirmationCode != null)
              Text(
                l.confirmationCode!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                DeskChip(
                  key: Key('payment-${l.lineId}'),
                  text: l.payment.label,
                  color: linePaymentColor(l.payment),
                ),
                if (l.isAddon)
                  DeskChip(
                    key: Key('addon-${l.lineId}'),
                    text: 'Added at the table',
                    color: const Color(0xFF9E9E9E),
                  ),
                if (manager &&
                    showTable &&
                    !l.cancelled &&
                    l.serverMembershipId == null)
                  DeskChip(
                    key: Key('no-server-${l.lineId}'),
                    text: 'No server',
                    color: const Color(0xFFEF5350),
                  ),
                Text(
                  formatDollars(l.lineTotalCents),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (sign != null)
              LineSignBar(sign: sign!, title: l.title, manager: manager, bookingId: l.bookingId, onChanged: onSignChanged ?? () {}),
            if (l.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Cancelled${l.cancellationReason == null ? '' : ': ${l.cancellationReason}'}',
                  key: Key('cancelled-${l.lineId}'),
                  style: theme.textTheme.bodySmall,
                ),
              )
            else if (!l.delivered)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Waiting ${waitedLabel(l.orderedAt, now)}',
                  key: Key('waiting-${l.lineId}'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (deliveredLabel(l) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(deliveredLabel(l)!, key: Key('delivered-count-${l.lineId}'), style: theme.textTheme.bodyMedium),
              ),
            if (block != null && !l.delivered && !l.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  block,
                  key: Key('blocked-${l.lineId}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFFB300),
                  ),
                ),
              ),
            if (primary != null || menu.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (primary != null)
                      FilledButton(
                        key: Key('move-${l.lineId}'),
                        onPressed:
                            busy ||
                                    (primary == ServiceState.served &&
                                        block != null) ||
                                    stoppedBySign(primary)
                                ? null
                                : () => onMove(primary),
                        child: Text(primary.moveLabel),
                      ),
                    if (onDeliverPart != null && canDeliverPart(l))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton(
                          key: Key('deliver-part-${l.lineId}'),
                          onPressed: busy || block != null || signStops ? null : onDeliverPart,
                          child: const Text('Deliver some'),
                        ),
                      ),
                    const Spacer(),
                    if (menu.isNotEmpty)
                      PopupMenuButton<ServiceState>(
                        key: Key('more-${l.lineId}'),
                        tooltip: 'Set another status',
                        enabled: !busy,
                        onSelected: onMove,
                        itemBuilder:
                            (_) => [
                              for (final s in menu)
                                PopupMenuItem(
                                  key: Key('move-${l.lineId}-${s.value}'),
                                  value: s,
                                  enabled:
                                      !(s == ServiceState.served &&
                                          block != null) &&
                                      !stoppedBySign(s),
                                  child: Text(
                                    s == ServiceState.awaitingPrep ||
                                            s.index < l.state.index
                                        ? 'Back to ${s.label}'
                                        : s.moveLabel,
                                  ),
                                ),
                            ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
