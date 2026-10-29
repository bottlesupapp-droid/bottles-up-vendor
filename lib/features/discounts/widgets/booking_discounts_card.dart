import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../../server_desk/widgets/desk_chip.dart';
import '../../table_service/logic/bottle_orders_rules.dart' show MenuBottle;
import '../logic/discount_rules.dart';
import '../providers/discount_providers.dart';

/// Discounts and free bottles on one table (the table's server, a manager or the owner; brief 15 Oct, section 21). Within a person's own limit a discount or a free bottle is applied at
/// once and the table's total, stock and records follow; above it, it waits for a manager or the owner, and nobody approves their own. Until the owner has set limits, staff cannot give
/// their own. Every one is listed with who asked and who approved. Someone who may not give anything here (a payment verifier) sees nothing.
class BookingDiscountsCard extends ConsumerWidget {
  const BookingDiscountsCard({super.key, required this.bookingId, this.onChanged});

  final String bookingId;

  /// Called after something was given or taken back, so the page reads the table's money and orders again.
  final VoidCallback? onChanged;

  void _refresh(WidgetRef ref) {
    ref.invalidate(concessionLimitsProvider(bookingId));
    ref.invalidate(bookingConcessionsProvider(bookingId));
    ref.invalidate(freeBottleMenuProvider(bookingId));
  }

  Future<void> _give(BuildContext context, WidgetRef ref, Widget sheet) async {
    final message = await showModalBottomSheet<String>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => sheet);
    _refresh(ref);
    if (message == null || !context.mounted) return;
    onChanged?.call();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takeBack(BuildContext context, WidgetRef ref, Concession c) async {
    final done = await showDialog<bool>(context: context, builder: (_) => TakeBackDialog(concession: c));
    _refresh(ref);
    if (done != true || !context.mounted) return;
    onChanged?.call();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Taken back: ${concessionLine(c)}.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final limits = ref.watch(concessionLimitsProvider(bookingId));
    return limits.when(
      loading: () => const Card(key: Key('discounts-card'), child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())),
      error: (error, _) {
        final e = opsLoadFailureFor(error, 'the discounts');
        // Someone who may not give anything on this table (a payment verifier) is not shown a card they cannot use.
        if (e.accessEnded) return const SizedBox.shrink(key: Key('discounts-hidden'));
        return Card(
          key: const Key('discounts-card'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discounts and free bottles', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(e.message, key: const Key('discounts-card-error')),
                if (!e.unavailable) TextButton(key: const Key('discounts-card-retry'), onPressed: () => _refresh(ref), child: const Text('Try again')),
              ],
            ),
          ),
        );
      },
      data: (l) {
        final given = ref.watch(bookingConcessionsProvider(bookingId));
        final list = given.asData?.value ?? const <Concession>[];
        final canGive = l.isOwner || l.limitsSet;
        return Card(
          key: const Key('discounts-card'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discounts and free bottles', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(limitsLine(l), key: const Key('discounts-limits')),
                if (l.discountedCents > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Discounted so far: ${formatDollars(l.discountedCents)}', key: const Key('discounts-so-far'), style: theme.textTheme.bodySmall)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('give-discount'),
                      onPressed: canGive ? () => _give(context, ref, GiveDiscountSheet(bookingId: bookingId, limits: l, existing: list)) : null,
                      icon: const Icon(Icons.percent, size: 18),
                      label: const Text('Give a discount'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('give-free-bottle'),
                      onPressed: canGive ? () => _give(context, ref, GiveFreeBottleSheet(bookingId: bookingId, limits: l)) : null,
                      icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                      label: const Text('Give a free bottle'),
                    ),
                  ],
                ),
                if (given.hasError)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('We could not load what has been given on this table.', key: const Key('discounts-list-error'), style: theme.textTheme.bodySmall)),
                for (final c in list)
                  Padding(
                    key: Key('concession-${c.id}'),
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(concessionLine(c), style: theme.textTheme.titleSmall)),
                            DeskChip(key: Key('concession-status-${c.id}'), text: c.status.label, color: _color(c.status)),
                          ],
                        ),
                        Text('${c.reason} · ${DateFormat('MMM d, HH:mm').format(c.createdAt)}', style: theme.textTheme.bodySmall),
                        Text(concessionWho(c), key: Key('concession-who-${c.id}'), style: theme.textTheme.bodySmall),
                        if (c.canTakeBack && l.role != GiverRole.server)
                          Align(alignment: Alignment.centerRight, child: TextButton(key: Key('take-back-${c.id}'), onPressed: () => _takeBack(context, ref, c), child: const Text('Take back'))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _color(ConcessionStatus s) => switch (s) {
        ConcessionStatus.applied => const Color(0xFF66BB6A),
        ConcessionStatus.pending => const Color(0xFFFFB300),
        ConcessionStatus.declined => const Color(0xFF9E9E9E),
        ConcessionStatus.voided => const Color(0xFFEF5350),
      };
}

/// A discount on the table's bottles, as a percent or an amount. Says before it is sent whether it will be applied at once or wait. Pops with the message to show.
class GiveDiscountSheet extends ConsumerStatefulWidget {
  const GiveDiscountSheet({super.key, required this.bookingId, required this.limits, required this.existing});

  final String bookingId;
  final ConcessionLimits limits;
  final List<Concession> existing;

  @override
  ConsumerState<GiveDiscountSheet> createState() => _GiveDiscountSheetState();
}

class _GiveDiscountSheetState extends ConsumerState<GiveDiscountSheet> {
  final _value = TextEditingController();
  final _reason = TextEditingController();
  DiscountKind _kind = DiscountKind.percent;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  DiscountForm get _form => DiscountForm(kind: _kind, valueText: _value.text, reason: _reason.text);

  /// What will happen, once what was typed is a discount that can be worked out and is allowed.
  String? get _preview {
    final l = widget.limits;
    final cents = l.bottleSubtotalCents <= 0 ? null : discountCents(_form, l.bottleSubtotalCents);
    if (cents == null || cents < 1 || cents > l.bottleSubtotalCents) return null;
    return discountPreview(l, cents);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final found = validateDiscount(_form, widget.limits, widget.existing);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(discountServiceProvider).giveDiscount(widget.bookingId, _form, widget.limits, widget.existing);
      if (!mounted) return;
      Navigator.of(context).pop(discountGivenMessage(r, widget.limits));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      // Whatever went wrong, the table's total and what it carries may be different: read them again, and keep what was typed.
      ref.invalidate(concessionLimitsProvider(widget.bookingId));
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.limits;
    final preview = _preview;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('discount-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give a discount', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('On the table\'s bottles: ${formatDollars(l.bottleSubtotalCents)}. The table still owes ${formatDollars(l.balanceDueCents)}.', key: const Key('discount-base')),
            const SizedBox(height: 12),
            SegmentedButton<DiscountKind>(
              key: const Key('discount-kind'),
              showSelectedIcon: false,
              segments: [for (final k in DiscountKind.values) ButtonSegment(value: k, label: Text(k.label))],
              selected: {_kind},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                        _kind = s.first;
                        _value.clear();
                        _problems = const [];
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('discount-value'),
              controller: _value,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _problems = const []),
              decoration: InputDecoration(labelText: _kind == DiscountKind.percent ? 'Percent off (1 to 100)' : 'Amount off (\$)', border: const OutlineInputBorder()),
            ),
            if (preview != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(preview, key: const Key('discount-preview'), style: theme.textTheme.bodySmall)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('discount-reason'),
              controller: _reason,
              enabled: !_busy,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Reason', helperText: 'Kept with who gave it and who approved it.', border: OutlineInputBorder(), counterText: ''),
            ),
            if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
            const SizedBox(height: 12),
            FilledButton(key: const Key('discount-confirm'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : 'Give the discount')),
          ],
        ),
      ),
    );
  }
}

/// A bottle given at no charge: a real bottle line at 0.00, served like any other and counted in stock; its list value is kept apart from sales. Says before it is sent whether it
/// is within the person's allowance for the night. Pops with the message to show.
class GiveFreeBottleSheet extends ConsumerStatefulWidget {
  const GiveFreeBottleSheet({super.key, required this.bookingId, required this.limits});

  final String bookingId;
  final ConcessionLimits limits;

  @override
  ConsumerState<GiveFreeBottleSheet> createState() => _GiveFreeBottleSheetState();
}

class _GiveFreeBottleSheetState extends ConsumerState<GiveFreeBottleSheet> {
  final _reason = TextEditingController();
  MenuBottle? _bottle;
  int _quantity = 1;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  FreeBottleForm get _form => FreeBottleForm(bottle: _bottle, quantity: _quantity, reason: _reason.text);

  Future<void> _submit() async {
    if (_busy) return;
    final found = validateFreeBottle(_form, widget.limits);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    final bottle = _bottle!;
    try {
      final r = await ref.read(discountServiceProvider).giveFreeBottle(widget.bookingId, _form, widget.limits);
      if (!mounted) return;
      Navigator.of(context).pop(freeBottleGivenMessage(r, widget.limits, bottle.title, _quantity));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      // The allowance used and the stock left may be different now: read them again, and keep what was typed.
      ref.invalidate(concessionLimitsProvider(widget.bookingId));
      ref.invalidate(freeBottleMenuProvider(widget.bookingId));
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = ref.watch(freeBottleMenuProvider(widget.bookingId));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('free-bottle-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give a free bottle', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('It is added to the table at no charge, served like any other order, and counted in stock. It is never counted as a sale.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            menu.when(
              loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              error: (error, _) {
                final e = opsLoadFailureFor(error, 'the bottles');
                return Column(
                  children: [
                    Text(e.message, key: const Key('free-bottle-error')),
                    if (!e.unavailable && !e.accessEnded) TextButton(key: const Key('free-bottle-retry'), onPressed: () => ref.invalidate(freeBottleMenuProvider(widget.bookingId)), child: const Text('Try again')),
                  ],
                );
              },
              data: (list) => list.isEmpty
                  ? Text('The club has no bottles on sale right now.', key: const Key('free-bottle-none'), style: theme.textTheme.bodyMedium)
                  : Column(
                      children: [
                        for (final b in list)
                          Card(
                            key: Key('free-bottle-${b.id}'),
                            color: b.id == _bottle?.id ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
                            child: ListTile(
                              enabled: !_busy && !b.soldOutByCount,
                              selected: b.id == _bottle?.id,
                              title: Text(b.title),
                              subtitle: Text('${formatDollars(b.priceCents)}${b.leftCount == null ? '' : ' · ${b.leftCount} left'}'),
                              trailing: b.id == _bottle?.id ? const Icon(Icons.check_circle) : null,
                              onTap: _busy || b.soldOutByCount
                                  ? null
                                  : () => setState(() {
                                        _bottle = b;
                                        if (_quantity > b.most && b.most > 0) _quantity = b.most;
                                        _problems = const [];
                                      }),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('How many')),
                IconButton(key: const Key('free-less'), onPressed: _busy || _quantity <= 1 ? null : () => setState(() => _quantity--), icon: const Icon(Icons.remove_circle_outline)),
                SizedBox(width: 32, child: Text('$_quantity', key: const Key('free-quantity'), textAlign: TextAlign.center)),
                IconButton(
                  key: const Key('free-more'),
                  onPressed: _busy || _quantity >= (_bottle?.most ?? maxFreeBottles) ? null : () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Text(freeBottlePreview(widget.limits, _quantity), key: const Key('free-preview'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const Key('free-reason'),
              controller: _reason,
              enabled: !_busy,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Reason', helperText: 'Kept with who gave it and who approved it.', border: OutlineInputBorder(), counterText: ''),
            ),
            if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
            const SizedBox(height: 12),
            FilledButton(key: const Key('free-confirm'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : 'Give the bottle')),
          ],
        ),
      ),
    );
  }
}

/// Takes an applied discount or free bottle back after asking why. A bottle that has already been served cannot be; the database says so. Pops true once done.
class TakeBackDialog extends ConsumerStatefulWidget {
  const TakeBackDialog({super.key, required this.concession});

  final Concession concession;

  @override
  ConsumerState<TakeBackDialog> createState() => _TakeBackDialogState();
}

class _TakeBackDialogState extends ConsumerState<TakeBackDialog> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    final problem = validateTakeBackNote(_note.text);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(discountServiceProvider).takeBack(widget.concession.id, _note.text);
      if (mounted) Navigator.of(context).pop(true);
    } on OpsActionException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.concession;
    return AlertDialog(
      title: Text('Take back ${concessionLine(c)}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.isDiscount ? 'The table owes the discounted amount again.' : 'The free bottle is cancelled, unless it has already been served.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('take-back-note'),
            controller: _note,
            enabled: !_busy,
            maxLength: 300,
            decoration: InputDecoration(labelText: 'Why is it taken back?', errorText: _problem, errorMaxLines: 3, border: const OutlineInputBorder(), counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('take-back-keep'), onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Keep it')),
        FilledButton(key: const Key('take-back-confirm'), onPressed: _busy ? null : _go, child: Text(_busy ? 'Saving...' : 'Take it back')),
      ],
    );
  }
}
