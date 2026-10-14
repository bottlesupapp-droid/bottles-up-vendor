import 'package:flutter/material.dart';

import '../logic/server_desk_rules.dart';

/// Asks for a reason (the database refuses to escalate or cancel without one). Returns the trimmed text, or null if the person
/// backs out. The text is checked here first so the person is told what is wrong before anything is sent.
Future<String?> showReasonDialog(BuildContext context, {required String title, required String hint, required String confirmLabel}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, hint: hint, confirmLabel: confirmLabel),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.hint, required this.confirmLabel});

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = validateReason(_controller.text);
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
      content: TextField(
        key: const Key('reason-field'),
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
      actions: [
        TextButton(key: const Key('reason-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('reason-confirm'), onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
