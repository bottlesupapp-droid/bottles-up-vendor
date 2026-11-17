import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

/// Records a payment that was ALREADY made somewhere else: the exact amount approved (filled in), the day it was paid, a reference, and optionally a note about the evidence. Nothing is sent.
Future<PaymentEntry?> showPaymentDialog(BuildContext context, {required int payableCents, required String currency, required String recipient, DateTime Function() clock = DateTime.now}) {
  return showDialog<PaymentEntry>(context: context, builder: (_) => _PaymentDialog(payableCents: payableCents, currency: currency, recipient: recipient, clock: clock));
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.payableCents, required this.currency, required this.recipient, required this.clock});

  final int payableCents;
  final String currency;
  final String recipient;
  final DateTime Function() clock;

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
    final checked = checkPaymentForm(_amount.text, _reference.text, _evidence.text, payableCents: widget.payableCents, currency: widget.currency);
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
      title: const Text('Record the payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Only record a payment that has ALREADY been made to ${widget.recipient}, outside BottlesUp. Nothing is sent from here.', key: const Key('form-message')),
            const SizedBox(height: 12),
            TextField(
              key: const Key('form-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount paid (${widget.currency.toUpperCase()})',
                helperText: 'Exactly what was approved: ${settlementMoney(widget.payableCents, currency: widget.currency)}',
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
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: const Text('Record payment')),
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
