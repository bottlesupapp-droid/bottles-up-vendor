import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars, moneyInput, parseMoney;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';

/// Decide one waiting refund request (club manager or owner): approve an amount and say how it is paid back, or decline with a reason the guest can be told. The policy's suggestion is
/// filled in; more than that needs a reason. A refund to the card is returned by BottlesUp, one at the club is recorded once it has been paid. What was typed is kept when anything
/// fails. Pops with the message to show on success.
class DecideRefundSheet extends ConsumerStatefulWidget {
  const DecideRefundSheet({super.key, required this.request});

  final RefundRequest request;

  @override
  ConsumerState<DecideRefundSheet> createState() => _DecideRefundSheetState();
}

class _DecideRefundSheetState extends ConsumerState<DecideRefundSheet> {
  late final _amount = TextEditingController(text: widget.request.suggestedCents > 0 ? moneyInput(widget.request.suggestedCents) : '');
  final _note = TextEditingController();
  bool _approve = true;
  RefundMethod? _method;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  DecisionForm get _form => DecisionForm(approve: _approve, amountText: _amount.text, method: _method, note: _note.text);

  Future<void> _submit(RefundOptions? options) async {
    if (_busy) return;
    final r = widget.request;
    // Without the booking's details (they failed to load) a card refund cannot be checked here, so the database is left to say.
    final paidOnline = options?.paidOnline ?? true;
    final found = validateDecision(_form, r, paidOnline: paidOnline);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(refundServiceProvider).decide(r.requestId, _form, r, paidOnline: paidOnline);
      if (!mounted) return;
      Navigator.of(context).pop(decisionMessage(_approve, _method, _approve ? parseMoney(_amount.text) : null));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      // Whatever went wrong, what can still be refunded may be different: read it again, and keep what was typed.
      ref.invalidate(refundOptionsProvider(r.bookingId));
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.request;
    final options = ref.watch(refundOptionsProvider(r.bookingId));
    final loaded = options.asData?.value;
    final cardNote = loaded != null && !loaded.paidOnline ? 'There is no online payment on this booking, so it can only be paid back at the club.' : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('decide-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.guestName} · ${r.tableName}', style: theme.textTheme.titleLarge),
            if (r.code != null) Text(r.code!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text('${r.byGuest ? 'The guest asked' : 'Staff asked'}: ${r.reason}', key: const Key('decide-reason')),
            const SizedBox(height: 8),
            Text('Paid ${formatDollars(r.paidCents)} · can still be refunded ${formatDollars(r.availableCents)}', key: const Key('decide-money')),
            Text(suggestionLine(r), key: const Key('decide-suggestion'), style: theme.textTheme.bodySmall),
            if (loaded != null && arrivalLine(loaded.hoursToArrival).isNotEmpty) Text(arrivalLine(loaded.hoursToArrival), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('decide-kind'),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: true, label: Text('Approve')), ButtonSegment(value: false, label: Text('Decline'))],
              selected: {_approve},
              onSelectionChanged: _busy ? null : (s) => setState(() {
                    _approve = s.first;
                    _problems = const [];
                  }),
            ),
            const SizedBox(height: 12),
            if (_approve) ...[
              TextField(
                key: const Key('decide-amount'),
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount to refund (\$)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Text('How is it paid back?', style: theme.textTheme.titleSmall),
              RadioGroup<RefundMethod>(
                groupValue: _method,
                onChanged: (v) {
                  if (_busy || v == null) return;
                  if (v == RefundMethod.online && loaded != null && !loaded.paidOnline) return;
                  setState(() {
                    _method = v;
                    _problems = const [];
                  });
                },
                child: Column(
                  children: [
                    for (final m in RefundMethod.values)
                      RadioListTile<RefundMethod>(
                        key: Key('method-${m.db}'),
                        value: m,
                        contentPadding: EdgeInsets.zero,
                        enabled: !(m == RefundMethod.online && loaded != null && !loaded.paidOnline),
                        title: Text(m.label),
                        subtitle: Text(m == RefundMethod.online ? 'BottlesUp returns it through the payment provider. You do not move any money.' : 'You pay the guest at the club, then record it with the terminal or receipt reference.'),
                      ),
                  ],
                ),
              ),
              if (cardNote != null) Text(cardNote, key: const Key('decide-no-online'), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const Key('decide-note'),
              controller: _note,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _approve ? 'Note (needed if more than the policy suggests)' : 'Why is it declined? (the guest is told)',
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('decide-confirm'),
              onPressed: _busy ? null : () => _submit(loaded),
              child: Text(_busy ? 'Saving...' : (_approve ? 'Approve the refund' : 'Decline the refund')),
            ),
          ],
        ),
      ),
    );
  }
}
