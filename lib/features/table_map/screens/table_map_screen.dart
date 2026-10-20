import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show addDays;
import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/venue_profile_rules.dart' show FloorRow;
import '../../owner/providers/owner_providers.dart' show floorsProvider;
import '../../table_service/widgets/night_bar.dart';
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';
import '../widgets/block_tables_sheet.dart';
import '../widgets/floor_canvas.dart';

/// The tables of one night, as the floor map (club manager and owner): for each arrival time, which tables are Available, Held, Booked, Occupied or Unavailable, drawn on the
/// floor plan where the tables have been placed and listed below it. A manager can hold some free tables for a while or take them out of use, and reopen them. The database counts
/// the states and refuses to block a table somebody has booked; the screen reads the map again after every change and when it is pulled down.
class TableMapScreen extends ConsumerStatefulWidget {
  const TableMapScreen({super.key, required this.venueId, this.venueName, required this.night, String? tonight}) : tonight = tonight ?? night;

  final String venueId;
  final String? venueName;

  /// The business night shown first, 'YYYY-MM-DD'.
  final String night;
  final String tonight;

  @override
  ConsumerState<TableMapScreen> createState() => _TableMapScreenState();
}

class _TableMapScreenState extends ConsumerState<TableMapScreen> {
  late String _night = widget.night;
  String? _slotId;
  String? _floorId;
  String? _selected;
  final Set<String> _busy = {};

  MapQuery get _query => MapQuery(widget.venueId, _night);

  void _changeNight(String night) {
    // The database shows from last night to 60 nights ahead.
    if (night.compareTo(addDays(widget.tonight, -1)) < 0 || night.compareTo(addDays(widget.tonight, 60)) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can look at the tables from last night to 60 nights ahead.')));
      return;
    }
    setState(() {
      _night = night;
      _slotId = null;
      _selected = null;
    });
  }

  void _reload() {
    ref.invalidate(tableStatesProvider(_query));
    ref.invalidate(tableBlocksProvider(_query));
  }

  Future<void> _block(MapSlot slot, TableState t) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlockTablesSheet(venueId: widget.venueId, night: _night, slotTitle: slot.title, table: t),
    );
    if (!mounted) return;
    // Whatever happened, what is free now may be different.
    _reload();
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reopen(TableBlock b) async {
    if (_busy.contains(b.id)) return;
    setState(() => _busy.add(b.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ended = await ref.read(tableMapServiceProvider).release(b.id);
      messenger.showSnackBar(SnackBar(content: Text(ended ? 'Reopened: ${b.quantity} × ${b.tableName}.' : 'That had already ended.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      _reload();
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = ref.watch(tableStatesProvider(_query));
    // The pictures are a bonus: without them (an older server, or no floors) the list below still works.
    final floors = ref.watch(floorsProvider(widget.venueId)).asData?.value ?? const <FloorRow>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await ref.read(tableStatesProvider(_query).future);
            } catch (_) {
              // The screen shows the failure itself.
            }
          },
          child: ListView(
            key: const Key('table-map'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.titleMedium),
              NightBar(night: _night, tonight: widget.tonight, onChanged: _changeNight),
              states.when(
                loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
                error: (error, _) {
                  final e = opsLoadFailureFor(error, 'the tables');
                  return Column(
                    children: [
                      Text(e.message, key: const Key('map-error'), textAlign: TextAlign.center),
                      if (!e.unavailable && !e.accessEnded)
                        Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(key: const Key('map-retry'), onPressed: _reload, child: const Text('Try again'))),
                    ],
                  );
                },
                data: (slots) => _content(context, theme, slots, floors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ThemeData theme, List<MapSlot> slots, List<FloorRow> floors) {
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('This club has no arrival times or tables set up for this night. Add them in the venue setup.', key: const Key('map-none'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
      );
    }
    final slot = slots.firstWhere((s) => s.id == _slotId, orElse: () => slots.first);
    final placedFloors = [for (final f in floors) if (slot.tables.any((t) => t.floorId == f.floorId)) f];
    final floor = placedFloors.where((f) => f.floorId == _floorId).firstOrNull ?? (placedFloors.isEmpty ? null : placedFloors.first);
    final blocks = ref.watch(tableBlocksProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Arrival time', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in slots)
              ChoiceChip(key: Key('map-slot-${s.id}'), label: Text(s.title), selected: s.id == slot.id, onSelected: (_) => setState(() => _slotId = s.id)),
          ],
        ),
        if (placedFloors.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final f in placedFloors)
                ChoiceChip(key: Key('map-floor-${f.floorId}'), label: Text(f.label), selected: f.floorId == floor?.floorId, onSelected: (_) => setState(() => _floorId = f.floorId)),
            ],
          ),
        ],
        if (floor != null) ...[
          const SizedBox(height: 12),
          FloorCanvas(
            imageUrl: floor.imageUrl,
            boxes: [
              for (final t in slot.tables)
                if (t.floorId == floor.floorId && t.box != null)
                  FloorBoxData(
                    id: t.tableTypeId,
                    box: t.box!,
                    label: t.tableName,
                    sublabel: '${t.available}/${t.inventory}',
                    color: colorOfKind(kindOf(t)),
                    selected: t.tableTypeId == _selected,
                  ),
            ],
            onTap: (id) => setState(() => _selected = id),
          ),
        ],
        const SizedBox(height: 8),
        const MapLegend(),
        if (floor == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No tables are placed on a floor plan yet, so they are listed below. The owner places them in the venue setup under Rooms and floor plan.', key: const Key('map-unplaced-note'), style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 12),
        for (final t in slot.tables) _tableCard(theme, slot, t),
        const SizedBox(height: 16),
        Text('Holds and tables out of use', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        blocks.when(
          loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          error: (error, _) => Text(opsLoadFailureFor(error, 'the holds').message, key: const Key('blocks-error')),
          data: (list) => list.isEmpty
              ? Text('Nothing is held or out of use on this night.', key: const Key('blocks-empty'), style: theme.textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final b in list)
                      Card(
                        key: Key('block-${b.id}'),
                        child: ListTile(
                          title: Text(blockLine(b)),
                          subtitle: Text('${b.reason} · by ${b.madeBy}'),
                          trailing: TextButton(key: Key('reopen-${b.id}'), onPressed: _busy.contains(b.id) ? null : () => _reopen(b), child: Text(_busy.contains(b.id) ? 'Reopening...' : 'Reopen')),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tableCard(ThemeData theme, MapSlot slot, TableState t) {
    final kind = kindOf(t);
    final selected = t.tableTypeId == _selected;
    return Card(
      key: Key('map-table-${t.tableTypeId}'),
      shape: selected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary, width: 2)) : null,
      child: ListTile(
        onTap: () => setState(() => _selected = t.tableTypeId),
        leading: Tooltip(message: kind.label, child: Icon(Icons.circle, color: colorOfKind(kind), size: 18)),
        title: Text(t.tableName),
        subtitle: Text('${countsLine(t)} · seats up to ${t.maxGuests}', key: Key('map-counts-${t.tableTypeId}')),
        trailing: TextButton(
          key: Key('map-block-${t.tableTypeId}'),
          onPressed: t.available < 1 ? null : () => _block(slot, t),
          child: const Text('Hold / out of use'),
        ),
      ),
    );
  }
}
