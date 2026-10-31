import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking_detail/providers/booking_detail_providers.dart';
import '../../ops/services/ops_rpc.dart';
import '../logic/sign_rules.dart';
import '../providers/bottle_sign_providers.dart';

/// Put, change or remove the sign on one bottle line. Pops with the sentence to tell the person (saved, waiting for approval, removed), or nothing if it was closed.
/// When the guest asked for a sign at checkout, that is offered as a starting point.
class SignSheet extends ConsumerStatefulWidget {
  const SignSheet({super.key, required this.lineId, required this.title, this.current, this.bookingId});

  final String lineId;

  /// What the sign is for, for the heading: "2 × Patron".
  final String title;
  final String? current;
  final String? bookingId;

  @override
  ConsumerState<SignSheet> createState() => _SignSheetState();
}

class _SignSheetState extends ConsumerState<SignSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.current ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    if (_saving) return;
    final problem = checkSignText(value);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final change = await ref.read(bottleSignServiceProvider).setSign(widget.lineId, value);
      if (mounted) Navigator.of(context).pop(signSavedMessage(change));
    } on OpsActionException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asked = widget.bookingId == null ? null : ref.watch(bookingSignProvider(widget.bookingId!)).valueOrNull;
    final suggestion = asked != null && asked.trim().isNotEmpty && asked.trim() != _text.text.trim() ? asked.trim() : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.current == null ? 'Add a sign' : 'Change the sign', style: theme.textTheme.titleLarge),
          Text(widget.title, key: const Key('sign-sheet-for'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (suggestion != null)
            Card(
              key: const Key('sign-suggestion'),
              child: ListTile(
                title: Text(suggestion),
                subtitle: const Text('The guest asked for this at checkout.'),
                trailing: TextButton(
                  key: const Key('sign-use-suggestion'),
                  onPressed: _saving ? null : () => setState(() => _text.text = suggestion),
                  child: const Text('Use this'),
                ),
              ),
            ),
          TextField(
            key: const Key('sign-field'),
            controller: _text,
            enabled: !_saving,
            maxLength: maxSignLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Sign', hintText: 'Happy Birthday'),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: _save,
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('sign-sheet-error'), style: TextStyle(color: theme.colorScheme.error))),
          Row(
            children: [
              if (widget.current != null)
                TextButton(key: const Key('sign-remove'), onPressed: _saving ? null : () => _save(''), child: const Text('Remove the sign')),
              const Spacer(),
              FilledButton(key: const Key('sign-save'), onPressed: _saving || _text.text.trim().isEmpty ? null : () => _save(_text.text), child: Text(_saving ? 'Saving…' : 'Save')),
            ],
          ),
        ],
      ),
    );
  }
}
