import 'package:flutter/material.dart';

/// A line or two of text, checked before it is sent. Returns the trimmed text, or null when the person backs out.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  required String? Function(String text) validate,
  String? message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(title: title, hint: hint, confirmLabel: confirmLabel, validate: validate, message: message),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.hint, required this.confirmLabel, required this.validate, this.message});

  final String title;
  final String hint;
  final String confirmLabel;
  final String? Function(String) validate;
  final String? message;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _controller = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = widget.validate(_controller.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.message!)),
          TextField(
            key: const Key('text-field'),
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: widget.hint, errorText: _problem),
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('dialog-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// An amount and an optional note. [validate] gets both and returns what is wrong, or null; the dialog closes with the raw texts.
Future<({String amount, String note})?> showAmountNoteDialog(
  BuildContext context, {
  required String title,
  required String amountLabel,
  required String noteLabel,
  required String confirmLabel,
  required String? Function(String amount, String note) validate,
  String initialAmount = '',
  String? message,
}) {
  return showDialog<({String amount, String note})>(
    context: context,
    builder: (_) => _AmountNoteDialog(
      title: title,
      amountLabel: amountLabel,
      noteLabel: noteLabel,
      confirmLabel: confirmLabel,
      validate: validate,
      initialAmount: initialAmount,
      message: message,
    ),
  );
}

class _AmountNoteDialog extends StatefulWidget {
  const _AmountNoteDialog({
    required this.title,
    required this.amountLabel,
    required this.noteLabel,
    required this.confirmLabel,
    required this.validate,
    required this.initialAmount,
    this.message,
  });

  final String title;
  final String amountLabel;
  final String noteLabel;
  final String confirmLabel;
  final String? Function(String, String) validate;
  final String initialAmount;
  final String? message;

  @override
  State<_AmountNoteDialog> createState() => _AmountNoteDialogState();
}

class _AmountNoteDialogState extends State<_AmountNoteDialog> {
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

  void _clear(String _) {
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
            if (widget.message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.message!)),
            TextField(
              key: const Key('amount-field'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: widget.amountLabel, prefixText: r'$ '),
              onChanged: _clear,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('note-field'),
              controller: _note,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.noteLabel),
              onChanged: _clear,
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
        FilledButton(key: const Key('dialog-confirm'), onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
