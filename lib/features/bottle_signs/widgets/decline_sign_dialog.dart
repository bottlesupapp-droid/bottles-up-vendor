import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/sign_rules.dart';
import '../providers/bottle_sign_providers.dart';

/// A manager declines a waiting sign and says why; the server reads the reason on the order and changes the words. Pops true once it is recorded.
class DeclineSignDialog extends ConsumerStatefulWidget {
  const DeclineSignDialog({super.key, required this.lineId, required this.signText});

  final String lineId;
  final String signText;

  @override
  ConsumerState<DeclineSignDialog> createState() => _DeclineSignDialogState();
}

class _DeclineSignDialogState extends ConsumerState<DeclineSignDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decline() async {
    if (_saving) return;
    final problem = checkDeclineReason(_reason.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(bottleSignServiceProvider).review(widget.lineId, approve: false, note: _reason.text);
      if (mounted) Navigator.of(context).pop(true);
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
    return AlertDialog(
      title: const Text('Decline this sign'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${widget.signText}"', key: const Key('decline-sign-text')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('decline-reason'),
            controller: _reason,
            enabled: !_saving,
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Why?', hintText: 'Please check the spelling'),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) Text(_error!, key: const Key('decline-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(key: const Key('decline-cancel'), onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const Key('decline-confirm'), onPressed: _saving ? null : _decline, child: Text(_saving ? 'Saving…' : 'Decline')),
      ],
    );
  }
}
