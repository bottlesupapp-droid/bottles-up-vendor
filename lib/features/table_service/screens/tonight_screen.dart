import '../../chat/logic/chat_rules.dart' show alertMaxLength, validateAlert;
import '../../chat/providers/chat_providers.dart';
import '../../chat/screens/chat_screen.dart';
import '../../floor/screens/floor_screen.dart';
import '../../ops/services/ops_rpc.dart' show OpsActionException;
import '../../report_emails/logic/report_email_rules.dart' show emailOrgIdFor;
import '../../server_desk/widgets/reason_dialog.dart';
import '../../booking_conflicts/providers/conflict_providers.dart';
import '../../booking_conflicts/screens/booking_conflicts_screen.dart';
import '../../discounts/logic/discount_rules.dart' show PendingConcession;
import '../../discounts/providers/discount_providers.dart';
import '../../discounts/screens/discounts_screen.dart';
import '../../table_map/screens/table_map_screen.dart';
import '../../walkin/screens/walkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../cash_review/providers/cash_providers.dart';
import '../../cash_review/screens/cash_screen.dart';
import '../../cash_review/screens/exceptions_screen.dart';
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../inventory/logic/inventory_rules.dart' show lowStockCount;
import '../../inventory/providers/inventory_providers.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../night/screens/night_screen.dart';
import '../../night/widgets/report_button.dart';
import '../../security/logic/security_rules.dart' show securitySummaryLine;
import '../../security/providers/security_providers.dart';
import '../../security/screens/security_hub_screen.dart';
import '../../server_desk/screens/service_requests_screen.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';
import '../widgets/night_bar.dart';
import 'orders_screen.dart';
import 'payment_review_screen.dart';

/// Tonight (manager and owner): what needs a person first, then the night at a glance. Each number that has a list opens it; the ones
/// that do not yet (closings, tables without a server) say what to do instead. Not built yet, and said so on the screen: the
/// checklist for preparing a night, closing it, and alerts for delays and low stock.
class TonightScreen extends ConsumerStatefulWidget {
  const TonightScreen({
    super.key,
    required this.workspace,
    this.clock = DateTime.now,
  });

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;

  @override
  ConsumerState<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends ConsumerState<TonightScreen> {
  late String _night = currentNight(widget.clock());

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);

  void _push(String title, Widget body) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder:
                (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
          ),
        )
        .then((_) {
          if (mounted) ref.invalidate(tonightProvider(_query));
        });
  }

  /// One row of a list: what it counts, a line under it when there is one, and the count at the right (amber when it is not zero and needs a person).
  Widget _tile(
    Key key,
    String label,
    int count, {
    String? note,
    VoidCallback? onTap,
    bool attention = true,
  }) {
    return BuListRow(
      key: key,
      title: label,
      subtitle: note,
      maxSubtitleLines: 4,
      onTap: onTap,
      // A row that opens something has a chevron after the count; one that does not keeps the same room, so the counts line up down the card.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BuCountBadge(
            count,
            tone: attention && count > 0 ? BuTone.attention : BuTone.neutral,
          ),
          if (onTap == null) const SizedBox(width: BuSpace.xs + 16),
        ],
      ),
    );
  }

  /// The two buttons of the five that get the room: a step under full size, so five of them do not push the night off the screen.
  static final ButtonStyle _actionStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 12),
  );

  /// The shortcuts: "Add walk-in" is the main one (the filled orange), the rest sit beside it, and "Send alert" is drawn in amber because it
  /// interrupts the whole team.
  Widget _actions(String venueId) {
    final bu = context.bu;
    const gap = SizedBox(width: BuSpace.s);
    const rowGap = SizedBox(height: BuSpace.s);
    final walkIn = OutlinedButton.icon(
      key: const Key('add-walkin'),
      style: _actionStyle.merge(
        OutlinedButton.styleFrom(
          backgroundColor: bu.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bu.panel2,
          disabledForegroundColor: bu.muted,
          side: BorderSide.none,
        ),
      ),
      onPressed: _night == _tonight ? () => _addWalkin(venueId) : null,
      icon: const Icon(Ionicons.person_add_outline, size: 18),
      label: const Text('Add walk-in'),
    );
    final tables = OutlinedButton.icon(
      key: const Key('open-table-map'),
      style: _actionStyle,
      onPressed: () => _openTables(venueId),
      icon: const Icon(Ionicons.map_outline, size: 18),
      label: const Text('Tables'),
    );
    final message = OutlinedButton.icon(
      key: const Key('message-team'),
      style: _actionStyle,
      onPressed:
          () => _push(
            'Messages',
            ChatScreen(workspace: widget.workspace, clock: widget.clock),
          ),
      icon: const Icon(Ionicons.chatbubble_outline, size: 18),
      label: const Text('Message team'),
    );
    final assign = OutlinedButton.icon(
      key: const Key('assign-staff'),
      style: _actionStyle,
      onPressed: () => _assignStaff(venueId),
      icon: const Icon(Ionicons.person_circle_outline, size: 18),
      label: const Text('Assign staff'),
    );
    final alert = OutlinedButton.icon(
      key: const Key('send-alert'),
      style: _actionStyle.merge(
        OutlinedButton.styleFrom(
          foregroundColor: bu.amber,
          side: BorderSide(color: bu.amber.withValues(alpha: 0.45)),
        ),
      ),
      onPressed: _sendAlert,
      icon: const Icon(Ionicons.megaphone_outline, size: 18),
      label: const Text('Send alert'),
    );
    return Column(
      children: [
        Row(children: [Expanded(child: walkIn), gap, Expanded(child: tables)]),
        rowGap,
        Row(children: [Expanded(child: message), gap, Expanded(child: assign)]),
        rowGap,
        SizedBox(width: double.infinity, child: alert),
      ],
    );
  }

  /// An alert to the club's staff: a message in the staff chat, pinned at the top. Managers and owners only (the database checks).
  Future<void> _sendAlert() async {
    final venueId = widget.workspace.venueId;
    if (venueId == null) return;
    final text = await showReasonDialog(
      context,
      title: 'Alert the staff',
      hint: 'What does the team need to know now?',
      confirmLabel: 'Send alert',
      validate: validateAlert,
      maxLength: alertMaxLength,
    );
    if (text == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    try {
      await ref.read(chatServiceProvider).sendAlert(venueId, text, 'alert-${widget.clock().microsecondsSinceEpoch}');
      messenger.showSnackBar(const SnackBar(content: Text('Alert sent. It is pinned at the top of the staff chat.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Tables are given to servers on the Floor, one booking at a time ("Give to a server").
  void _assignStaff(String venueId) => _push(
        'Assign staff',
        FloorScreen(venueId: venueId, venueName: widget.workspace.venueName, orgId: widget.workspace.orgId, clock: widget.clock, showHeading: false),
      );

  /// Walk-ins are booked for tonight; afterwards what Tonight shows is read again.
  Future<void> _addWalkin(String venueId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WalkinScreen(venueId: venueId, venueName: widget.workspace.venueName, night: _night)),
    );
    if (!mounted) return;
    ref.invalidate(tonightProvider(_query));
  }

  /// The floor map for the night on screen; what Tonight shows is read again afterwards.
  Future<void> _openTables(String venueId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TableMapScreen(venueId: venueId, venueName: widget.workspace.venueName, night: _night, tonight: _tonight)),
    );
    if (!mounted) return;
    ref.invalidate(tonightProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This workspace is not tied to a club, so there is no night to show.',
            key: Key('tonight-no-venue'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final async = ref.watch(tonightProvider(_query));
    // Cash and flags are a bonus on this screen: without them (an older server) the rest still shows.
    final cash = ref.watch(verifierSummaryProvider(_query)).asData?.value;
    // Security is a bonus too: an older server has no security functions and the rest still shows.
    final security = ref.watch(securitySummaryProvider(_query)).asData?.value;
    final stock = ref.watch(stockProvider(venueId)).asData?.value;
    // Discounts and free bottles waiting for approval are a bonus too: where the server does not have them yet the tile is simply not there.
    final waitingApprovals = ref.watch(pendingConcessionsProvider(venueId)).asData?.value;
    // Guests who paid after their table had gone to someone else are a bonus too: where the server does not have them yet the tile is simply not there.
    final doubleBooked = ref.watch(bookingConflictsProvider(ConflictsQuery(venueId))).asData?.value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tonightProvider(_query));
        try {
          await ref.read(tonightProvider(_query).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          BuSpace.page,
          BuSpace.l,
          BuSpace.page,
          BuSpace.xl,
        ),
        children: [
          const BuPageHeader(eyebrow: 'Operations', title: 'Tonight'),
          if (widget.workspace.venueName != null) ...[
            const SizedBox(height: BuSpace.xs),
            Text(
              widget.workspace.venueName!,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.bu.muted),
            ),
          ],
          const SizedBox(height: BuSpace.l),
          NightBar(
            night: _night,
            tonight: _tonight,
            onChanged: (n) => setState(() => _night = n),
          ),
          const SizedBox(height: BuSpace.s),
          _actions(venueId),
          if (_night != _tonight)
            Padding(
              padding: const EdgeInsets.only(top: BuSpace.s),
              child: Text('Walk-ins are added for tonight. Go back to tonight to add one.', key: const Key('walkin-tonight-only'), style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: BuSpace.l),
          async.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: BuSpace.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (error, _) {
              final e = loadFailureFor(error, 'Tonight');
              return BuCard(
                child: Column(
                  children: [
                    Text(
                      e.message,
                      key: const Key('tonight-error'),
                      textAlign: TextAlign.center,
                    ),
                    if (!e.unavailable)
                      Padding(
                        padding: const EdgeInsets.only(top: BuSpace.m),
                        child: OutlinedButton(
                          key: const Key('tonight-retry'),
                          onPressed:
                              () => ref.invalidate(tonightProvider(_query)),
                          child: const Text('Try again'),
                        ),
                      ),
                  ],
                ),
              );
            },
            data:
                (t) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BuCard(
                      key: const Key('tile-night'),
                      highlight: true,
                      padding: EdgeInsets.zero,
                      child: BuListRow(
                        icon: Ionicons.moon_outline,
                        title: 'Prepare and close the night',
                        subtitle: 'Checklist, what is still open, and the final report.',
                        onTap: () => _push(
                          'Prepare and close',
                          NightScreen(
                            venueId: venueId,
                            venueName: widget.workspace.venueName,
                            emailOrgId: emailOrgIdFor(widget.workspace),
                            canReopen: widget.workspace.role == WorkspaceRole.owner,
                            clock: widget.clock,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: BuSpace.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ReportButton(venueId: venueId, venueName: widget.workspace.venueName, emailOrgId: emailOrgIdFor(widget.workspace), night: _night, clock: widget.clock),
                    ),
                    const SizedBox(height: BuSpace.xl),
                    const BuSectionHeader(title: 'Needs attention'),
                    const SizedBox(height: BuSpace.s),
                    BuListCard(
                      children: [
                        _tile(
                          const Key('tile-payments'),
                          'Payments to check',
                          t.paymentQueue,
                          note:
                              t.paymentsDisputed > 0
                                  ? '${t.paymentsDisputed} disputed by the guest'
                                  : null,
                          onTap:
                              () => _push(
                                'Payments to check',
                                PaymentReviewScreen(
                                  workspace: widget.workspace,
                                  clock: widget.clock,
                                ),
                              ),
                        ),
                        if (cash != null) ...[
                          _tile(
                            const Key('tile-handovers'),
                            'Cash handovers waiting to be counted',
                            cash.handoversWaiting,
                            onTap: () => _push('Cash', CashScreen(workspace: widget.workspace, clock: widget.clock)),
                          ),
                          _tile(
                            const Key('tile-flags'),
                            'Payments flagged',
                            cash.flagsOpen,
                            note: 'Flagged by the payment verifier, waiting for you.',
                            onTap: () => _push('Flagged payments', ExceptionsScreen(workspace: widget.workspace)),
                          ),
                        ],
                        if (doubleBooked != null)
                          _tile(
                            const Key('tile-conflicts'),
                            'Double-booked tables',
                            doubleBooked.length,
                            note: doubleBooked.isEmpty ? null : 'Guests who paid after their table had gone. They have no confirmation yet.',
                            onTap: () => _push('Double-booked tables', BookingConflictsScreen(workspace: widget.workspace, clock: widget.clock)),
                          ),
                        if (waitingApprovals != null)
                          _tile(
                            const Key('tile-approvals'),
                            'Discounts and free bottles waiting for approval',
                            waitingApprovals.length,
                            note: approvalsNote(waitingApprovals),
                            onTap: () => _push('Discounts', DiscountsScreen(workspace: widget.workspace)),
                          ),
                        if (stock != null && lowStockCount(stock) > 0)
                          _tile(
                            const Key('tile-low-stock'),
                            'Bottles running low',
                            lowStockCount(stock),
                            onTap: () => _push('Inventory', InventoryScreen(workspace: widget.workspace, clock: widget.clock)),
                          ),
                        if (security != null)
                          _tile(
                            const Key('tile-security'),
                            'Security alerts',
                            security.alertsUnresolved,
                            note: securitySummaryLine(security),
                            onTap: () => _push('Security', SecurityHubScreen(workspace: widget.workspace, clock: widget.clock)),
                          ),
                        _tile(
                          const Key('tile-orders-new'),
                          'New orders not started',
                          t.ordersNew,
                          onTap:
                              () => _push(
                                'Orders',
                                OrdersScreen(
                                  workspace: widget.workspace,
                                  clock: widget.clock,
                                  initialFilter: OrderFilter.fresh,
                                ),
                              ),
                        ),
                        _tile(
                          const Key('tile-requests'),
                          'Open requests from tables',
                          t.requestsOpen,
                          onTap:
                              () => _push(
                                'Requests',
                                ServiceRequestsScreen(
                                  workspace: widget.workspace,
                                  clock: widget.clock,
                                ),
                              ),
                        ),
                        _tile(
                          const Key('tile-without-server'),
                          'Tables without a server',
                          t.withoutServer,
                          note: 'Give them one from the Floor tab.',
                        ),
                        _tile(
                          const Key('tile-closeouts'),
                          'Closings asked for',
                          t.closeoutsRequested,
                          note: 'Closing a table is not built yet.',
                        ),
                      ],
                    ),
                    const SizedBox(height: BuSpace.xl),
                    const BuSectionHeader(title: 'The night'),
                    const SizedBox(height: BuSpace.s),
                    BuListCard(
                      children: [
                        _tile(
                          const Key('tile-tables'),
                          'Tables',
                          t.tables,
                          note:
                              '${t.guests} ${t.guests == 1 ? 'guest' : 'guests'} expected · ${t.arrived} ${t.arrived == 1 ? 'table' : 'tables'} arrived',
                          attention: false,
                        ),
                        _tile(
                          const Key('tile-balance'),
                          'Tables with a balance',
                          t.withBalance,
                          note:
                              t.withBalance == 0
                                  ? null
                                  : '${formatDollars(t.balanceDueCents)} still due',
                          attention: false,
                        ),
                        _tile(
                          const Key('tile-in-progress'),
                          'Orders in progress',
                          t.ordersInProgress,
                          attention: false,
                        ),
                        _tile(
                          const Key('tile-delivered'),
                          'Orders delivered',
                          t.ordersDelivered,
                          attention: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: BuSpace.xl),
                    Text(
                      'Preparing and closing the night, and alerts for slow orders and low stock, are not built yet.',
                      key: const Key('tonight-footnote'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

/// What to say under the count of waiting requests: how many this person can decide themselves (never their own, and a manager only within the manager's limit).
String? approvalsNote(List<PendingConcession> waiting) {
  if (waiting.isEmpty) return null;
  final mine = waiting.where((p) => p.canDecide).length;
  if (mine == waiting.length) return null;
  return mine == 0 ? 'None of them is yours to decide.' : '$mine of them you can decide.';
}
