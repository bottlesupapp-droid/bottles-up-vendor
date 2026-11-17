import 'package:flutter/material.dart';

import '../../inventory/logic/inventory_rules.dart' show StockItem;
import '../logic/complimentary_rules.dart';

/// The form for a new offer: the bottle (from the club's menu), how many, the e-mail the link is for, an optional name, why, an optional sign, and how long the link lasts. Checked here the way the
/// database checks it, then returned; the person backs out with null.
Future<OfferDraft?> showOfferDialog(BuildContext context, {required List<StockItem> bottles}) {
  return showDialog<OfferDraft>(context: context, builder: (_) => _OfferDialog(bottles: bottles));
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.bottles});

  final List<StockItem> bottles;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _qty = TextEditingController(text: '1');
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _reason = TextEditingController();
  final _sign = TextEditingController();
  String? _bottle;
  int _hours = defaultExpiryHours;
  String? _problem;

  @override
  void dispose() {
    for (final c in [_qty, _email, _name, _reason, _sign]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear() {
    if (_problem != null) setState(() => _problem = null);
  }

  void _confirm() {
    final checked = checkOfferForm(bottleId: _bottle, quantityText: _qty.text, email: _email.text, name: _name.text, reason: _reason.text, sign: _sign.text, expiresHours: _hours);
    if (checked.error != null) {
      setState(() => _problem = checked.error);
      return;
    }
    Navigator.of(context).pop(checked.draft);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New offer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('offer-bottle'),
              initialValue: _bottle,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bottle'),
              items: [for (final b in widget.bottles) DropdownMenuItem(value: b.bottleId, child: Text(b.title, overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                setState(() => _bottle = v);
                _clear();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('offer-quantity'),
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'How many (1 to 12)'),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('offer-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail the link is for'),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(key: const Key('offer-name'), controller: _name, decoration: const InputDecoration(labelText: 'Name (optional)'), onChanged: (_) => _clear()),
            const SizedBox(height: 12),
            TextField(
              key: const Key('offer-reason'),
              controller: _reason,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Why', hintText: 'For example "Birthday table"'),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            TextField(key: const Key('offer-sign'), controller: _sign, decoration: const InputDecoration(labelText: 'Sign on the bottle (optional)'), onChanged: (_) => _clear()),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('offer-expiry'),
              initialValue: _hours,
              decoration: InputDecoration(labelText: 'The link lasts', errorText: _problem, errorMaxLines: 3),
              items: [for (final c in expiryChoices) DropdownMenuItem(value: c.hours, child: Text(c.label))],
              onChanged: (v) {
                setState(() => _hours = v ?? defaultExpiryHours);
                _clear();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: const Text('Make the offer')),
      ],
    );
  }
}
