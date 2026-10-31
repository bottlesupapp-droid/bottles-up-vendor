import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bottle_signs/providers/bottle_sign_providers.dart';
import '../../bottle_signs/widgets/signs_load_notice.dart';
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';
import '../widgets/night_bar.dart';
import '../widgets/order_card.dart';
import 'table_detail_screen.dart';

/// Orders (server and manager): the bottle lines of one night, longest wait first, with the move to make next. A manager or owner sees
/// the whole club; a server only the tables they were given. The database decides which lines those are and which moves are allowed;
/// the buttons only offer what it would accept.
///
/// The brief's "needs attention" filter means orders left waiting too long. The client has not said how long, so it is not guessed at:
/// every order shows how long it has waited and the longest wait comes first.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({
    super.key,
    required this.workspace,
    this.clock = DateTime.now,
    this.initialFilter = OrderFilter.all,
  });

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final OrderFilter initialFilter;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late String _night = currentNight(widget.clock());
  late OrderFilter _filter = widget.initialFilter;
  final Set<String> _busy = {};

  String get _tonight => currentNight(widget.clock());
  bool get _manager =>
      widget.workspace.role == WorkspaceRole.manager ||
      widget.workspace.role == WorkspaceRole.owner;

  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);

  Future<void> _move(OrderLine l, ServiceState to) async {
    setState(() => _busy.add(l.lineId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref
          .read(tableServiceServiceProvider)
          .moveOrder(l.lineId, to);
      if (!changed) {
        messenger.showSnackBar(
          SnackBar(content: Text('It was already ${to.label.toLowerCase()}.')),
        );
      }
    } on TableServiceActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Always read the list again: after a refusal (a colleague got there first) it shows where the order stands now.
      ref.invalidate(ordersProvider(_query));
      if (mounted) setState(() => _busy.remove(l.lineId));
    }
  }

  void _openTable(OrderLine l) {
    final id = l.bookingId;
    if (id == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder:
                (_) => TableDetailScreen(
                  bookingId: id,
                  title: [
                    if (l.tableName != null) l.tableName!,
                    if (l.customerName != null) l.customerName!,
                  ].join(' · '),
                  clock: widget.clock,
                ),
          ),
        )
        .then((_) {
          // Whatever was moved or paid on the table's page, the list shows it now.
          if (!mounted) return;
          ref.invalidate(ordersProvider(_query));
        });
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
            'This workspace is not tied to a club, so there are no orders to show.',
            key: Key('orders-no-venue'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final async = ref.watch(ordersProvider(_query));
    final now = widget.clock();

    // One entry per row, built only when it scrolls into view: a busy night has hundreds of orders.
    final items = <Widget Function()>[
      () => Text(
        _manager ? 'Orders' : 'My orders',
        style: theme.textTheme.headlineSmall,
      ),
      () =>
          widget.workspace.venueName == null
              ? const SizedBox.shrink()
              : Text(
                widget.workspace.venueName!,
                style: theme.textTheme.bodyMedium,
              ),
      () => const SizedBox(height: 12),
      () => NightBar(
        night: _night,
        tonight: _tonight,
        onChanged: (n) => setState(() => _night = n),
      ),
      () => const SizedBox(height: 8),
    ];
    async.when<void>(
      loading:
          () => items.add(
            () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error: (error, _) {
        final e = loadFailureFor(error, 'orders');
        items.add(
          () => Column(
            children: [
              Text(
                e.message,
                key: const Key('orders-error'),
                textAlign: TextAlign.center,
              ),
              if (!e.unavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    key: const Key('orders-retry'),
                    onPressed: () => ref.invalidate(ordersProvider(_query)),
                    child: const Text('Try again'),
                  ),
                ),
            ],
          ),
        );
      },
      data: (lines) {
        if (lines.isEmpty) {
          items.add(
            () => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                _manager
                    ? 'No bottle orders for this night.'
                    : 'No bottle orders on your tables for this night.',
                key: const Key('orders-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
          return;
        }
        // The signs of every line of the night, read together; a failure to read them is said, because a bottle must not go out without its sign unnoticed.
        final signIds = LineIds([for (final l in lines) l.lineId]);
        final signs = ref.watch(lineSignsProvider(signIds));
        void signsChanged() {
          ref.invalidate(lineSignsProvider(signIds));
          ref.invalidate(ordersProvider(_query));
        }

        final counts = filterCounts(lines);
        final shown = [
          for (final l in lines)
            if (orderMatches(_filter, l)) l,
        ];
        items.add(
          () => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in OrderFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('filter-${f.name}'),
                      label: Text('${f.label} ${counts[f]}'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        );
        items.add(() => SignsLoadNotice(signs: signs, onRetry: () => ref.invalidate(lineSignsProvider(signIds))));
        if (shown.isEmpty) {
          items.add(
            () => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Nothing is ${_filter.label.toLowerCase()}.',
                  key: const Key('orders-filter-empty'),
                ),
              ),
            ),
          );
        }
        for (final l in shown) {
          items.add(
            () => OrderCard(
              line: l,
              now: now,
              manager: _manager,
              busy: _busy.contains(l.lineId),
              onMove: (to) => _move(l, to),
              onOpenTable: () => _openTable(l),
              sign: signs.valueOrNull?[l.lineId],
              onSignChanged: signsChanged,
            ),
          );
        }
        if (lines.length >= 1000) {
          items.add(
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Showing the first 1000 orders of the night.',
                key: const Key('orders-cutoff'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }
      },
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ordersProvider(_query));
        try {
          await ref.read(ordersProvider(_query).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i](),
      ),
    );
  }
}
