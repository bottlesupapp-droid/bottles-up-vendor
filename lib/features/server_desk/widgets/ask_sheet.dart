import 'package:flutter/material.dart';

import '../logic/server_desk_rules.dart';

/// What the person chose in the sheet: a kind and an optional note.
class AskChoice {
  const AskChoice(this.kind, this.note);

  final ServiceKind kind;
  final String? note;
}

/// "What does this table need?": a note (optional) and the five kinds the brief lists. Tapping a kind is the choice. Returns null if
/// the person backs out.
Future<AskChoice?> showAskSheet(BuildContext context, {required String tableLabel}) {
  return showModalBottomSheet<AskChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AskSheet(tableLabel: tableLabel),
  );
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.tableLabel});

  final String tableLabel;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _note = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _choose(ServiceKind kind) {
    final problem = validateNote(_note.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(AskChoice(kind, _note.text.trim().isEmpty ? null : _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What does this table need?', style: theme.textTheme.titleMedium),
              Text(widget.tableLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ask-note'),
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Note (optional)', errorText: _problem),
                onChanged: (_) {
                  if (_problem != null) setState(() => _problem = null);
                },
              ),
              const SizedBox(height: 8),
              for (final k in ServiceKind.values)
                ListTile(
                  key: Key('kind-${k.value}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(k.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _choose(k),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
