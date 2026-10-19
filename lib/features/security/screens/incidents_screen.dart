import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../workspace/models/workspace.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';
import 'incident_detail_screen.dart';
import 'report_incident_screen.dart';

/// Incidents (security's tab, and the manager's from More): the club's incident reports, newest first. A report is kept: it cannot be
/// edited or deleted, later facts are added as notes, and a manager reviews it (never their own).
class IncidentsScreen extends ConsumerStatefulWidget {
  const IncidentsScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends ConsumerState<IncidentsScreen> {
  final List<IncidentRow> _older = [];
  bool _more = true;
  bool _loadingMore = false;

  String get _venue => widget.workspace.venueId ?? '';

  void _refresh() {
    setState(() {
      _older.clear();
      _more = true;
    });
    ref.invalidate(incidentsProvider(_venue));
  }

  Future<void> _loadMore(List<IncidentRow> first) async {
    final last = _older.isNotEmpty ? _older.last : first.last;
    if (last.createdAt == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(securityServiceProvider).incidents(_venue, before: last.createdAt);
      if (!mounted) return;
      setState(() {
        _older.addAll(page);
        _more = page.length >= 50;
      });
    } on OpsLoadException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _report() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReportIncidentScreen(workspace: widget.workspace, clock: widget.clock)));
    if (sent == true) _refresh();
  }

  Future<void> _open(IncidentRow row) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: row.id, clock: widget.clock)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_venue.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there are no incident reports to show.', key: Key('incidents-no-venue'), textAlign: TextAlign.center)));
    }
    final incidents = ref.watch(incidentsProvider(_venue));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('incidents-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('Incidents', style: theme.textTheme.headlineSmall)),
              FilledButton.icon(key: const Key('incident-report'), onPressed: _report, icon: const Icon(Icons.edit_note, size: 20), label: const Text('Report')),
            ],
          ),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          OpsAsyncView<List<IncidentRow>>(
            value: incidents,
            what: 'incident reports',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No incident reports yet.',
            emptyKey: const Key('incidents-empty'),
            errorKey: const Key('incidents-error'),
            onRetry: _refresh,
            builder: (first) {
              final all = [...first, ..._older];
              return Column(
                children: [
                  for (final r in all)
                    Card(
                      key: Key('incident-${r.id}'),
                      child: ListTile(
                        onTap: () => _open(r),
                        title: Text('${kindLabel(r.kind)} · ${r.location}'),
                        subtitle: Text(
                          '${r.occurredAt == null ? '' : DateFormat('d MMM HH:mm').format(r.occurredAt!.toLocal())} · ${r.reportedByMe ? 'you' : r.reportedByName}'
                          '${r.noteCount > 0 ? ' · ${r.noteCount} ${r.noteCount == 1 ? 'note' : 'notes'}' : ''}',
                        ),
                        trailing: Text(r.reviewed ? 'Reviewed' : (r.canReview ? 'To review' : 'Submitted'), key: Key('incident-status-${r.id}'), style: theme.textTheme.labelMedium),
                      ),
                    ),
                  if (first.length >= 50 && _more)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(key: const Key('incidents-more'), onPressed: () => _loadMore(first), child: const Text('Load earlier reports')),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
