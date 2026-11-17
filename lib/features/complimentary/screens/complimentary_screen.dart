import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../inventory/logic/inventory_rules.dart' show StockItem;
import '../../inventory/providers/inventory_providers.dart';
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../logic/complimentary_rules.dart';
import '../providers/complimentary_providers.dart';
import '../widgets/offer_dialog.dart';

BuTone _tone(OfferTone t) => switch (t) {
  OfferTone.neutral => BuTone.neutral,
  OfferTone.attention => BuTone.attention,
  OfferTone.good => BuTone.good,
  OfferTone.bad => BuTone.bad,
};

/// Complimentary bottles (brief section 20): the offers the club has made, a form for a new one, and the steps from there: place the recipient at a table, accept at their booking (an ordinary free bottle
/// under the club's limits), mark delivered, or cancel. The owner and the manager. Nothing is sent: the e-mail with the claim link is not switched on, and the page says so.
class ComplimentaryScreen extends ConsumerStatefulWidget {
  const ComplimentaryScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<ComplimentaryScreen> createState() => _ComplimentaryScreenState();
}

class _ComplimentaryScreenState extends ConsumerState<ComplimentaryScreen> {
  String? _chosenVenue;
  bool _busy = false;

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _refresh() => ref.invalidate(offersProvider(_venueId ?? ''));

  /// One step. A refusal is the database's own sentence; either way the list is read again so it shows what is true now.
  Future<void> _run(Future<String> Function() step) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _say(await step());
    } on OpsActionException catch (e) {
      _say(e.message);
    } on OpsLoadException catch (e) {
      _say(e.message);
    } finally {
      _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final venue = _venueId;
    if (venue == null) return;
    List<StockItem> bottles;
    try {
      bottles = await ref.read(inventoryServiceProvider).list(venue);
    } on OpsLoadException catch (e) {
      _say(e.message);
      return;
    }
    if (!mounted) return;
    final draft = await showOfferDialog(context, bottles: bottles);
    if (draft == null || !mounted) return;
    await _run(() async {
      await ref.read(complimentaryServiceProvider).create(venue, draft);
      return 'The offer is made. Nothing has been sent: place and accept it by hand for now.';
    });
  }

  Future<void> _place(OfferRow o) async {
    final venue = _venueId;
    if (venue == null) return;
    List<OfferTable> tables;
    try {
      tables = await ref.read(complimentaryServiceProvider).tables(venue);
    } on OpsLoadException catch (e) {
      _say(e.message);
      return;
    }
    if (!mounted) return;
    final picked = await showDialog<OfferTable>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Where is the recipient?'),
            children: [
              if (tables.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('This club has no tables yet.', key: Key('offer-no-tables'))),
              for (final t in tables) SimpleDialogOption(key: Key('offer-table-${t.id}'), onPressed: () => Navigator.of(ctx).pop(t), child: Text(t.label)),
            ],
          ),
    );
    if (picked == null || !mounted) return;
    await _run(() async {
      await ref.read(complimentaryServiceProvider).setLocation(o.id, picked.id);
      return 'Placed at ${picked.name}. Now choose the booking.';
    });
  }

  Future<void> _accept(OfferRow o) async {
    List<OfferBooking> bookings;
    try {
      bookings = await ref.read(complimentaryServiceProvider).bookings(o.id, currentNight(widget.clock()));
    } on OpsLoadException catch (e) {
      _say(e.message);
      return;
    }
    if (!mounted) return;
    final picked = await showDialog<OfferBooking>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: Text('Which booking at ${o.locationName ?? 'that table'}?'),
            children: [
              if (bookings.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('There is no confirmed booking at ${o.locationName ?? 'that table'} tonight.', key: const Key('offer-no-bookings'))),
              for (final b in bookings) SimpleDialogOption(key: Key('offer-booking-${b.id}'), onPressed: () => Navigator.of(ctx).pop(b), child: Text(b.label)),
            ],
          ),
    );
    if (picked == null || !mounted) return;
    await _run(() async {
      final out = await ref.read(complimentaryServiceProvider).accept(o.id, picked.id);
      return out.pending ? 'Accepted. The free bottle is over the club\'s limit, so it waits for the owner to approve it.' : 'Accepted. A free bottle is on ${picked.guestName}\'s booking.';
    });
  }

  Future<void> _delivered(OfferRow o) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Mark as delivered?'),
            content: Text('${o.item} for ${o.recipient} has reached the table.', key: const Key('offer-confirm-message')),
            actions: [
              TextButton(key: const Key('confirm-back'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
              FilledButton(key: const Key('confirm-yes'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delivered')),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await ref.read(complimentaryServiceProvider).markDelivered(o.id);
      return 'Marked as delivered.';
    });
  }

  Future<void> _cancel(OfferRow o) async {
    final reason = await showTextDialog(
      context,
      title: 'Cancel this offer?',
      hint: 'Why?',
      message: 'The link stops working. ${o.item} for ${o.recipient}.',
      confirmLabel: 'Cancel the offer',
      validate: checkCancelReason,
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      await ref.read(complimentaryServiceProvider).cancel(o.id, reason);
      return 'The offer is cancelled.';
    });
  }

  Future<void> _open(OfferRow o) async {
    final theme = Theme.of(context);
    final info = offerStatusInfo(o.status);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(o.item, key: const Key('offer-sheet-item'), style: theme.textTheme.titleMedium),
                Text(o.recipient, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('${info.label}${info.note.isEmpty ? '' : ' · ${info.note}'}', key: const Key('offer-sheet-status'), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('Why: ${o.reason}', style: theme.textTheme.bodySmall),
                if (o.sign != null) Text('Sign: ${o.sign}', style: theme.textTheme.bodySmall),
                if (o.locationName != null)
                  Text('Place: ${o.locationName} (chosen by ${o.locationSetBy == 'recipient' ? 'the recipient' : 'staff'})', key: const Key('offer-sheet-place'), style: theme.textTheme.bodySmall),
                if (concessionNote(o.concessionStatus) != null) Text(concessionNote(o.concessionStatus)!, key: const Key('offer-sheet-concession'), style: theme.textTheme.bodySmall),
                if (o.expiresAt != null) Text('Expires ${DateFormat('EEE d MMM, HH:mm').format(o.expiresAt!.toLocal())}', style: theme.textTheme.bodySmall),
                Text('Worth ${(o.valueCents / 100).toStringAsFixed(2)} at list price: recorded as complimentary, never as a sale.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                if (o.actions.isEmpty) Text('Nothing more to do here.', key: const Key('offer-sheet-nothing'), style: theme.textTheme.bodySmall),
                for (final (a, label) in [('set_location', 'Place at a table'), ('accept', 'Accept at a booking'), ('mark_delivered', 'Mark as delivered'), ('cancel', 'Cancel the offer')])
                  if (o.can(a)) Padding(padding: const EdgeInsets.only(bottom: 8), child: FilledButton(key: Key('offer-action-$a'), onPressed: () => Navigator.of(ctx).pop(a), child: Text(label))),
              ],
            ),
          ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'set_location':
        await _place(o);
      case 'accept':
        await _accept(o);
      case 'mark_delivered':
        await _delivered(o);
      case 'cancel':
        await _cancel(o);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = _venueId;
    if (venueId == null) {
      return VenuePicker(
        workspace: widget.workspace,
        title: 'Complimentary bottles',
        listKey: const Key('offers-pick-club'),
        itemKeyPrefix: 'offers-club-',
        onPick: (id) => setState(() => _chosenVenue = id),
      );
    }
    final offers = ref.watch(offersProvider(venueId));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('offers-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl),
        children: [
          BuPageHeader(
            eyebrow: 'Discounts and complimentary',
            title: 'Complimentary bottles',
            trailing: TextButton(key: const Key('offer-new'), onPressed: _busy ? null : _create, child: const Text('New offer')),
          ),
          if (widget.workspace.venueId != null && widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          if (widget.workspace.venueId == null) TextButton(key: const Key('offers-change-club'), onPressed: () => setState(() => _chosenVenue = null), child: const Text('Choose another club')),
          const SizedBox(height: BuSpace.m),
          BuCard(child: Text(claimNote, key: const Key('offers-note'), style: theme.textTheme.bodyMedium)),
          const SizedBox(height: BuSpace.l),
          OpsAsyncView<List<OfferRow>>(
            value: offers,
            what: 'the offers',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No offers yet. Make one with New offer.',
            emptyKey: const Key('offers-empty'),
            errorKey: const Key('offers-error'),
            onRetry: _refresh,
            builder:
                (rows) => BuListCard(
                  children: [
                    for (final o in rows)
                      BuListRow(
                        key: Key('offer-${o.id}'),
                        title: o.item,
                        subtitle: '${o.recipient}\n${offerStatusInfo(o.status).note}${o.locationName == null ? '' : ' · ${o.locationName}'}',
                        maxSubtitleLines: 3,
                        trailing: BuStatusPill(offerStatusInfo(o.status).label, key: Key('offer-status-${o.id}'), tone: _tone(offerStatusInfo(o.status).tone)),
                        onTap: () => _open(o),
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
