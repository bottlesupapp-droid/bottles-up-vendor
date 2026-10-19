import 'package:flutter/material.dart';

import '../logic/seating_rules.dart';

/// Confirm a guest before seating them: who and which table, an optional service estimate in minutes, and (when the booking was found
/// by name, not by its code) what was checked with the guest. Returns the entries, or null when the person backs out.
Future<({String? detail, int? minutes})?> showSeatDialog(
  BuildContext context, {
  required String heading,
  required String detailLine,
  required bool manual,
  bool seated = false,
  String? blockedNote,
}) {
  return showDialog<({String? detail, int? minutes})>(
    context: context,
    builder: (_) => _SeatDialog(heading: heading, detailLine: detailLine, manual: manual, seated: seated, blockedNote: blockedNote),
  );
}

class _SeatDialog extends StatefulWidget {
  const _SeatDialog({required this.heading, required this.detailLine, required this.manual, required this.seated, this.blockedNote});

  final String heading;
  final String detailLine;
  final bool manual;
  final bool seated;
  final String? blockedNote;

  @override
  State<_SeatDialog> createState() => _SeatDialogState();
}

class _SeatDialogState extends State<_SeatDialog> {
  final _estimate = TextEditingController();
  final _detail = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _estimate.dispose();
    _detail.dispose();
    super.dispose();
  }

  void _confirm() {
    final est = checkEstimate(_estimate.text);
    final problem = est.error ?? (widget.manual ? checkManualDetail(_detail.text) : null);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop((detail: widget.manual ? _detail.text.trim() : null, minutes: est.minutes));
  }

  void _clear(String _) {
    if (_problem != null) setState(() => _problem = null);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = widget.seated || widget.blockedNote != null;
    return AlertDialog(
      title: Text(widget.heading, key: const Key('seat-heading')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.detailLine),
            if (widget.seated) const Padding(padding: EdgeInsets.only(top: 8), child: Text('This guest is already seated.', key: Key('seat-already'))),
            if (widget.blockedNote != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.blockedNote!, key: const Key('seat-blocked'))),
            if (!blocked) ...[
              const SizedBox(height: 12),
              if (widget.manual) ...[
                const Text('Found by name: check another detail with the guest.'),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('detail-field'),
                  controller: _detail,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'What did you check?', hintText: 'Their email, or the last digits of their phone'),
                  onChanged: _clear,
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const Key('estimate-field'),
                controller: _estimate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Service estimate in minutes (optional)', hintText: 'For example 25'),
                onChanged: _clear,
              ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_problem!, key: const Key('seat-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('seat-back'), onPressed: () => Navigator.of(context).pop(), child: Text(blocked ? 'Close' : 'Back')),
        if (!blocked) FilledButton(key: const Key('seat-confirm'), onPressed: _confirm, child: const Text('Seat the guest')),
      ],
    );
  }
}
