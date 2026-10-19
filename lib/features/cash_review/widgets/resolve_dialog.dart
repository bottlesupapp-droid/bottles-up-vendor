import 'package:flutter/material.dart';

import '../logic/cash_rules.dart';

/// How a flagged payment ended, and what was done. Returns the outcome and the note, or null when the person backs out.
Future<({String resolution, String note})?> showResolveDialog(BuildContext context) {
  return showDialog<({String resolution, String note})>(context: context, builder: (_) => const _ResolveDialog());
}

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog();

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  String? _resolution;
  final _note = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = checkResolution(_resolution, _note.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop((resolution: _resolution!, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve this flag'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _resolution,
              onChanged: (v) => setState(() {
                _resolution = v;
                _problem = null;
              }),
              child: Column(
                children: [
                  for (final (value, label) in flagResolutions)
                    RadioListTile<String>(key: Key('resolution-$value'), dense: true, value: value, title: Text(label)),
                ],
              ),
            ),
            TextField(
              key: const Key('note-field'),
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What was done (needed unless the payment is fine)'),
              onChanged: (_) {
                if (_problem != null) setState(() => _problem = null);
              },
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_problem!, key: const Key('dialog-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: const Text('Resolve')),
      ],
    );
  }
}
