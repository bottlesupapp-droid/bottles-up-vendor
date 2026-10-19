import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';

/// One incident report with everything said about it. The report itself never changes; notes are added below it, and a manager (not its
/// author) marks it reviewed.
class IncidentDetailScreen extends ConsumerStatefulWidget {
  const IncidentDetailScreen({super.key, required this.incidentId, this.clock = DateTime.now});

  final String incidentId;
  final DateTime Function() clock;

  @override
  ConsumerState<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  final _note = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addNote() async {
    final problem = checkIncidentNote(_note.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(securityServiceProvider).addNote(widget.incidentId, _note.text);
      _note.clear();
      setState(() => _problem = null);
      ref.invalidate(incidentDetailProvider(widget.incidentId));
    } on OpsActionException catch (e) {
      setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    final note = await showTextDialog(
      context,
      title: 'Mark as reviewed',
      hint: 'A note (optional)',
      confirmLabel: 'Mark reviewed',
      validate: (t) => t.trim().length > 500 ? 'Keep the note to 500 characters or fewer.' : null,
    );
    if (note == null || !mounted) return;
    try {
      await ref.read(securityServiceProvider).review(widget.incidentId, note: note);
      _say('Marked as reviewed.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    ref.invalidate(incidentDetailProvider(widget.incidentId));
  }

  String _when(DateTime? t) => t == null ? '' : DateFormat('d MMM y, HH:mm').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(incidentDetailProvider(widget.incidentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Incident report')),
      body: SafeArea(
        child: ListView(
          key: const Key('incident-detail'),
          padding: const EdgeInsets.all(16),
          children: [
            OpsAsyncView<IncidentDetail>(
              value: detail,
              what: 'the incident report',
              errorKey: const Key('incident-detail-error'),
              onRetry: () => ref.invalidate(incidentDetailProvider(widget.incidentId)),
              builder: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${kindLabel(d.kind)} · ${d.location}', style: theme.textTheme.titleLarge),
                  Text('${_when(d.occurredAt)} · reported by ${d.reportedByName}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Text(d.details, key: const Key('incident-detail-text')),
                  if (d.actionsTaken != null) ...[
                    const SizedBox(height: 12),
                    Text('What was done', style: theme.textTheme.titleSmall),
                    Text(d.actionsTaken!),
                  ],
                  const Divider(height: 32),
                  Text(
                    d.reviewed ? 'Reviewed by ${d.reviewedByName ?? 'a manager'}${d.reviewNote == null ? '' : ': ${d.reviewNote}'}' : 'Not reviewed yet.',
                    key: const Key('incident-review-state'),
                    style: theme.textTheme.labelLarge,
                  ),
                  if (d.canReview) Padding(padding: const EdgeInsets.only(top: 8), child: FilledButton(key: const Key('incident-review'), onPressed: _review, child: const Text('Mark as reviewed'))),
                  const Divider(height: 32),
                  Text('Notes', style: theme.textTheme.titleSmall),
                  if (d.notes.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No notes yet.', key: Key('incident-no-notes'))),
                  for (final (i, n) in d.notes.indexed)
                    ListTile(key: Key('incident-note-$i'), contentPadding: EdgeInsets.zero, title: Text(n.body), subtitle: Text('${n.isMine ? 'You' : n.authorName} · ${_when(n.createdAt)}')),
                  TextField(
                    key: const Key('incident-note-field'),
                    controller: _note,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: 'Add a note', errorText: _problem),
                    onChanged: (_) => setState(() => _problem = null),
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: OutlinedButton(key: const Key('incident-note-add'), onPressed: _busy ? null : _addNote, child: const Text('Add note'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
