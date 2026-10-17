import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../workspace/models/workspace.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';

/// New incident report: what, where, when, details, and what was done. If it cannot be sent, everything typed stays on the screen. A sent
/// report is kept and cannot be edited; anything learned later is added as a note.
class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _actions = TextEditingController();
  String? _kind;
  String _when = 'now';
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    _location.dispose();
    _details.dispose();
    _actions.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final problem = checkIncidentForm(kind: _kind, location: _location.text, details: _details.text, actions: _actions.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final now = widget.clock();
    final minutes = whenOptions.firstWhere((w) => w.id == _when).minutesAgo;
    setState(() {
      _sending = true;
      _problem = null;
    });
    try {
      await ref.read(securityServiceProvider).reportIncident(
            widget.workspace.venueId ?? '',
            currentNight(now),
            kind: _kind!,
            occurredAt: now.subtract(Duration(minutes: minutes)),
            location: _location.text,
            details: _details.text,
            actionsTaken: _actions.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident report sent and kept.')));
      Navigator.of(context).pop(true);
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Report an incident')),
      body: SafeArea(
        child: ListView(
          key: const Key('report-form'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('What kind?', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in incidentKinds)
                  ChoiceChip(key: Key('incident-kind-${k.id}'), label: Text(k.label), selected: _kind == k.id, onSelected: (_) => setState(() {
                        _kind = k.id;
                        _problem = null;
                      })),
              ],
            ),
            const SizedBox(height: 16),
            Text('When did it happen?', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final w in whenOptions) ChoiceChip(key: Key('incident-when-${w.id}'), label: Text(w.label), selected: _when == w.id, onSelected: (_) => setState(() => _when = w.id)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(key: const Key('incident-location'), controller: _location, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Where?'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('incident-details'), controller: _details, minLines: 3, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What happened?', alignLabelWithHint: true), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('incident-actions'), controller: _actions, minLines: 2, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What was done? (optional)', alignLabelWithHint: true), onChanged: (_) => setState(() => _problem = null)),
            const SizedBox(height: 8),
            Text('A report is kept and cannot be edited after it is sent. You can add notes to it later.', style: theme.textTheme.bodySmall),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('incident-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 12),
            FilledButton(key: const Key('incident-send'), onPressed: _sending ? null : _send, child: Text(_sending ? 'Sending…' : 'Send report')),
          ],
        ),
      ),
    );
  }
}
