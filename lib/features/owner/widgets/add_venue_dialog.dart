import 'package:flutter/material.dart';

import '../logic/owner_rules.dart';

/// Asks for a new venue's name. Pops with the trimmed name, or null when cancelled. The same rule as the database's, said
/// before anything is sent.
class AddVenueDialog extends StatefulWidget {
  const AddVenueDialog({super.key});

  @override
  State<AddVenueDialog> createState() => _AddVenueDialogState();
}

class _AddVenueDialogState extends State<AddVenueDialog> {
  final _name = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = validateVenueName(_name.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a venue'),
      content: TextField(
        key: const Key('venue-name-field'),
        controller: _name,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: 'Venue name', errorText: _problem, counterText: ''),
        onChanged: (_) {
          if (_problem != null) setState(() => _problem = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(key: const Key('add-venue-cancel'), onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const Key('add-venue-confirm'), onPressed: _submit, child: const Text('Add venue')),
      ],
    );
  }
}
