import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show addDays, currentNight, formatNight;
import '../../table_service/logic/table_service_rules.dart' show TableStatus;
import '../../table_service/providers/table_service_providers.dart';
import '../../table_service/screens/table_detail_screen.dart';
import '../../workspace/models/workspace.dart';
import '../logic/server_desk_rules.dart';
import '../providers/server_desk_providers.dart';
import '../services/server_desk_service.dart';
import '../widgets/ask_sheet.dart';
import '../widgets/table_card.dart';
import '../../cash_review/widgets/cash_held_card.dart';
import '../../security/widgets/raise_alert.dart';
import '../../vip/screens/vip_lookup_screen.dart';

/// Shows the sheet that asks what a table needs. Replaced in tests.
typedef AskPicker = Future<AskChoice?> Function(BuildContext context, String tableLabel);

Future<AskChoice?> _defaultAskPicker(BuildContext context, String tableLabel) => showAskSheet(context, tableLabel: tableLabel);

/// My Tables (server): the tables the manager has given to this person for one business night, with what each has asked for that is
/// still open, and a way to ask for something on a table's behalf. The database decides which tables those are (only paid bookings
/// given to this person's current server role) and the screen shows nothing else: no guest email or phone, no money. What was
/// paid and the bottle orders live in production-only columns and are not here until `supabase db pull` brings them in.
class MyTablesScreen extends ConsumerStatefulWidget {
  const MyTablesScreen({super.key, required this.workspace, this.clock = DateTime.now, this.pickAsk = _defaultAskPicker});

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final AskPicker pickAsk;

  @override
  ConsumerState<MyTablesScreen> createState() => _MyTablesScreenState();
}

int guests(List<AssignedTable> tables) => tables.fold<int>(0, (sum, t) => sum + t.guestCount);

class _MyTablesScreenState extends ConsumerState<MyTablesScreen> {
  late String _night = currentNight(widget.clock());
  final Set<String> _asking = {};

  String get _tonight => currentNight(widget.clock());

  Future<void> _ask(AssignedTable t) async {
    final choice = await widget.pickAsk(context, '${t.tableName} · ${t.customerName}');
    if (choice == null || !mounted) return;
    setState(() => _asking.add(t.bookingId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serverDeskServiceProvider).ask(t.bookingId, choice.kind, note: choice.note);
      messenger.showSnackBar(SnackBar(content: Text('Asked for: ${choice.kind.label}.')));
    } on ServerDeskActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // The list shows the truth either way: the request is there, or it is not.
      ref.invalidate(serviceRequestsProvider(RequestsQuery(widget.workspace.venueId ?? '')));
      if (mounted) setState(() => _asking.remove(t.bookingId));
    }
  }

  void _open(AssignedTable t) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => TableDetailScreen(bookingId: t.bookingId, title: '${t.tableName} · ${t.customerName}', clock: widget.clock),
        ))
        .then((_) {
      // Whatever was moved or paid on the table's page, the cards show it now.
      if (!mounted) return;
      ref.invalidate(tableStatusesProvider(NightQuery(widget.workspace.venueId ?? '', _night)));
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
          child: Text('This workspace is not tied to a club, so there are no tables to show.', key: Key('tables-no-venue'), textAlign: TextAlign.center),
        ),
      );
    }

    final tablesAsync = ref.watch(myTablesProvider(_night));
    // The open requests are a bonus on each card: if they cannot be loaded the tables still show.
    final requests = ref.watch(serviceRequestsProvider(RequestsQuery(venueId))).asData?.value ?? const <ServiceRequestRow>[];
    final byBooking = openByBooking(requests);
    // Where each table stands is a bonus on each card too: without it the card simply has no "next" line.
    final statuses = ref.watch(tableStatusesProvider(NightQuery(venueId, _night))).asData?.value ?? const <TableStatus>[];
    final statusOf = {for (final s in statuses) s.bookingId: s};
    final now = widget.clock();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myTablesProvider(_night));
        ref.invalidate(serviceRequestsProvider(RequestsQuery(venueId)));
        ref.invalidate(tableStatusesProvider(NightQuery(venueId, _night)));
        try {
          await ref.read(myTablesProvider(_night).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('My tables', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                key: const Key('night-prev'),
                tooltip: 'The night before',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _night = addDays(_night, -1)),
              ),
              Expanded(child: Text(formatNight(_night), key: const Key('night-label'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium)),
              IconButton(
                key: const Key('night-next'),
                tooltip: 'The next night',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _night = addDays(_night, 1)),
              ),
            ],
          ),
          if (_night != _tonight)
            Align(
              alignment: Alignment.center,
              child: TextButton(key: const Key('night-tonight'), onPressed: () => setState(() => _night = _tonight), child: const Text('Back to tonight')),
            ),
          CashHeldCard(workspace: widget.workspace, night: _night),
          if ((widget.workspace.venueId ?? '').isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const Key('call-security'),
                  onPressed: () => raiseAlertFlow(context, ref, venueId: widget.workspace.venueId!, night: _tonight),
                  icon: const Icon(Icons.add_alert_outlined, size: 18),
                  label: const Text('Call security'),
                ),
                TextButton.icon(
                  key: const Key('vip-lookup-open'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VipLookupScreen(venueId: widget.workspace.venueId!, clock: widget.clock))),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('VIP lookup'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          tablesAsync.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = error is ServerDeskLoadException ? error : const ServerDeskLoadException(unavailable: false, accessEnded: false, what: 'tables');
              return Column(
                children: [
                  Text(e.message, key: const Key('tables-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        key: const Key('tables-retry'),
                        onPressed: () => ref.invalidate(myTablesProvider(_night)),
                        child: const Text('Try again'),
                      ),
                    ),
                ],
              );
            },
            data: (all) {
              // A person with server roles at several clubs sees each club's tables in its own workspace.
              final tables = [for (final t in all) if (t.venueId == venueId) t];
              if (tables.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('No tables have been given to you for this night.', key: Key('tables-empty'), textAlign: TextAlign.center),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tables.length} ${tables.length == 1 ? 'table' : 'tables'} · '
                    '${guests(tables)} ${guests(tables) == 1 ? 'guest' : 'guests'} expected',
                    key: const Key('tables-summary'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  for (final t in tables)
                    TableCard(
                      table: t,
                      openRequests: byBooking[t.bookingId] ?? const [],
                      now: now,
                      asking: _asking.contains(t.bookingId),
                      onAsk: () => _ask(t),
                      status: statusOf[t.bookingId],
                      onOpen: () => _open(t),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Open a table for its bottle orders and payments.',
            key: const Key('tables-footnote'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
