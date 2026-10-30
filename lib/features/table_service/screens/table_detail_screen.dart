import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/bottle_orders_rules.dart';
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';
import '../widgets/deliver_part_dialog.dart';
import '../widgets/order_card.dart';
import '../widgets/payment_tile.dart';
import '../widgets/receipt_view.dart';
import 'add_bottles_screen.dart';
import 'record_payment_screen.dart';
import '../../seating/widgets/seating_panel.dart';
import '../../booking_detail/widgets/booking_sign_card.dart';
import '../../booking_detail/widgets/booking_activity_tab.dart';
import '../../booking_detail/widgets/booking_guests_tab.dart';
import '../../discounts/widgets/booking_discounts_card.dart';
import '../../refunds/widgets/refund_booking_card.dart';
import '../../table_map/widgets/booking_terms_card.dart';

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

  Future<void> _addBottles(BookingMoney money) async {
    final result = await Navigator.of(context).push<AddedBottles>(
      MaterialPageRoute(builder: (_) => AddBottlesScreen(bookingId: widget.bookingId, tableLabel: widget.title.isEmpty ? money.tableName : widget.title)),
    );
    if (!mounted) return;
    // Whatever happened, the table's total and its orders are read again.
    _reload();
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(addedMessage(result.count, result.subtotalCents))));
    }
  }

  Future<void> _deliverPart(OrderLine l) async {
    if (_busy.contains(l.lineId)) return;
    final n = await showDialog<int>(context: context, builder: (_) => DeliverPartDialog(line: l));
    if (n == null || !mounted) return;
    setState(() => _busy.add(l.lineId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(tableServiceServiceProvider).deliverPart(l, n);
      messenger.showSnackBar(SnackBar(content: Text(deliveryOutcomeMessage(l, r))));
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

  /// Every tab scrolls and pulls to refresh the same way.
  Widget _scroll(List<Widget> children, {Key? key}) => RefreshIndicator(
        onRefresh: () async {
          _reload();
          try {
            await ref.read(bookingMoneyProvider(widget.bookingId).future);
          } catch (_) {
            // The screen shows the failure itself.
          }
        },
        child: ListView(
          key: key,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: children,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(bookingMoneyProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? 'Table' : widget.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: money.when(
        loading: () => _scroll(const [Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator()))]),
        error: (error, _) {
          final e = loadFailureFor(error, 'payments');
          return _scroll([
            SeatingPanel(bookingId: widget.bookingId, title: widget.title, canUnseat: false),
            Column(
              children: [
                Text(e.message, key: const Key('detail-error'), textAlign: TextAlign.center),
                if (!e.unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton(key: const Key('detail-retry'), onPressed: _reload, child: const Text('Try again')),
                  ),
              ],
            ),
          ]);
        },
        data: (m) => _tabs(context, m),
      ),
    );
  }

  /// The tabs a person gets follow how they stand towards this table (the database says): a manager or owner all five, the server of the table
  /// all but Activity, a payment verifier only the money.
  Widget _tabs(BuildContext context, BookingMoney m) {
    final theme = Theme.of(context);
    final now = widget.clock();
    final withOrders = m.level != 'verifier';
    final withGuests = m.level == 'manager' || m.level == 'server';
    final withActivity = m.level == 'manager';
    final tabs = <(String, String, Widget)>[
      ('Overview', 'tab-overview', _overview(m, theme)),
      if (withOrders) ('Orders', 'tab-orders', _ordersTab(m, now, theme)),
      ('Payments', 'tab-payments', _paymentsTab(m, now, theme)),
      if (withGuests) ('Guests', 'tab-guests', BookingGuestsTab(bookingId: widget.bookingId)),
      if (withActivity) ('Activity', 'tab-activity', BookingActivityTab(bookingId: widget.bookingId)),
    ];
    return DefaultTabController(
      key: ValueKey('tabs-${tabs.length}'),
      length: tabs.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.customerName, style: theme.textTheme.titleLarge),
                  Text('${m.tableName} · ${m.guestCount} ${m.guestCount == 1 ? 'guest' : 'guests'}', style: theme.textTheme.bodyMedium),
                  if (m.confirmationCode != null) Text(m.confirmationCode!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(key: Key(t.$2), text: t.$1)]),
          Expanded(child: TabBarView(children: [for (final t in tabs) t.$3])),
        ],
      ),
    );
  }

  Widget _overview(BookingMoney m, ThemeData theme) => _scroll([
        SeatingPanel(bookingId: widget.bookingId, title: widget.title, canUnseat: m.isManager),
        // The guest's sign is for the people who serve the table: the manager and its own server (the database refuses a payment verifier, so none is asked for).
        if (m.level == 'manager' || m.level == 'server') BookingSignCard(bookingId: widget.bookingId),
        Card(
          key: const Key('money-card'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text('Total', style: theme.textTheme.bodyMedium)), Text(formatDollars(m.totalCents), key: const Key('money-total'), style: theme.textTheme.bodyMedium)]),
                Row(children: [Expanded(child: Text('Collected', style: theme.textTheme.bodyMedium)), Text(formatDollars(m.paidCents), key: const Key('money-paid'), style: theme.textTheme.bodyMedium)]),
                const Divider(),
                Row(children: [Expanded(child: Text('Still due', style: theme.textTheme.titleMedium)), Text(formatDollars(m.balanceDueCents), key: const Key('money-due'), style: theme.textTheme.titleMedium)]),
                if (m.closedOut || m.closeoutRequested)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (m.closedOut) const DeskChip(key: Key('closed-out'), text: 'Closed out', color: Color(0xFF9E9E9E)),
                        if (m.closeoutRequested && !m.closedOut) const DeskChip(key: Key('closeout-requested'), text: 'Closing asked for', color: Color(0xFFFFB300)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        BookingTermsCard(bookingId: widget.bookingId, canMove: m.isManager && m.status == 'paid' && !m.closedOut, onMoved: _reload),
        const SizedBox(height: 8),
        if (m.isManager) ...[
          RefundBookingCard(bookingId: widget.bookingId, canCancel: m.status == 'paid' && !m.closedOut, onChanged: _reload),
          const SizedBox(height: 8),
        ],
        if (m.canRecord)
          FilledButton.icon(key: const Key('record-payment'), onPressed: () => _record(m), icon: const Icon(Icons.add_card_outlined), label: const Text('Record a payment'))
        else if (m.closedOut)
          Text('This table has been closed out. Nothing more can be recorded or changed.', key: const Key('closed-note'), style: theme.textTheme.bodySmall),
      ]);

  Widget _ordersTab(BookingMoney m, DateTime now, ThemeData theme) {
    final orders = ref.watch(tableOrdersProvider(TableOrdersQuery(widget.bookingId, m.balanceDueCents)));
    return _scroll([
      if (m.canRecord) ...[
        BookingDiscountsCard(bookingId: widget.bookingId, onChanged: _reload),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(child: Text('Bottle orders', style: theme.textTheme.titleMedium)),
          if (m.canRecord)
            OutlinedButton.icon(key: const Key('add-bottles'), onPressed: () => _addBottles(m), icon: const Icon(Icons.add, size: 18), label: const Text('Add bottles')),
        ],
      ),
      orders.when(
        loading: () => const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
        error: (error, _) {
          final e = loadFailureFor(error, 'orders');
          return Padding(padding: const EdgeInsets.only(top: 8), child: Text(e.message, key: const Key('detail-orders-error')));
        },
        data: (lines) => lines.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No bottle orders on this table.', key: const Key('detail-orders-empty'), style: theme.textTheme.bodyMedium),
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
                      onDeliverPart: () => _deliverPart(l),
                    ),
                ],
              ),
      ),
    ]);
  }

  Widget _paymentsTab(BookingMoney m, DateTime now, ThemeData theme) => _scroll([
        Text('Payments', style: theme.textTheme.titleMedium),
        if (m.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No payment has been recorded for this table.', key: const Key('detail-payments-empty'), style: theme.textTheme.bodyMedium),
          )
        else
          for (final p in m.payments) PaymentTile(payment: p, now: now, onViewReceipt: (path) => showReceipt(context, ref, path)),
        if (m.canRecord) ...[
          const SizedBox(height: 12),
          FilledButton.icon(key: const Key('record-payment-payments'), onPressed: () => _record(m), icon: const Icon(Icons.add_card_outlined), label: const Text('Record a payment')),
        ],
      ]);
}
