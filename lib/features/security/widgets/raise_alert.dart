import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';

class AlertDraft {
  const AlertDraft({required this.kind, required this.urgent, required this.location, this.details});

  final String kind;
  final bool urgent;
  final String location;
  final String? details;
}

/// The form for raising an alert: what kind, where, how urgent, and any details. Closes with the draft, or null when backed out.
Future<AlertDraft?> showRaiseAlertSheet(BuildContext context) {
  return showModalBottomSheet<AlertDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _RaiseAlertSheet(),
  );
}

class _RaiseAlertSheet extends StatefulWidget {
  const _RaiseAlertSheet();

  @override
  State<_RaiseAlertSheet> createState() => _RaiseAlertSheetState();
}

class _RaiseAlertSheetState extends State<_RaiseAlertSheet> {
  final _location = TextEditingController();
  final _details = TextEditingController();
  String? _kind;
  bool _urgent = false;
  String? _problem;

  @override
  void dispose() {
    _location.dispose();
    _details.dispose();
    super.dispose();
  }

  void _send() {
    final problem = checkAlertForm(kind: _kind, location: _location.text, details: _details.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(AlertDraft(kind: _kind!, urgent: _urgent, location: _location.text.trim(), details: _details.text.trim().isEmpty ? null : _details.text.trim()));
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
              Text('Raise an alert', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in alertKinds)
                    ChoiceChip(
                      key: Key('alert-kind-${k.id}'),
                      label: Text(k.label),
                      selected: _kind == k.id,
                      onSelected: (_) => setState(() {
                        _kind = k.id;
                        _problem = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('alert-urgent'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Urgent'),
                subtitle: const Text('Someone is at risk right now.'),
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
              ),
              TextField(
                key: const Key('alert-location'),
                controller: _location,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Where?', hintText: 'For example: Terrace, near the bar'),
                onChanged: (_) => setState(() => _problem = null),
              ),
              TextField(
                key: const Key('alert-details'),
                controller: _details,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
                onChanged: (_) => setState(() => _problem = null),
              ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_problem!, key: const Key('alert-problem'), style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(key: const Key('alert-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
                  const SizedBox(width: 8),
                  FilledButton(key: const Key('alert-submit'), onPressed: _send, child: const Text('Send alert')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the form and sends the alert; says what happened. Returns whether it was sent. Used by the Alerts screen and by a server's
/// "Call security" button, so both raise it the same way.
Future<bool> raiseAlertFlow(BuildContext context, WidgetRef ref, {required String venueId, required String night, VoidCallback? onSent}) async {
  final draft = await showRaiseAlertSheet(context);
  if (draft == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  try {
    await ref.read(securityServiceProvider).raiseAlert(venueId, night, kind: draft.kind, urgent: draft.urgent, location: draft.location, details: draft.details);
    messenger.showSnackBar(const SnackBar(content: Text('Alert sent to security and the manager.')));
    onSent?.call();
    return true;
  } on OpsActionException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}
