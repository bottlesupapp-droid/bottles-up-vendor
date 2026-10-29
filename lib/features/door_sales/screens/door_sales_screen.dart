import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Door Sales (door role): sell a ticket to a guest at the door and check them in once. The flow is the brief's: ticket type, guest details, payment, confirm, issue. BottlesUp takes no payment
/// here: the person records how the guest paid (cash, or the club's own card machine with its receipt number) and confirms that the money is in hand.
///
/// Safe against a double tap and a lost answer: while a sale is being made the buttons are off, and the sale carries a key that is kept until it succeeds, so sending it again returns the
/// sale already made instead of selling twice. Any change to the sale gets a new key. Nothing is emailed from here; an email address is only kept with the sale.
class DoorSalesScreen extends ConsumerStatefulWidget {
  const DoorSalesScreen({super.key, required this.membershipId});

  final String membershipId;

  @override
  ConsumerState<DoorSalesScreen> createState() => _DoorSalesScreenState();
}

class _DoorSalesScreenState extends ConsumerState<DoorSalesScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _reference = TextEditingController();

  String? _tierId;
  int _quantity = 1;
  DoorPayMethod? _method;
  bool _busy = false;
  String? _problem;
  DoorSale? _done;
  DoorPayMethod? _doneMethod;
  String? _key;
  String? _keyPrint;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _reference.dispose();
    super.dispose();
  }

  SaleOption? _chosen(List<SaleOption> options) {
    for (final o in options) {
      if (o.tierId == _tierId) return o;
    }
    return null;
  }

  void _choose(SaleOption option) {
    setState(() {
      _tierId = option.tierId;
      if (_quantity > option.maxQuantity) _quantity = option.maxQuantity < 1 ? 1 : option.maxQuantity;
      _problem = null;
    });
  }

  String? _validate(SaleOption? option) => validateSale(
        option: option,
        quantity: _quantity,
        method: _method,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        reference: _method?.needsReference == true ? _reference.text : '',
      );

  Future<void> _review(DoorEvent event, SaleOption? option) async {
    if (_busy) return;
    final problem = _validate(option);
    setState(() => _problem = problem);
    if (problem != null || option == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('sale-confirm-dialog'),
        title: const Text('Confirm the sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(saleSummaryLine(option, _quantity, _method!), key: const Key('sale-confirm-line'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('For ${_name.text.trim()}', key: const Key('sale-confirm-guest')),
            if (_method!.needsReference) Text('Receipt number ${_reference.text.trim()}', key: const Key('sale-confirm-reference')),
            const SizedBox(height: 12),
            const Text('Only confirm once the money is in your hand or on the card machine\'s receipt. The ticket is issued and the guests are checked in right away.'),
          ],
        ),
        actions: [
          TextButton(key: const Key('sale-confirm-cancel'), onPressed: () => Navigator.of(context).pop(false), child: const Text('Not yet')),
          FilledButton(key: const Key('sale-confirm'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, issue the ticket')),
        ],
      ),
    );
    if (ok == true && mounted) await _submit(event, option);
  }

  Future<void> _submit(DoorEvent event, SaleOption option) async {
    if (_busy) return;
    final method = _method!;
    final fingerprint = saleFingerprint(
      eventId: event.eventId,
      tierId: option.tierId,
      quantity: _quantity,
      method: method,
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      reference: method.needsReference ? _reference.text : '',
    );
    // The same sale tried again keeps its key (so a lost answer cannot become a second sale); any change is a different sale.
    if (_key == null || _keyPrint != fingerprint) {
      _key = ref.read(saleKeyMakerProvider)();
      _keyPrint = fingerprint;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final sale = await ref.read(doorSalesServiceProvider).sell(
            eventId: event.eventId,
            tierId: option.tierId,
            quantity: _quantity,
            method: method,
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            reference: method.needsReference ? _reference.text : '',
            key: _key!,
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      _key = null;
      _keyPrint = null;
      setState(() {
        _busy = false;
        _done = sale;
        _doneMethod = method;
      });
      ref.invalidate(doorEventsProvider(widget.membershipId));
      ref.invalidate(saleOptionsProvider(event.eventId));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
      // What is left may have changed under the person's hands: read it again.
      ref.invalidate(saleOptionsProvider(event.eventId));
    }
  }

  void _another() {
    setState(() {
      _done = null;
      _doneMethod = null;
      _quantity = 1;
      _problem = null;
      _name.clear();
      _email.clear();
      _phone.clear();
      _reference.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(doorEventsProvider(widget.membershipId));
    return events.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DoorMessage(
        text: error is DoorLoadException ? error.message : doorLoadMessage(unavailable: false, accessEnded: false),
        onRetry: error is DoorLoadException && error.unavailable ? null : () => ref.invalidate(doorEventsProvider(widget.membershipId)),
      ),
      data: (list) {
        final event = resolveEvent(list, ref.watch(selectedDoorEventProvider(widget.membershipId)));
        if (event == null) {
          return DoorMessage(text: 'No event to sell tickets for right now.', onRetry: () => ref.invalidate(doorEventsProvider(widget.membershipId)));
        }
        return _body(list, event);
      },
    );
  }

  Widget _body(List<DoorEvent> events, DoorEvent event) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        DoorEventBar(
          events: events,
          selected: event,
          onSelect: (id) {
            if (_busy) return;
            ref.read(selectedDoorEventProvider(widget.membershipId).notifier).state = id;
            setState(() {
              _tierId = null;
              _quantity = 1;
              _problem = null;
              _done = null;
              _key = null;
              _keyPrint = null;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_done != null)
          _SaleDone(sale: _done!, method: _doneMethod!, onAnother: _another)
        else
          _form(event),
      ],
    );
  }

  Widget _form(DoorEvent event) {
    final theme = Theme.of(context);
    final options = ref.watch(saleOptionsProvider(event.eventId));
    return options.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      // A failed re-read after a sale keeps the form the person is working in; only a first load that fails shows the failure.
      skipError: true,
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (error, _) {
        final e = opsLoadFailureFor(error, 'ticket types');
        return Column(children: [
          Text(e.message, key: const Key('sale-load-error'), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (!e.unavailable) OutlinedButton(key: const Key('sale-retry'), onPressed: () => ref.invalidate(saleOptionsProvider(event.eventId)), child: const Text('Try again')),
        ]);
      },
      data: (data) {
        if (data.closed) return Text(salesClosedMessage, key: const Key('sale-closed'), style: theme.textTheme.bodyLarge);
        if (data.options.isEmpty) {
          return Text('This event has no ticket types you can sell at the door.', key: const Key('sale-none'), style: theme.textTheme.bodyLarge);
        }
        final option = _chosen(data.options);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Ticket type', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final o in data.options) _TierCard(option: o, selected: o.tierId == _tierId, enabled: !_busy, onTap: () => _choose(o)),
            if (option != null && !option.soldOut) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('How many?'),
                  const Spacer(),
                  IconButton(
                    key: const Key('sale-qty-minus'),
                    onPressed: _busy || _quantity <= 1 ? null : () => setState(() => _quantity--),
                    icon: const Icon(Ionicons.remove_circle_outline),
                  ),
                  Text('$_quantity', key: const Key('sale-qty'), style: theme.textTheme.titleLarge),
                  IconButton(
                    key: const Key('sale-qty-plus'),
                    onPressed: _busy || _quantity >= option.maxQuantity ? null : () => setState(() => _quantity++),
                    icon: const Icon(Ionicons.add_circle_outline),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('2. Guest details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('sale-name'),
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: guestNameMax,
              decoration: const InputDecoration(labelText: 'Guest name (required)', border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('sale-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('sale-phone'),
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            Text('The email and phone are only kept with the sale. No ticket is emailed or texted from here.', key: const Key('sale-contact-note'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            Text('3. How did the guest pay?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<DoorPayMethod>(
              key: const Key('sale-method'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final m in DoorPayMethod.values) ButtonSegment(value: m, label: Text(m.label, key: Key('sale-method-${m.db}'))),
              ],
              selected: {if (_method != null) _method!},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                        _method = s.isEmpty ? null : s.first;
                        _problem = null;
                      }),
            ),
            if (_method != null) ...[
              const SizedBox(height: 6),
              Text(_method!.hint, key: const Key('sale-method-hint'), style: theme.textTheme.bodySmall),
            ],
            if (_method?.needsReference == true) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('sale-reference'),
                controller: _reference,
                enabled: !_busy,
                maxLength: receiptMax,
                decoration: const InputDecoration(labelText: 'Card machine receipt number (required)', border: OutlineInputBorder(), counterText: ''),
              ),
            ],
            const SizedBox(height: 20),
            if (option != null && _method != null)
              Text(saleSummaryLine(option, _quantity, _method!), key: const Key('sale-summary'), style: theme.textTheme.titleMedium),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('sale-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('sale-submit'),
              onPressed: _busy ? null : () => _review(event, option),
              child: Text(_busy ? 'Issuing...' : 'Review and issue the ticket'),
            ),
            const SizedBox(height: 8),
            Text('Approved discounts and promo codes are not part of door sales yet.', key: const Key('sale-no-discounts'), style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.option, required this.selected, required this.enabled, required this.onTap});

  final SaleOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usable = enabled && !option.soldOut;
    return Card(
      key: Key('sale-tier-${option.tierId}'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: usable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.name, style: theme.textTheme.titleMedium?.copyWith(color: option.soldOut ? theme.disabledColor : null)),
                    Text(option.leftLabel, key: Key('sale-left-${option.tierId}'), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(option.priceLabel, key: Key('sale-price-${option.tierId}'), style: theme.textTheme.titleMedium),
              if (selected) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Ionicons.checkmark_circle, key: Key('sale-selected'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleDone extends StatelessWidget {
  const _SaleDone({required this.sale, required this.method, required this.onAnother});

  final DoorSale sale;
  final DoorPayMethod method;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guests = sale.quantity == 1 ? '1 guest is' : '${sale.quantity} guests are';
    return Card(
      key: const Key('sale-done'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Ionicons.checkmark_circle, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(sale.repeated ? 'This sale was already made' : 'Ticket issued', key: const Key('sale-done-title'), style: theme.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 12),
            SelectableText(sale.ticketCode, key: const Key('sale-done-code'), style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text('${sale.quantity} × ${sale.tierName} · ${sale.amountCents == 0 ? 'Free' : formatDollars(sale.amountCents)} · ${method.label}', key: const Key('sale-done-line')),
            const SizedBox(height: 8),
            Text(
              sale.repeated
                  ? '$guests checked in. Nothing new was recorded: the sale had already gone through.'
                  : '$guests checked in. The ticket cannot be scanned again. No ticket was emailed or texted.',
              key: const Key('sale-done-note'),
            ),
            if (!sale.repeated) ...[
              const SizedBox(height: 4),
              Text(sale.available == 1 ? '1 ticket of this type is left.' : '${sale.available} tickets of this type are left.', key: const Key('sale-done-left'), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            FilledButton(key: const Key('sale-another'), onPressed: onAnother, child: const Text('Sell another ticket')),
          ],
        ),
      ),
    );
  }
}
