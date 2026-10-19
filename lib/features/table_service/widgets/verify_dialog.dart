import 'package:flutter/material.dart';

import '../logic/table_service_rules.dart';

/// Asks for the optional note that goes with checking a payment ("matches the till"). Returns the text (empty for none) when the
/// person confirms, or null if they back out. The note is checked here first so they are told what is wrong before anything is sent.
Future<String?> showVerifyDialog(
  BuildContext context, {
  required String summary,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _VerifyDialog(summary: summary),
  );
}

class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog({required this.summary});

  final String summary;

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _controller = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = validateVerifyNote(_controller.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark this payment as checked'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.summary),
          const SizedBox(height: 8),
          const Text(
            'Only confirm if the amount and the method match the till or the cash you counted.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('verify-note'),
            controller: _controller,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              errorText: _problem,
            ),
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('verify-back'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('verify-confirm'),
          onPressed: _confirm,
          child: const Text('It matches'),
        ),
      ],
    );
  }
}
