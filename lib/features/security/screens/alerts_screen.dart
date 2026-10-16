import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';
import '../widgets/raise_alert.dart';

/// Alerts (security's tab, and the manager's from More): the alerts of one night at the club. Anyone working there can raise one; security
/// and the manager take it, say they are responding, then resolve it or escalate it. It looks again every few seconds while it is open.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  late String _night = currentNight(widget.clock());
  Timer? _timer;
  final Set<String> _busy = {};

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);
  bool get _isManager => widget.workspace.role == WorkspaceRole.manager || widget.workspace.role == WorkspaceRole.owner;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(ref.read(securityPollIntervalProvider), (_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(alertsProvider(_query));
    ref.invalidate(securitySummaryProvider(_query));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _step(SecurityAlert a, AlertStep step) async {
    String? note;
    if (step.needsNote) {
      note = await showTextDialog(
        context,
        title: step.label,
        hint: step.noteQuestion,
        confirmLabel: step.label,
        validate: (t) => checkStepNote(step, t),
      );
      if (note == null || !mounted) return;
    }
    setState(() => _busy.add(a.id));
    try {
      final outcome = await ref.read(securityServiceProvider).alertStep(a.id, step, note: note);
      _say(alertOutcomeMessage(step, outcome));
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(a.id));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there are no alerts to show.', key: Key('alerts-no-venue'), textAlign: TextAlign.center)));
    }
    final alerts = ref.watch(alertsProvider(_query));
    final summary = ref.watch(securitySummaryProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('alerts-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('Alerts', style: theme.textTheme.headlineSmall)),
              FilledButton.icon(
                key: const Key('alert-raise'),
                onPressed: () => raiseAlertFlow(context, ref, venueId: venueId, night: _night, onSent: _refresh),
                icon: const Icon(Icons.add_alert_outlined, size: 18),
                label: const Text('Raise an alert'),
              ),
            ],
          ),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          summary.maybeWhen(
            skipLoadingOnReload: true,
            data: (s) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(securitySummaryLine(s), key: const Key('alerts-summary'), style: theme.textTheme.bodyMedium)),
            orElse: () => const SizedBox.shrink(),
          ),
          if (alerts.hasError && alerts.hasValue)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Could not refresh. Trying again…', key: const Key('alerts-stale'), style: theme.textTheme.bodySmall)),
          OpsAsyncView<List<SecurityAlert>>(
            value: alerts,
            what: 'alerts',
            keepWhileReloading: true,
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No alerts for this night.',
            emptyKey: const Key('alerts-empty'),
            errorKey: const Key('alerts-error'),
            onRetry: _refresh,
            builder: (list) => Column(
              children: [
                for (final a in list) _AlertCard(alert: a, isManager: _isManager, busy: _busy.contains(a.id), onStep: (s) => _step(a, s)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.isManager, required this.busy, required this.onStep});

  final SecurityAlert alert;
  final bool isManager;
  final bool busy;
  final ValueChanged<AlertStep> onStep;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final theme = Theme.of(context);
    final steps = alertSteps(a, isManager: isManager);
    return Card(
      key: Key('alert-${a.id}'),
      color: a.urgent && !a.resolved ? theme.colorScheme.errorContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(a.urgent ? Icons.warning_amber_rounded : Icons.notifications_none, size: 20, color: a.urgent && !a.resolved ? theme.colorScheme.error : null),
                const SizedBox(width: 8),
                Expanded(child: Text(kindLabel(a.kind), style: theme.textTheme.titleMedium)),
                if (a.urgent) Text('URGENT', key: Key('alert-urgent-${a.id}'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
              ],
            ),
            Text('${a.location} · ${a.raisedByMe ? 'you' : a.raisedByName}${a.raisedAt == null ? '' : ' · ${securityTime(a.raisedAt)}'}', style: theme.textTheme.bodySmall),
            if (a.details != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(a.details!)),
            const SizedBox(height: 6),
            Text(a.statusLabel, key: Key('alert-status-${a.id}'), style: theme.textTheme.labelLarge),
            if (a.escalationNote != null) Text('Why: ${a.escalationNote}', style: theme.textTheme.bodySmall),
            if (a.resolutionNote != null) Text('Done: ${a.resolutionNote}', style: theme.textTheme.bodySmall),
            if (steps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final s in steps)
                      (s == AlertStep.acknowledge || s == AlertStep.resolve)
                          ? FilledButton(key: Key('alert-${s.id}-${a.id}'), onPressed: busy ? null : () => onStep(s), child: Text(s.label))
                          : OutlinedButton(key: Key('alert-${s.id}-${a.id}'), onPressed: busy ? null : () => onStep(s), child: Text(s.label)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
