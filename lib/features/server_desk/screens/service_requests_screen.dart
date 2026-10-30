import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../team/providers/team_providers.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/server_desk_rules.dart';
import '../providers/server_desk_providers.dart';
import '../services/server_desk_service.dart';
import '../widgets/assign_server_row.dart';
import '../widgets/reason_dialog.dart';
import '../widgets/request_card.dart';

/// Asks why a request is being escalated or cancelled. Replaced in tests.
typedef ReasonPicker = Future<String?> Function(BuildContext context, RequestAction action);

Future<String?> _defaultReasonPicker(BuildContext context, RequestAction action) => showReasonDialog(
      context,
      title: action == RequestAction.escalate ? 'Pass this to a manager' : 'Cancel this request',
      hint: action == RequestAction.escalate ? 'Why does a manager need to step in?' : 'Why is it being cancelled?',
      confirmLabel: action == RequestAction.escalate ? 'Pass it on' : 'Cancel request',
    );

/// Requests (server): what the tables of this club have asked for, the longest wait first. The first person to take a request owns
/// it; a colleague who tries next is told so. A server sees their own tables' requests and those of tables nobody has been given;
/// a request passed up to a manager is read only for them. The database decides all of that and the buttons only offer what it
/// would accept.
class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({
    super.key,
    required this.workspace,
    this.clock = DateTime.now,
    this.pickReason = _defaultReasonPicker,
    this.pickHolder = showRequestHolderPicker,
  });

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final ReasonPicker pickReason;

  /// Lets a manager choose who should take a request. Replaced in tests.
  final ServerPicker pickHolder;

  @override
  ConsumerState<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends ConsumerState<ServiceRequestsScreen> {
  bool _showClosed = false;
  final Set<String> _busy = {};

  bool get _manager => widget.workspace.role == WorkspaceRole.manager || widget.workspace.role == WorkspaceRole.owner;

  RequestsQuery get _query => RequestsQuery(widget.workspace.venueId ?? '', includeClosed: _showClosed);

  Future<void> _act(ServiceRequestRow r, RequestAction action) async {
    String? note;
    if (action.needsReason) {
      note = await widget.pickReason(context, action);
      if (note == null || !mounted) return;
    }
    setState(() => _busy.add(r.requestId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serverDeskServiceProvider).act(r.requestId, action, note: note);
    } on ServerDeskActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Always read the list again: after a refusal (someone else took it) the list shows who has it now.
      ref.invalidate(serviceRequestsProvider(_query));
      if (mounted) setState(() => _busy.remove(r.requestId));
    }
  }

  /// A manager hands an open request to a server of the club. It goes back to New: the new person takes it themselves.
  Future<void> _handOver(ServiceRequestRow r, List<ServerOption> options) async {
    final choice = await widget.pickHolder(context, options, r.assignedMembershipId);
    final to = choice?.membershipId;
    if (to == null || !mounted || to == r.assignedMembershipId) return;
    setState(() => _busy.add(r.requestId));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    try {
      await ref.read(serverDeskServiceProvider).reassign(r.requestId, to);
      final name = options.where((o) => o.membershipId == to).map((o) => o.label).firstOrNull ?? 'them';
      messenger.showSnackBar(SnackBar(content: Text('Handed to $name. They need to take it.')));
    } on ServerDeskActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Always read the list again: after a refusal the list shows who has it now.
      ref.invalidate(serviceRequestsProvider(_query));
      if (mounted) setState(() => _busy.remove(r.requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This workspace is not tied to a club, so there are no requests to show.', key: Key('requests-no-venue'), textAlign: TextAlign.center),
        ),
      );
    }

    final async = ref.watch(serviceRequestsProvider(_query));
    final now = widget.clock();
    // Names and the people a request can be handed to come from the team; only a manager needs them.
    final members = _manager ? ref.watch(teamMembersProvider(widget.workspace.orgId)).asData?.value : null;
    final options = members == null ? const <ServerOption>[] : serverOptions(members, venueId);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(serviceRequestsProvider(_query));
        try {
          await ref.read(serviceRequestsProvider(_query).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Requests', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          SwitchListTile(
            key: const Key('show-closed'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show finished requests (last 24 hours)'),
            value: _showClosed,
            onChanged: (v) => setState(() => _showClosed = v),
          ),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = error is ServerDeskLoadException ? error : const ServerDeskLoadException(unavailable: false, accessEnded: false, what: 'requests');
              return Column(
                children: [
                  Text(e.message, key: const Key('requests-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        key: const Key('requests-retry'),
                        onPressed: () => ref.invalidate(serviceRequestsProvider(_query)),
                        child: const Text('Try again'),
                      ),
                    ),
                ],
              );
            },
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('Nothing needs your attention.', key: Key('requests-empty'), textAlign: TextAlign.center),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in rows)
                    RequestCard(
                      request: r,
                      now: now,
                      actions: availableActions(r, manager: _manager),
                      busy: _busy.contains(r.requestId),
                      onAction: (a) => _act(r, a),
                      holder: holderLabelFor(r, members ?? const []),
                      onHandOver: canHandOver(r, manager: _manager) ? () => _handOver(r, options) : null,
                      handOverEnabled: members != null,
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
