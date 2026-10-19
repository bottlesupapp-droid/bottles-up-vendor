import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/cash_rules.dart';
import '../providers/cash_providers.dart';
import '../widgets/resolve_dialog.dart';

/// The payment verifier's Exceptions tab: payments flagged because something looked wrong. A manager or owner resolves them; the
/// verifier sees them and what became of them.
class ExceptionsScreen extends ConsumerStatefulWidget {
  const ExceptionsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<ExceptionsScreen> createState() => _ExceptionsScreenState();
}

class _ExceptionsScreenState extends ConsumerState<ExceptionsScreen> {
  bool _resolved = false;

  bool get _canResolve => widget.workspace.role == WorkspaceRole.manager || widget.workspace.role == WorkspaceRole.owner;
  String get _venueId => widget.workspace.venueId ?? '';

  void _refresh() {
    ref.invalidate(flagsProvider((venueId: _venueId, resolved: false)));
    ref.invalidate(flagsProvider((venueId: _venueId, resolved: true)));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resolve(PaymentFlag f) async {
    final answer = await showResolveDialog(context);
    if (answer == null) return;
    try {
      await ref.read(cashServiceProvider).resolveFlag(f.id, answer.resolution, note: answer.note);
      _say('Flag resolved.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_venueId.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there are no flagged payments to show.', key: Key('exceptions-no-venue'), textAlign: TextAlign.center)),
      );
    }
    final flags = ref.watch(flagsProvider((venueId: _venueId, resolved: _resolved)));

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Exceptions', style: theme.textTheme.headlineSmall),
          Text('Payments flagged because something looked wrong.', style: theme.textTheme.bodyMedium),
          if (!_canResolve) Text('A manager resolves them.', key: const Key('exceptions-manager-note'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            key: const Key('exceptions-toggle'),
            segments: const [
              ButtonSegment(value: false, label: Text('Open'), icon: Icon(Icons.flag_outlined)),
              ButtonSegment(value: true, label: Text('Resolved'), icon: Icon(Icons.check_circle_outline)),
            ],
            selected: {_resolved},
            onSelectionChanged: (s) => setState(() => _resolved = s.first),
          ),
          const SizedBox(height: 8),
          OpsAsyncView<List<PaymentFlag>>(
            value: flags,
            what: 'flagged payments',
            isEmpty: (d) => d.isEmpty,
            emptyText: _resolved ? 'Nothing has been resolved yet.' : 'No payments are flagged.',
            emptyKey: const Key('exceptions-empty'),
            errorKey: const Key('exceptions-error'),
            onRetry: _refresh,
            builder: (list) => Column(
              children: [
                for (final f in list)
                  Card(
                    key: Key('flag-${f.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${f.customerName} · ${f.tableName}', style: theme.textTheme.titleSmall),
                          Text('${formatDollars(f.amountPaidCents)} by ${f.paymentMethod}${f.confirmationCode == null ? '' : ' · ${f.confirmationCode}'}'),
                          const SizedBox(height: 4),
                          Text('Flagged by ${f.raisedByName}${f.raisedAt == null ? '' : ' at ${DateFormat('MMM d, HH:mm').format(f.raisedAt!.toLocal())}'}', style: theme.textTheme.bodySmall),
                          Text('“${f.reason}”'),
                          if (!f.open) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${resolutionLabel(f.resolution)}${f.resolvedByName == null ? '' : ' · ${f.resolvedByName}'}',
                              key: Key('flag-outcome-${f.id}'),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (f.resolutionNote != null) Text(f.resolutionNote!),
                          ],
                          if (f.open && _canResolve)
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(key: Key('resolve-${f.id}'), onPressed: () => _resolve(f), child: const Text('Resolve')),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
