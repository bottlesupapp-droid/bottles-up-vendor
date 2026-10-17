import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/inventory_rules.dart';

class MoveDraft {
  const MoveDraft({required this.kind, required this.quantity, required this.clientKey, this.reason, this.note});

  final StockKind kind;
  final int quantity;
  final String? reason;
  final String? note;

  /// Made when the form opened. Sending the same draft again (after a bad connection) is the same movement, never a second one.
  final String clientKey;
}

String newMovementKey() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

/// The form for one movement of one bottle: a quantity, a reason where the movement needs one, and an optional note.
Future<MoveDraft?> showMovementDialog(BuildContext context, {required StockKind kind, required String bottleTitle, required int? current}) {
  return showDialog<MoveDraft>(context: context, builder: (_) => _MovementDialog(kind: kind, bottleTitle: bottleTitle, current: current));
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.kind, required this.bottleTitle, required this.current});

  final StockKind kind;
  final String bottleTitle;
  final int? current;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  final String _key = newMovementKey();
  String? _problem;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final checked = checkMovement(widget.kind, _quantity.text, _reason.text, current: widget.current);
    if (checked.error != null) {
      setState(() => _problem = checked.error);
      return;
    }
    Navigator.of(context).pop(MoveDraft(
      kind: widget.kind,
      quantity: checked.quantity!,
      clientKey: _key,
      reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.kind;
    return AlertDialog(
      title: Text('${kind.label}: ${widget.bottleTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.current == null ? 'Not counted yet.' : 'In stock now: ${widget.current}', key: const Key('movement-current'), style: theme.textTheme.bodySmall),
            TextField(
              key: const Key('movement-quantity'),
              controller: _quantity,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(labelText: kind.question),
              onChanged: (_) => setState(() => _problem = null),
            ),
            if (kind.needsReason)
              TextField(
                key: const Key('movement-reason'),
                controller: _reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: kind.reasonQuestion),
                onChanged: (_) => setState(() => _problem = null),
              ),
            TextField(
              key: const Key('movement-note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('movement-problem'), style: TextStyle(color: theme.colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('movement-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('movement-save'), onPressed: _save, child: Text(kind == StockKind.count ? 'Save count' : 'Save')),
      ],
    );
  }
}
