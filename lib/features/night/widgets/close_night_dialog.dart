import 'package:flutter/material.dart';

import '../logic/night_rules.dart';

class CloseAnswer {
  const CloseAnswer({required this.acknowledge, this.note});

  final bool acknowledge;
  final String? note;
}

/// Asks before closing. With nothing open it is a plain confirmation. With things open it lists them and will not go on until the person
/// says they know and gives a reason (10+ characters): those exceptions are kept with the close.
Future<CloseAnswer?> showCloseNightDialog(BuildContext context, {required String nightLabel, required List<NightException> exceptions}) {
  return showDialog<CloseAnswer>(context: context, builder: (_) => _CloseNightDialog(nightLabel: nightLabel, exceptions: exceptions));
}

class _CloseNightDialog extends StatefulWidget {
  const _CloseNightDialog({required this.nightLabel, required this.exceptions});

  final String nightLabel;
  final List<NightException> exceptions;

  @override
  State<_CloseNightDialog> createState() => _CloseNightDialogState();
}

class _CloseNightDialogState extends State<_CloseNightDialog> {
  final _note = TextEditingController();
  bool _know = false;
  String? _problem;

  bool get _hasExceptions => widget.exceptions.isNotEmpty;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _close() {
    if (!_hasExceptions) {
      Navigator.of(context).pop(const CloseAnswer(acknowledge: false));
      return;
    }
    if (!_know) {
      setState(() => _problem = 'Tick the box to confirm you know these are still open.');
      return;
    }
    final problem = checkCloseNote(_note.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(CloseAnswer(acknowledge: true, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Close ${widget.nightLabel}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasExceptions)
              const Text('Everything is dealt with. The final report is made when you close, and only the owner can reopen the night.', key: Key('close-clean'))
            else ...[
              Text('These are still open:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final e in widget.exceptions) Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('• ${e.sentence}', key: Key('close-exception-${e.key}'))),
              const SizedBox(height: 8),
              const Text('They will be listed in the final report. Only the owner can reopen the night.'),
              CheckboxListTile(
                key: const Key('close-know'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _know,
                title: const Text('I know these are still open'),
                onChanged: (v) => setState(() {
                  _know = v ?? false;
                  _problem = null;
                }),
              ),
              TextField(
                key: const Key('close-note'),
                controller: _note,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Why are you closing anyway?'),
                onChanged: (_) => setState(() => _problem = null),
              ),
            ],
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('close-problem'), style: TextStyle(color: theme.colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('close-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Not yet')),
        FilledButton(key: const Key('close-confirm'), onPressed: _close, child: Text(_hasExceptions ? 'Close with exceptions' : 'Close the night')),
      ],
    );
  }
}
