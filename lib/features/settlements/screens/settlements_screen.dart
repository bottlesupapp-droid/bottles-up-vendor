import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/settlement_rules.dart';
import '../providers/settlement_providers.dart';
import 'settlement_detail_screen.dart';

BuTone toneOf(SettlementTone t) => switch (t) {
  SettlementTone.neutral => BuTone.neutral,
  SettlementTone.attention => BuTone.attention,
  SettlementTone.good => BuTone.good,
  SettlementTone.bad => BuTone.bad,
};

/// Organizer settlements (brief section 25): what each club owes each organizer for their share of bar sales under the accepted agreement. The owner sees every club's (Owner Money -> Organizer
/// Settlements), the manager their club's (Settlement Review), and the organizer their own (Organizer Event -> Settlement). RECORD ONLY: nothing is paid from here; a payment is recorded after it
/// was made somewhere else.
class SettlementsScreen extends ConsumerStatefulWidget {
  const SettlementsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends ConsumerState<SettlementsScreen> {
  String? _chosenVenue;

  bool get _organizer => widget.workspace.role == WorkspaceRole.organizer;
  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  String get _title => switch (widget.workspace.role) {
    WorkspaceRole.manager => 'Settlement review',
    WorkspaceRole.organizer => 'Settlement',
    _ => 'Organizer settlements',
  };

  void _refresh() {
    if (_organizer) {
      ref.invalidate(orgSettlementsProvider(widget.workspace.orgId));
    } else {
      ref.invalidate(venueSettlementsProvider(_venueId ?? ''));
    }
  }

  Future<void> _open(SettlementRow row) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettlementDetailScreen(agreementId: row.agreementId)));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = _venueId;
    if (!_organizer && venueId == null) {
      return VenuePicker(
        workspace: widget.workspace,
        title: _title,
        listKey: const Key('settlements-pick-club'),
        itemKeyPrefix: 'settlements-club-',
        onPick: (id) => setState(() => _chosenVenue = id),
      );
    }
    final value = _organizer ? ref.watch(orgSettlementsProvider(widget.workspace.orgId)) : ref.watch(venueSettlementsProvider(venueId!));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('settlements-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl),
        children: [
          BuPageHeader(eyebrow: 'Money', title: _title),
          if (!_organizer && widget.workspace.venueId != null && widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          if (!_organizer && widget.workspace.venueId == null)
            TextButton(key: const Key('settlements-change-club'), onPressed: () => setState(() => _chosenVenue = null), child: const Text('Choose another club')),
          const SizedBox(height: BuSpace.m),
          BuCard(child: Text(recordOnlyNote, key: const Key('settlements-note'), style: theme.textTheme.bodyMedium)),
          const SizedBox(height: BuSpace.l),
          OpsAsyncView<List<SettlementRow>>(
            value: value,
            what: 'the settlements',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'Nothing to settle yet. An agreement with a share of bar sales appears here once it is active.',
            emptyKey: const Key('settlements-empty'),
            errorKey: const Key('settlements-error'),
            onRetry: _refresh,
            builder:
                (rows) => BuListCard(
                  children: [
                    for (final r in rows)
                      BuListRow(
                        key: Key('settlement-${r.agreementId}'),
                        title: r.eventTitle,
                        subtitle: '${_organizer ? r.venueName : r.organizerName} · ${r.terms}\n${r.started ? 'Owed: ${settlementMoney(r.payableCents ?? 0)}' : settlementStatusInfo(null).note}',
                        maxSubtitleLines: 3,
                        trailing: BuStatusPill(settlementStatusInfo(r.status).label, key: Key('settlement-status-${r.agreementId}'), tone: toneOf(settlementStatusInfo(r.status).tone)),
                        onTap: () => _open(r),
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
