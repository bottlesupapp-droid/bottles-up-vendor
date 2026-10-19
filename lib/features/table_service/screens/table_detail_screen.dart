import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';
import '../widgets/order_card.dart';
import '../widgets/payment_tile.dart';
import '../widgets/receipt_view.dart';
import 'record_payment_screen.dart';
import '../../seating/widgets/seating_panel.dart';

/// One table: what it was charged, what has been collected and what is still due, its bottle orders and the payments recorded for it,
/// with a way to record another. A manager or owner reaches any table of their club; a server only the ones they were given. The
/// database says how this person stands towards the table (`level`) and the buttons follow it.
class TableDetailScreen extends ConsumerStatefulWidget {
  const TableDetailScreen({
    super.key,
    required this.bookingId,
    required this.title,
    this.clock = DateTime.now,
  });

  final String bookingId;
  final String title;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;

  @override
  ConsumerState<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends ConsumerState<TableDetailScreen> {
  final Set<String> _busy = {};

  void _reload() {
    ref.invalidate(bookingMoneyProvider(widget.bookingId));
    ref.invalidate(tableOrdersProvider);
  }

  Future<void> _move(OrderLine l, ServiceState to) async {
    setState(() => _busy.add(l.lineId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref
          .read(tableServiceServiceProvider)
          .moveOrder(l.lineId, to);
      if (!changed) {
        messenger.showSnackBar(
          SnackBar(content: Text('It was already ${to.label.toLowerCase()}.')),
        );
      }
    } on TableServiceActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      _reload();
      if (mounted) setState(() => _busy.remove(l.lineId));
    }
  }

  Future<void> _record(BookingMoney money) async {
    final result = await Navigator.of(context).push<RecordedPayment>(
      MaterialPageRoute(
        builder:
            (_) => RecordPaymentScreen(
              bookingId: widget.bookingId,
              tableLabel: widget.title,
              balanceDueCents: money.balanceDueCents,
              manager: money.isManager,
            ),
      ),
    );
    if (!mounted) return;
    _reload();
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'That payment was already recorded.'
                : result.balanceDueCents > 0
                ? 'Payment recorded. ${formatDollars(result.balanceDueCents)} still due.'
                : 'Payment recorded. The table is paid up.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = ref.watch(bookingMoneyProvider(widget.bookingId));
    final now = widget.clock();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? 'Table' : widget.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          try {
            await ref.read(bookingMoneyProvider(widget.bookingId).future);
          } catch (_) {
            // The screen shows the failure itself.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            SeatingPanel(bookingId: widget.bookingId, title: widget.title, canUnseat: money.asData?.value.isManager ?? false),
            money.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, _) {
                final e = loadFailureFor(error, 'payments');
                return Column(
                  children: [
                    Text(
                      e.message,
                      key: const Key('detail-error'),
                      textAlign: TextAlign.center,
                    ),
                    if (!e.unavailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          key: const Key('detail-retry'),
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ),
                  ],
                );
              },
              data: (m) => _body(context, m, now, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    BookingMoney m,
    DateTime now,
    ThemeData theme,
  ) {
    final orders =
        m.level == 'verifier'
            ? null
            : ref.watch(
              tableOrdersProvider(
                TableOrdersQuery(widget.bookingId, m.balanceDueCents),
              ),
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(m.customerName, style: theme.textTheme.titleLarge),
        Text(
          '${m.tableName} · ${m.guestCount} ${m.guestCount == 1 ? 'guest' : 'guests'}',
          style: theme.textTheme.bodyMedium,
        ),
        if (m.confirmationCode != null)
          Text(
            m.confirmationCode!,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        const SizedBox(height: 12),
        Card(
          key: const Key('money-card'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Total', style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      formatDollars(m.totalCents),
                      key: const Key('money-total'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Collected',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      formatDollars(m.paidCents),
                      key: const Key('money-paid'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Still due',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatDollars(m.balanceDueCents),
                      key: const Key('money-due'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                if (m.closedOut || m.closeoutRequested)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (m.closedOut)
                          const DeskChip(
                            key: Key('closed-out'),
                            text: 'Closed out',
                            color: Color(0xFF9E9E9E),
                          ),
                        if (m.closeoutRequested && !m.closedOut)
                          const DeskChip(
                            key: Key('closeout-requested'),
                            text: 'Closing asked for',
                            color: Color(0xFFFFB300),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (m.canRecord)
          FilledButton.icon(
            key: const Key('record-payment'),
            onPressed: () => _record(m),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Record a payment'),
          )
        else if (m.closedOut)
          Text(
            'This table has been closed out. Nothing more can be recorded or changed.',
            key: const Key('closed-note'),
            style: theme.textTheme.bodySmall,
          ),
        if (orders != null) ...[
          const SizedBox(height: 20),
          Text('Bottle orders', style: theme.textTheme.titleMedium),
          orders.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (error, _) {
              final e = loadFailureFor(error, 'orders');
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(e.message, key: const Key('detail-orders-error')),
              );
            },
            data:
                (lines) =>
                    lines.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No bottle orders on this table.',
                            key: const Key('detail-orders-empty'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                        : Column(
                          children: [
                            for (final l in lines)
                              OrderCard(
                                line: l,
                                now: now,
                                manager: m.isManager,
                                busy: _busy.contains(l.lineId),
                                showTable: false,
                                onMove: (to) => _move(l, to),
                              ),
                          ],
                        ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Payments', style: theme.textTheme.titleMedium),
        if (m.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No payment has been recorded for this table.',
              key: const Key('detail-payments-empty'),
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final p in m.payments)
            PaymentTile(
              payment: p,
              now: now,
              onViewReceipt: (path) => showReceipt(context, ref, path),
            ),
      ],
    );
  }
}
