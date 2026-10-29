import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../../table_service/widgets/receipt_view.dart';
import '../../workspace/models/workspace.dart';
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';
import '../widgets/club_refund_dialog.dart';
import '../widgets/decide_refund_sheet.dart';
import 'refund_policy_screen.dart';

/// Refunds (club manager, and the owner for any of their clubs): the venue's own refund policy, and the requests to decide. A request comes from a guest (with their booking code and
/// e-mail) or from staff; the manager approves an amount or declines with a reason. A refund to a card is returned by BottlesUp through the payment provider, so the app never moves
/// money; one paid back at the club is recorded here once it has been paid. The BottlesUp team can see every venue's policy and requests.
class RefundsScreen extends ConsumerStatefulWidget {
  const RefundsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends ConsumerState<RefundsScreen> {
  String? _chosenVenue;
  RefundFilter _filter = RefundFilter.open;

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _reload() {
    final v = _venueId;
    if (v != null) ref.invalidate(refundRequestsProvider(v));
  }

  Future<void> _decide(RefundRequest r) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DecideRefundSheet(request: r),
    );
    _reload();
    if (message != null) _say(message);
  }

  Future<void> _recordClub(RefundRequest r) async {
    final done = await showDialog<bool>(context: context, builder: (_) => ClubRefundDialog(request: r));
    _reload();
    if (done == true) _say('Recorded: ${formatDollars(r.approvedCents ?? 0)} paid back at the club.');
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venueId;
    if (venue == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Refunds', listKey: const Key('refunds-pick-club'), itemKeyPrefix: 'refunds-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final theme = Theme.of(context);
    final requests = ref.watch(refundRequestsProvider(venue));
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await ref.read(refundRequestsProvider(venue).future);
        } catch (_) {
          // The list shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('refunds'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Card(
            child: ListTile(
              key: const Key('open-policy'),
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Refund policy'),
              subtitle: const Text('The rules guests read before they pay. You set them; the BottlesUp team can see them.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => RefundPolicyScreen(venueId: venue))),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in RefundFilter.values)
                ChoiceChip(key: Key('refund-filter-${f.name}'), label: Text(f.label), selected: f == _filter, onSelected: (_) => setState(() => _filter = f)),
            ],
          ),
          const SizedBox(height: 8),
          OpsAsyncView<List<RefundRequest>>(
            value: requests,
            what: 'the refund requests',
            errorKey: const Key('refunds-error'),
            onRetry: _reload,
            builder: (all) {
              final list = all.where(_filter.matches).toList();
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _filter == RefundFilter.open ? 'No refund is waiting for you.' : 'There are no refund requests yet.',
                    key: const Key('refunds-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }
              return Column(children: [for (final r in list) _card(theme, r)]);
            },
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, RefundRequest r) {
    final color = switch (r.status) {
      RefundStatus.requested => const Color(0xFFFFB300),
      RefundStatus.approved || RefundStatus.processing => const Color(0xFF42A5F5),
      RefundStatus.completed => const Color(0xFF66BB6A),
      RefundStatus.declined => const Color(0xFF9E9E9E),
      RefundStatus.failed => const Color(0xFFEF5350),
    };
    return Card(
      key: Key('refund-${r.requestId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${r.guestName} · ${r.tableName}', style: theme.textTheme.titleMedium)),
                DeskChip(key: Key('refund-status-${r.requestId}'), text: r.status.label, color: color),
              ],
            ),
            if (r.code != null) Text('${r.code} · ${r.bookingDate}', style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Text('${r.byGuest ? 'The guest' : 'Staff'}: ${r.reason}'),
            const SizedBox(height: 6),
            Text('Paid ${formatDollars(r.paidCents)} · ${suggestionLine(r)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(requestStatusLine(r), key: Key('refund-line-${r.requestId}')),
            if (r.canDecide)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: Key('decide-${r.requestId}'), onPressed: () => _decide(r), child: const Text('Decide')),
              ),
            if (r.hasReceiptPhoto)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(key: Key('view-receipt-${r.requestId}'), onPressed: () => showReceipt(context, ref, r.receiptPath!), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('View the receipt photo')),
              ),
            if (r.needsClubPayment)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: Key('record-club-${r.requestId}'), onPressed: () => _recordClub(r), child: const Text('Record that it was paid back')),
              ),
          ],
        ),
      ),
    );
  }
}
