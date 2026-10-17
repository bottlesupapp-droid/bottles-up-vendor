import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/agreement_rules.dart';
import '../providers/agreement_providers.dart';
import 'agreement_detail_screen.dart';
import 'ask_club_screen.dart';

/// Agreements (More): for a club's manager or owner, the requests from organizers and the agreements for events at the club; for an
/// organizer's business, the requests it has made and where each stands. Each line says who has to act next.
class AgreementsScreen extends ConsumerStatefulWidget {
  const AgreementsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<AgreementsScreen> createState() => _AgreementsScreenState();
}

class _AgreementsScreenState extends ConsumerState<AgreementsScreen> {
  String? _chosenVenue;

  bool get _organizer => widget.workspace.role == WorkspaceRole.organizer;
  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  ({String venueId, String orgId}) get _key => _organizer ? (venueId: '', orgId: widget.workspace.orgId) : (venueId: _venueId ?? '', orgId: '');

  Future<void> _ask() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AskClubScreen(orgId: widget.workspace.orgId)));
    if (sent == true && mounted) {
      ref.invalidate(agreementListProvider(_key));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Request sent. The club will propose terms or decline.')));
    }
  }

  Future<void> _open(AgreementRow a) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AgreementDetailScreen(agreementId: a.id)));
    ref.invalidate(agreementListProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_organizer && _venueId == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Events and agreements', listKey: const Key('agreements-pick-club'), itemKeyPrefix: 'agreements-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final list = ref.watch(agreementListProvider(_key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(agreementListProvider(_key)),
      child: ListView(
        key: const Key('agreements-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text(_organizer ? 'Venue agreements' : 'Events and agreements', style: theme.textTheme.headlineSmall)),
              if (_organizer) FilledButton.icon(key: const Key('agreements-ask'), onPressed: _ask, icon: const Icon(Icons.add, size: 18), label: const Text('Ask a club')),
            ],
          ),
          if (!_organizer && widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          if (!_organizer && widget.workspace.venueId == null) TextButton(key: const Key('agreements-change-club'), onPressed: () => setState(() => _chosenVenue = null), child: const Text('Choose another club')),
          const SizedBox(height: 8),
          OpsAsyncView<List<AgreementRow>>(
            value: list,
            what: 'agreements',
            isEmpty: (d) => d.isEmpty,
            emptyText: _organizer ? 'No requests yet. Ask a club to host one of your events.' : 'No organizer has asked to hold an event here yet.',
            emptyKey: const Key('agreements-empty'),
            errorKey: const Key('agreements-error'),
            onRetry: () => ref.invalidate(agreementListProvider(_key)),
            builder: (rows) => Column(
              children: [
                for (final a in rows)
                  Card(
                    key: Key('agreement-${a.id}'),
                    child: ListTile(
                      onTap: () => _open(a),
                      title: Text(a.eventTitle),
                      subtitle: Text('${_organizer ? a.venueName : a.organizerName} · ${agreementStatusLabel(a.status)}\n${waitingLine(a)}', key: Key('agreement-line-${a.id}')),
                      isThreeLine: true,
                      trailing: a.waitingOnMe ? Icon(Icons.circle, size: 12, color: theme.colorScheme.primary, semanticLabel: 'Waiting for you') : null,
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
