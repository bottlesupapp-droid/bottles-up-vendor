import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/settlement_adjustment_rules.dart';
import '../logic/settlement_rules.dart';

/// An amount and a sentence, checked before they are sent (the eligible bar sales and where they come from; an adjustment and why). Returns what was typed once [validate] accepts it, or null when the person
/// backs out. The caller reads the typed text again with the same check to get the cents.
Future<({String amount, String note})?> showMoneyNoteDialog(
  BuildContext context, {
  required String title,
  required String amountLabel,
  required String amountHint,
  required String noteLabel,
  required String noteHint,
  required String confirmLabel,
  required String? Function(String amount, String note) validate,
  String? message,
  String initialAmount = '',
}) {
  return showDialog<({String amount, String note})>(
    context: context,
    builder:
        (_) => _MoneyNoteDialog(
          title: title,
          message: message,
          amountLabel: amountLabel,
          amountHint: amountHint,
          noteLabel: noteLabel,
          noteHint: noteHint,
          confirmLabel: confirmLabel,
          validate: validate,
          initialAmount: initialAmount,
        ),
  );
}

class _MoneyNoteDialog extends StatefulWidget {
  const _MoneyNoteDialog({
    required this.title,
    required this.amountLabel,
    required this.amountHint,
    required this.noteLabel,
    required this.noteHint,
    required this.confirmLabel,
    required this.validate,
    required this.initialAmount,
    this.message,
  });

  final String title;
  final String? message;
  final String amountLabel;
  final String amountHint;
  final String noteLabel;
  final String noteHint;
  final String confirmLabel;
  final String? Function(String amount, String note) validate;
  final String initialAmount;

  @override
  State<_MoneyNoteDialog> createState() => _MoneyNoteDialogState();
}

class _MoneyNoteDialogState extends State<_MoneyNoteDialog> {
  late final _amount = TextEditingController(text: widget.initialAmount);
  final _note = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = widget.validate(_amount.text, _note.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop((amount: _amount.text.trim(), note: _note.text.trim()));
  }

  void _clear() {
    if (_problem != null) setState(() => _problem = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.message!, key: const Key('form-message'))),
            TextField(
              key: const Key('form-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(labelText: widget.amountLabel, hintText: widget.amountHint),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-note'),
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.noteLabel, hintText: widget.noteHint, errorText: _problem, errorMaxLines: 3),
              onChanged: (_) => _clear(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// What the owner typed to record a payment that was made outside BottlesUp.
typedef PaymentEntry = ({String amount, DateTime paidOn, String reference, String evidence});

/// How a payment form is checked: what was typed in, and the cents, reference and evidence it comes to, or the sentence that says what is wrong.
typedef PaymentCheck = ({int? cents, String? reference, String? evidence, String? error}) Function(String amount, String reference, String evidence);

/// Records a payment that was ALREADY made somewhere else: the exact amount (filled in), the day it was paid, a reference, and optionally a note about the evidence. Nothing is sent. By default it is the
/// settlement's approved amount; the adjustments after payment use it too, with their own words and their own check.
Future<PaymentEntry?> showPaymentDialog(
  BuildContext context, {
  required int payableCents,
  required String currency,
  required String recipient,
  DateTime Function() clock = DateTime.now,
  String title = 'Record the payment',
  String? message,
  String helper = 'Exactly what was approved',
  String confirmLabel = 'Record payment',
  PaymentCheck? check,
}) {
  return showDialog<PaymentEntry>(
    context: context,
    builder:
        (_) => _PaymentDialog(
          payableCents: payableCents,
          currency: currency,
          recipient: recipient,
          clock: clock,
          title: title,
          message: message ?? 'Only record a payment that has ALREADY been made to $recipient, outside BottlesUp. Nothing is sent from here.',
          helper: helper,
          confirmLabel: confirmLabel,
          check: check ?? ((a, r, e) => checkPaymentForm(a, r, e, payableCents: payableCents, currency: currency)),
        ),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.payableCents,
    required this.currency,
    required this.recipient,
    required this.clock,
    required this.title,
    required this.message,
    required this.helper,
    required this.confirmLabel,
    required this.check,
  });

  final int payableCents;
  final String currency;
  final String recipient;
  final DateTime Function() clock;
  final String title;
  final String message;
  final String helper;
  final String confirmLabel;
  final PaymentCheck check;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: '${widget.payableCents ~/ 100}.${(widget.payableCents % 100).toString().padLeft(2, '0')}');
  final _reference = TextEditingController();
  final _evidence = TextEditingController();
  late DateTime _paidOn = widget.clock();
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = widget.clock();
    final picked = await showDatePicker(context: context, initialDate: _paidOn, firstDate: DateTime(now.year - 2), lastDate: now, helpText: 'The day it was paid');
    if (picked != null) setState(() => _paidOn = picked);
  }

  void _confirm() {
    final checked = widget.check(_amount.text, _reference.text, _evidence.text);
    if (checked.error != null) {
      setState(() => _problem = checked.error);
      return;
    }
    Navigator.of(context).pop((amount: _amount.text.trim(), paidOn: _paidOn, reference: _reference.text.trim(), evidence: _evidence.text.trim()));
  }

  void _clear() {
    if (_problem != null) setState(() => _problem = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, key: const Key('form-message')),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount paid (${widget.currency.toUpperCase()})',
                helperText: '${widget.helper}: ${settlementMoney(widget.payableCents, currency: widget.currency)}',
              ),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('form-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Paid on ${DateFormat('EEE d MMM yyyy').format(_paidOn)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-reference'),
              controller: _reference,
              decoration: const InputDecoration(labelText: 'Reference', hintText: 'For example the transfer or cheque number'),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-evidence'),
              controller: _evidence,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Evidence (optional)', hintText: 'For example "bank confirmation kept"', errorText: _problem, errorMaxLines: 3),
              onChanged: (_) => _clear(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// A plain yes or no, with what will happen said first. True only when the person confirms.
Future<bool> confirmSettlementStep(BuildContext context, {required String title, required String message, required String confirmLabel}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message, key: const Key('confirm-message')),
          actions: [
            TextButton(key: const Key('confirm-back'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
            FilledButton(key: const Key('confirm-yes'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
          ],
        ),
  );
  return yes == true;
}

/// What the owner typed to record an adjustment after payment.
typedef AdjustmentEntry = ({String kind, String amount, String reason, String reference});

/// Records an adjustment after payment: what it is for (a refund, a chargeback or a correction), the amount, why, and an optional reference. Says first that it cannot be edited afterwards, and how much can
/// still be taken off. Returns what was typed once it passes the same check the database has, or null when the person backs out.
Future<AdjustmentEntry?> showAdjustmentRecordDialog(BuildContext context, {required int netCents, required String currency, String? initialKind}) {
  return showDialog<AdjustmentEntry>(context: context, builder: (_) => _AdjustmentRecordDialog(netCents: netCents, currency: currency, initialKind: initialKind));
}

class _AdjustmentRecordDialog extends StatefulWidget {
  const _AdjustmentRecordDialog({required this.netCents, required this.currency, this.initialKind});

  final int netCents;
  final String currency;
  final String? initialKind;

  @override
  State<_AdjustmentRecordDialog> createState() => _AdjustmentRecordDialogState();
}

class _AdjustmentRecordDialogState extends State<_AdjustmentRecordDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _reference = TextEditingController();
  late String? _kind = widget.initialKind;
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _confirm() {
    final checked = checkAdjustmentRecordForm(kind: _kind, amount: _amount.text, reason: _reason.text, reference: _reference.text, netCents: widget.netCents, currency: widget.currency);
    if (checked.error != null) {
      setState(() => _problem = checked.error);
      return;
    }
    Navigator.of(context).pop((kind: _kind!, amount: _amount.text.trim(), reason: _reason.text.trim(), reference: _reference.text.trim()));
  }

  void _clear() {
    if (_problem != null) setState(() => _problem = null);
  }

  @override
  Widget build(BuildContext context) {
    final correction = _kind == 'correction';
    return AlertDialog(
      title: const Text('Record an adjustment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$adjustmentRecordWarning Owed to the organizer now: ${settlementMoney(widget.netCents, currency: widget.currency)}.', key: const Key('form-message')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in adjustmentKinds)
                  ChoiceChip(
                    key: Key('form-kind-$k'),
                    label: Text(adjustmentKindLabel(k)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _problem = null;
                    }),
                  ),
              ],
            ),
            if (_kind != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(adjustmentKindHint(_kind!), key: const Key('form-kind-hint'), style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Amount (${widget.currency.toUpperCase()})',
                hintText: correction ? 'For example +15.00 or -15.00' : 'For example 50.00',
                helperText: correction ? 'A plus adds to what the organizer is owed, a minus takes off.' : 'The amount refunded or charged back. It is taken off.',
              ),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-note'),
              controller: _reason,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Why', hintText: 'For example "Refund of a Friday bottle"'),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-reference'),
              controller: _reference,
              decoration: InputDecoration(
                labelText: 'Reference (optional)',
                hintText: 'The refund or the chargeback case number',
                errorText: _problem,
                errorMaxLines: 3,
              ),
              onChanged: (_) => _clear(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: const Text('Record adjustment')),
      ],
    );
  }
}
