import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight, formatNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../logic/night_rules.dart';
import '../providers/night_providers.dart';
import '../widgets/close_night_dialog.dart';
import 'report_screen.dart';

/// Prepare and close a night (manager; the owner can also reopen). Prepare: tick off what is ready. Close: what is still open is listed,
/// the closing items are ticked, and the night is closed, with exceptions only if they are acknowledged and explained. A closed night's
/// checklist is locked; only the owner reopens it, with a reason.
class NightScreen extends ConsumerStatefulWidget {
  const NightScreen({super.key, required this.venueId, this.venueName, this.canReopen = false, this.clock = DateTime.now});

  final String venueId;
  final String? venueName;
  final bool canReopen;
  final DateTime Function() clock;

  @override
  ConsumerState<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends ConsumerState<NightScreen> {
  late String _night = currentNight(widget.clock());
  final Set<String> _busy = {};
  bool _closing = false;

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.venueId, _night);

  void _refresh() {
    ref.invalidate(nightChecklistProvider(_query));
    ref.invalidate(closeStatusProvider(_query));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(ChecklistItem item) async {
    setState(() => _busy.add(item.key));
    try {
      await ref.read(nightServiceProvider).check(widget.venueId, _night, item.key, !item.done);
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(item.key));
      _refresh();
    }
  }

  Future<void> _close(CloseStatus status) async {
    final answer = await showCloseNightDialog(context, nightLabel: formatNight(_night), exceptions: status.wouldBeExceptions);
    if (answer == null || !mounted) return;
    setState(() => _closing = true);
    try {
      final n = await ref.read(nightServiceProvider).close(widget.venueId, _night, acknowledge: answer.acknowledge, note: answer.note);
      _say(n == 0 ? 'The night is closed.' : 'The night is closed with $n ${n == 1 ? 'exception' : 'exceptions'}.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _closing = false);
      _refresh();
    }
  }

  Future<void> _reopen() async {
    final reason = await showTextDialog(
      context,
      title: 'Reopen this night',
      hint: 'Why is it being reopened?',
      confirmLabel: 'Reopen',
      message: 'The figures at the close stay in the audit log. The night can be closed again.',
      validate: checkReopenReason,
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(nightServiceProvider).reopen(widget.venueId, _night, reason);
      _say('The night is open again.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    _refresh();
  }

  Widget _checkTile(ChecklistItem i, bool locked) {
    return CheckboxListTile(
      key: Key('check-${i.key}'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: i.done,
      onChanged: locked || _busy.contains(i.key) ? null : (_) => _toggle(i),
      title: Text(i.label),
      subtitle: i.done && i.doneByName != null ? Text('${i.doneByName}${i.doneAt == null ? '' : ' · ${DateFormat('HH:mm').format(i.doneAt!.toLocal())}'}') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(closeStatusProvider(_query));
    final checklist = ref.watch(nightChecklistProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('night-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Prepare and close the night', style: theme.textTheme.headlineSmall),
          if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: 8),
          OpsAsyncView<CloseStatus>(
            value: status,
            what: 'the state of the night',
            errorKey: const Key('night-error'),
            onRetry: _refresh,
            builder: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  key: const Key('night-state'),
                  child: ListTile(
                    leading: Icon(s.closed ? Icons.lock_outline : Icons.lock_open_outlined),
                    title: Text(s.closed ? 'Closed' : (s.reopened ? 'Reopened' : 'Open')),
                    subtitle: Text(
                      s.closed
                          ? 'Closed${s.closedAt == null ? '' : ' ${DateFormat('HH:mm').format(s.closedAt!.toLocal())}'}${s.closedByName == null ? '' : ' by ${s.closedByName}'}'
                          : (s.reopened ? 'Reopened${s.reopenReason == null ? '' : ': ${s.reopenReason}'}' : 'Not closed yet.'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Prepare', style: theme.textTheme.titleMedium),
                OpsAsyncView<List<ChecklistItem>>(
                  value: checklist,
                  what: 'the checklist',
                  errorKey: const Key('checklist-error'),
                  onRetry: _refresh,
                  builder: (items) => Column(children: [for (final i in items.where((i) => !i.isClosing)) _checkTile(i, s.closed)]),
                ),
                const SizedBox(height: 12),
                Text('Close', style: theme.textTheme.titleMedium),
                OpsAsyncView<List<ChecklistItem>>(
                  value: checklist,
                  what: 'the checklist',
                  errorKey: const Key('checklist-error-close'),
                  onRetry: _refresh,
                  builder: (items) => Column(children: [for (final i in items.where((i) => i.isClosing)) _checkTile(i, s.closed)]),
                ),
                const SizedBox(height: 8),
                if (s.closed) ...[
                  if (s.exceptions.isNotEmpty) ...[
                    Text('Closed with exceptions', style: theme.textTheme.titleSmall),
                    for (final e in s.exceptions) Text('• ${e.sentence}', key: Key('exception-${e.key}')),
                    if (s.exceptionsNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reason: ${s.exceptionsNote}', key: const Key('exceptions-note'))),
                  ] else
                    const Text('Closed with nothing left open.', key: Key('closed-clean')),
                  const SizedBox(height: 8),
                  if (widget.canReopen) OutlinedButton(key: const Key('night-reopen'), onPressed: _reopen, child: const Text('Reopen this night')) else const Text('Only the owner can reopen a closed night.', key: Key('night-owner-only')),
                ] else ...[
                  Text('Still open', style: theme.textTheme.titleSmall),
                  if (s.blockers.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Nothing is waiting.', key: Key('nothing-open')))
                  else
                    for (final b in s.blockers) Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('• ${b.sentence}', key: Key('blocker-${b.key}'))),
                  const SizedBox(height: 12),
                  FilledButton(key: const Key('night-close'), onPressed: _closing ? null : () => _close(s), child: Text(_closing ? 'Closing…' : 'Close the night')),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('night-report'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Report')), body: ReportScreen(venueId: widget.venueId, venueName: widget.venueName, initialNight: _night, clock: widget.clock)),
                  )),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(s.closed ? 'Final report' : 'Preliminary report'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
