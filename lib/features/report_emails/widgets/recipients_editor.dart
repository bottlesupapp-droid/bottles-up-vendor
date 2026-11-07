import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../logic/report_email_rules.dart';
import '../providers/report_email_providers.dart';

/// One list of addresses: who is on it, add one, take one off. The database decides who may do either; a refusal is shown as its sentence.
class RecipientsEditor extends ConsumerStatefulWidget {
  const RecipientsEditor({super.key, required this.scope, required this.keyPrefix, this.compact = false});

  final ReportListScope scope;

  /// Keys of the parts, so a screen with several lists can tell them apart.
  final String keyPrefix;

  /// Inside the send sheet the list is shown without its own heading.
  final bool compact;

  @override
  ConsumerState<RecipientsEditor> createState() => _RecipientsEditorState();
}

class _RecipientsEditorState extends ConsumerState<RecipientsEditor> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _add(List<ReportRecipient> now) async {
    final problem = recipientProblem(_field.text, [for (final r in now) r.email]);
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(reportEmailServiceProvider).add(widget.scope, _field.text);
      _field.clear();
      ref.invalidate(reportRecipientsProvider(widget.scope));
    } on OpsActionException catch (e) {
      _message = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ReportRecipient r) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(reportEmailServiceProvider).remove(r.id);
      ref.invalidate(reportRecipientsProvider(widget.scope));
    } on OpsActionException catch (e) {
      _message = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = widget.keyPrefix;
    final list = ref.watch(reportRecipientsProvider(widget.scope));
    return OpsAsyncView<List<ReportRecipient>>(
      value: list,
      what: 'the list',
      isEmpty: (_) => false,
      errorKey: Key('$k-error'),
      onRetry: () => ref.invalidate(reportRecipientsProvider(widget.scope)),
      builder:
          (people) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('No one yet. Add an e-mail address below.', key: Key('$k-empty'), style: theme.textTheme.bodyMedium),
                ),
              for (final (i, r) in people.indexed)
                ListTile(
                  key: Key('$k-person-$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Ionicons.mail_outline, size: 20),
                  title: Text(r.email),
                  trailing: IconButton(key: Key('$k-remove-$i'), tooltip: 'Remove ${r.email}', icon: const Icon(Ionicons.close), onPressed: _busy ? null : () => _remove(r)),
                ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('$k-field'),
                      controller: _field,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'E-mail address', isDense: true),
                      onChanged: (_) => setState(() => _message = null),
                      onSubmitted: (_) => _add(people),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(key: Key('$k-add'), onPressed: _busy ? null : () => _add(people), child: Text(_busy ? '…' : 'Add')),
                ],
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_message!, key: Key('$k-message'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
            ],
          ),
    );
  }
}
