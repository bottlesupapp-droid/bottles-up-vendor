import '../../walkin/screens/walkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Widget _tile(
    Key key,
    String label,
    int count, {
    String? note,
    VoidCallback? onTap,
    bool attention = true,
  }) {
    final theme = Theme.of(context);
    final hot = attention && count > 0;
    return Card(
      key: key,
      child: ListTile(
        onTap: onTap,
        title: Text(label),
        subtitle: note == null ? null : Text(note),
        trailing: Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            color: hot ? const Color(0xFFFFB300) : null,
          ),
        ),
      ),
    );
  }

  /// Walk-ins are booked for tonight; afterwards what Tonight shows is read again.
  Future<void> _addWalkin(String venueId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WalkinScreen(venueId: venueId, venueName: widget.workspace.venueName, night: _night)),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Tonight', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null)
            Text(
              widget.workspace.venueName!,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          NightBar(
            night: _night,
            tonight: _tonight,
            onChanged: (n) => setState(() => _night = n),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('add-walkin'),
              onPressed: _night == _tonight ? () => _addWalkin(venueId) : null,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Add walk-in'),
            ),
          ),
          if (_night != _tonight)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Walk-ins are added for tonight. Go back to tonight to add one.', key: const Key('walkin-tonight-only'), style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          async.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (error, _) {
              final e = loadFailureFor(error, 'Tonight');
              return Column(
                children: [
                  Text(
                    e.message,
                    key: const Key('tonight-error'),
                    textAlign: TextAlign.center,
                  ),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        key: const Key('tonight-retry'),
                        onPressed:
                            () => ref.invalidate(tonightProvider(_query)),
                        child: const Text('Try again'),
                      ),
                    ),
                ],
              );
            },
            data:
                (t) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      key: const Key('tile-night'),
                      child: ListTile(
                        leading: const Icon(Icons.nightlight_outlined),
                        title: const Text('Prepare and close the night'),
                        subtitle: const Text('Checklist, what is still open, and the final report.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(
                          'Prepare and close',
                          NightScreen(
                            venueId: venueId,
                            venueName: widget.workspace.venueName,
                            canReopen: widget.workspace.role == WorkspaceRole.owner,
                            clock: widget.clock,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ReportButton(venueId: venueId, venueName: widget.workspace.venueName, night: _night, clock: widget.clock),
                    ),
                    const SizedBox(height: 8),
                    Text('Needs attention', style: theme.textTheme.titleMedium),
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
                    const SizedBox(height: 16),
                    Text('The night', style: theme.textTheme.titleMedium),
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
                    const SizedBox(height: 16),
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
