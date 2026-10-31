import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../venue_access/widgets/agreement_grants_card.dart';
import '../logic/agreement_rules.dart';
import '../providers/agreement_providers.dart';
import 'terms_form_screen.dart';

/// One agreement: what is being agreed (the latest version in words, and what changed since the last one), a sample calculation for the
/// share of bar sales, who has accepted, the discussion, and the actions: accept the version on screen, propose changes, or decline /
/// withdraw. Earlier versions are kept below. "Accepted" always means one particular version, by a named person, at a time.
class AgreementDetailScreen extends ConsumerStatefulWidget {
  const AgreementDetailScreen({super.key, required this.agreementId});

  final String agreementId;

  @override
  ConsumerState<AgreementDetailScreen> createState() => _AgreementDetailScreenState();
}

class _AgreementDetailScreenState extends ConsumerState<AgreementDetailScreen> {
  final _note = TextEditingController();
  final _sales = TextEditingController(text: '10000');
  String? _noteProblem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _sales.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(agreementDetailProvider(widget.agreementId));

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null) _say(message);
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _accept(AgreementDetail d) => _run(() async {
        final changed = await ref.read(agreementServiceProvider).accept(d.id, d.currentVersion);
        return changed ? 'You accepted version ${d.currentVersion}.' : 'Nothing changed: your side had already accepted this version.';
      });

  Future<void> _propose(AgreementDetail d) async {
    final proposal = await Navigator.of(context).push<TermsProposal>(MaterialPageRoute(
      builder: (_) => TermsFormScreen(initial: d.latest?.terms ?? const {}, title: d.currentVersion == 0 ? 'Propose terms' : 'Propose changes'),
    ));
    if (proposal == null || !mounted) return;
    await _run(() async {
      final v = await ref.read(agreementServiceProvider).propose(d.id, proposal.terms, note: proposal.note);
      return 'Version $v sent. The other side has to accept it.';
    });
  }

  Future<void> _close(AgreementDetail d) async {
    final declining = d.side == 'venue' && d.activeVersion == null;
    final reason = await showTextDialog(
      context,
      title: declining ? 'Decline this request' : (d.activeVersion == null ? 'Withdraw this request' : 'Cancel this agreement'),
      hint: 'Why?',
      confirmLabel: declining ? 'Decline' : 'Confirm',
      validate: checkCloseReason,
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      await ref.read(agreementServiceProvider).close(d.id, reason);
      return declining ? 'Request declined.' : 'Done.';
    });
  }

  Future<void> _addNote(AgreementDetail d) async {
    final problem = checkAgreementNote(_note.text);
    if (problem != null) {
      setState(() => _noteProblem = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(agreementServiceProvider).note(d.id, _note.text);
      _note.clear();
      setState(() => _noteProblem = null);
    } on OpsActionException catch (e) {
      setState(() => _noteProblem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  String _acceptance(AgreementVersion v) {
    final o = v.organizerAccepted ? 'Organizer: ${v.organizerAcceptedByName ?? 'accepted'} · ${agreementTime(v.organizerAcceptedAt)}' : 'Organizer: not yet';
    final c = v.venueAccepted ? 'Club: ${v.venueAcceptedByName ?? 'accepted'} · ${agreementTime(v.venueAcceptedAt)}' : 'Club: not yet';
    return '$o\n$c';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(agreementDetailProvider(widget.agreementId));
    return Scaffold(
      appBar: AppBar(title: const Text('Agreement')),
      body: SafeArea(
        child: ListView(
          key: const Key('agreement-detail'),
          padding: const EdgeInsets.all(16),
          children: [
            OpsAsyncView<AgreementDetail>(
              value: detail,
              what: 'the agreement',
              errorKey: const Key('agreement-error'),
              onRetry: _refresh,
              builder: (d) {
                final latest = d.latest;
                final cents = parseMoneyToCents(_sales.text);
                final sample = latest == null || cents == null ? null : sampleSentence(latest.terms, cents);
                final changes = latest != null && d.previous != null ? termsChanges(d.previous!.terms, latest.terms) : const <String>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.eventTitle, style: theme.textTheme.headlineSmall),
                    Text('${d.organizerName} at ${d.venueName}', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Chip(key: const Key('agreement-status'), label: Text(agreementStatusLabel(d.status))),
                    if (d.closed && d.closedReason != null) Text('Reason: ${d.closedReason}', key: const Key('agreement-closed-reason')),
                    if (d.requestNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Request: ${d.requestNote}', key: const Key('agreement-request-note'))),
                    const SizedBox(height: 12),
                    if (latest == null)
                      Text(d.side == 'venue' ? 'The organizer has asked you to host this event. Propose terms, or decline.' : 'Waiting for the club to respond.', key: const Key('agreement-no-terms'))
                    else ...[
                      Text(latest.isActive ? 'Accepted terms: version ${latest.version}' : 'Proposed terms: version ${latest.version}', key: const Key('agreement-terms-heading'), style: theme.textTheme.titleMedium),
                      Text('Proposed by ${latest.proposedByName ?? (latest.proposedBySide == 'venue' ? 'the club' : 'the organizer')}, ${agreementTime(latest.proposedAt)}', style: theme.textTheme.bodySmall),
                      if (latest.note != null) Text('"${latest.note}"', key: const Key('agreement-version-note')),
                      const SizedBox(height: 8),
                      for (final l in termsLines(latest.terms))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: Text(l.label, style: theme.textTheme.bodySmall)), Expanded(flex: 3, child: Text(l.value, key: Key('term-value-${l.key}')))]),
                        ),
                      if (changes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Changed since version ${d.previous!.version}', style: theme.textTheme.titleSmall),
                        for (final (i, c) in changes.indexed) Text('• $c', key: Key('change-$i')),
                      ],
                      if (latest.terms['bar_percent'] is num && (latest.terms['bar_percent'] as num) > 0) ...[
                        const SizedBox(height: 8),
                        TextField(key: const Key('detail-sample-sales'), controller: _sales, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sample: if bar sales were', prefixText: r'$ '), onChanged: (_) => setState(() {})),
                        if (sample != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sample, key: const Key('detail-sample-result'))),
                      ],
                      const SizedBox(height: 8),
                      Text(_acceptance(latest), key: const Key('agreement-acceptance'), style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    if (!d.closed)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (d.canAccept) FilledButton(key: const Key('agreement-accept'), onPressed: _busy ? null : () => _accept(d), child: Text('Accept version ${d.currentVersion}')),
                          if (d.canPropose) OutlinedButton(key: const Key('agreement-propose'), onPressed: _busy ? null : () => _propose(d), child: Text(d.currentVersion == 0 ? 'Propose terms' : 'Propose changes')),
                          if (d.canClose) OutlinedButton(key: const Key('agreement-close'), onPressed: _busy ? null : () => _close(d), child: Text(d.side == 'venue' && d.activeVersion == null ? 'Decline' : (d.activeVersion == null ? 'Withdraw' : 'Cancel agreement'))),
                        ],
                      ),
                    // What the club shares with the organizer under this agreement (only while it is in force; the card says nothing otherwise).
                    if (d.status == 'active' || d.status == 'changes_pending') ...[
                      const SizedBox(height: 12),
                      AgreementGrantsCard(agreementId: d.id, side: d.side),
                    ],
                    const Divider(height: 32),
                    Text('Discussion', style: theme.textTheme.titleMedium),
                    if (d.notes.isEmpty) const Text('Nothing said yet.', key: Key('agreement-no-notes')),
                    for (final (i, n) in d.notes.indexed)
                      ListTile(key: Key('agreement-note-$i'), contentPadding: EdgeInsets.zero, title: Text(n.body), subtitle: Text('${n.isMine ? 'You' : n.authorName} (${n.side == 'venue' ? 'club' : 'organizer'})${n.version == null ? '' : ' · on version ${n.version}'} · ${agreementTime(n.createdAt)}')),
                    if (!d.closed) ...[
                      TextField(key: const Key('agreement-note-field'), controller: _note, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Write to the other side', errorText: _noteProblem), onChanged: (_) => setState(() => _noteProblem = null)),
                      Align(alignment: Alignment.centerRight, child: OutlinedButton(key: const Key('agreement-note-add'), onPressed: _busy ? null : () => _addNote(d), child: const Text('Send note'))),
                    ],
                    if (d.versions.length > 1) ...[
                      const Divider(height: 32),
                      Text('Earlier versions', style: theme.textTheme.titleMedium),
                      for (final v in d.versions.skip(1))
                        ExpansionTile(
                          key: Key('agreement-version-${v.version}'),
                          tilePadding: EdgeInsets.zero,
                          title: Text('Version ${v.version}${v.isActive ? ' (in force)' : ''}'),
                          subtitle: Text('${v.proposedByName ?? ''} · ${agreementTime(v.proposedAt)}'),
                          children: [
                            for (final l in termsLines(v.terms)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(l.label), trailing: Text(l.value)),
                            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_acceptance(v), style: theme.textTheme.bodySmall)),
                          ],
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
