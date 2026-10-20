import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/venue_profile_rules.dart' show FloorRow;
import '../../owner/providers/owner_providers.dart' show floorsProvider, venueSetupProvider;
import '../../owner/widgets/setup_common.dart' show ProblemsBox, say;
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';
import '../widgets/floor_canvas.dart';

/// Where the tables sit on one floor plan (owner and manager): put a table on the picture, drag it where it belongs, make it bigger or smaller, or take it off. Positions are
/// percentages of the picture, the same numbers the website's editor writes, so a table placed here shows in the right place for guests choosing a table on the website.
/// Nothing is saved until Save; if some of the changes are refused, the rest are kept and the refused ones stay on screen with the database's reason.
class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key, required this.venueId, required this.floor});

  final String venueId;
  final FloorRow floor;

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  /// What the person has changed on this floor: a box = put it here, null = take it off this floor.
  final Map<String, PlacedBox?> _edited = {};
  String? _selected;
  bool _saving = false;

  /// A finger is on a table being dragged: the list does not scroll meanwhile.
  bool _grabbed = false;
  List<String> _problems = const [];

  PlacedBox? _boxOf(TableLayout t) {
    if (_edited.containsKey(t.typeId)) return _edited[t.typeId];
    return t.placed && t.floorId == widget.floor.floorId ? t.box : null;
  }

  bool get _dirty => _edited.isNotEmpty;

  void _set(String typeId, PlacedBox? box) => setState(() {
        _edited[typeId] = box;
        _problems = const [];
      });

  void _putOnFloor(TableLayout t, List<TableLayout> all) {
    final used = all.where((x) => x.typeId != t.typeId && _boxOf(x) != null).length;
    _set(t.typeId, defaultBox(used));
    setState(() => _selected = t.typeId);
  }

  Future<void> _save(List<TableLayout> layout) async {
    if (_saving) return;
    final changes = placementChanges(floorId: widget.floor.floorId, layout: layout, edited: _edited);
    if (changes.isEmpty) {
      setState(() => _edited.clear());
      say(context, 'Nothing changed.');
      return;
    }
    setState(() {
      _saving = true;
      _problems = const [];
    });
    final service = ref.read(tableMapServiceProvider);
    final failed = <String>[];
    var saved = 0;
    for (final c in changes) {
      try {
        if (c.action == PlacementAction.place) {
          await service.place(widget.venueId, c.typeId, widget.floor.floorId, c.box!);
        } else {
          await service.unplace(widget.venueId, c.typeId);
        }
        saved++;
        _edited.remove(c.typeId);
      } on OpsActionException catch (e) {
        failed.add('${c.name}: ${e.message}');
      }
    }
    if (!mounted) return;
    if (saved > 0) {
      // Something changed in the database, so the lists are read again. When every change failed nothing did, and the screen stays as it is.
      ref.invalidate(tableLayoutProvider(widget.venueId));
      ref.invalidate(venueSetupProvider(widget.venueId));
      ref.invalidate(floorsProvider(widget.venueId));
    }
    setState(() {
      _saving = false;
      _problems = failed;
    });
    if (failed.isEmpty) {
      say(context, saved == 1 ? 'Saved: 1 table placed.' : 'Saved: $saved tables placed.');
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('The changes you made to the floor plan have not been saved.'),
        actions: [
          TextButton(key: const Key('placement-stay'), onPressed: () => Navigator.of(c).pop(false), child: const Text('Keep editing')),
          FilledButton(key: const Key('placement-leave'), onPressed: () => Navigator.of(c).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = ref.watch(tableLayoutProvider(widget.venueId));
    final floors = ref.watch(floorsProvider(widget.venueId)).asData?.value ?? const <FloorRow>[];
    String floorName(String id) => floors.where((f) => f.floorId == id).firstOrNull?.label ?? 'another floor';
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave() && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Place tables · ${widget.floor.label}')),
        body: layout.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final e = opsLoadFailureFor(error, 'the tables');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.message, key: const Key('placement-error'), textAlign: TextAlign.center),
                    if (!e.unavailable && !e.accessEnded) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(key: const Key('placement-retry'), onPressed: () => ref.invalidate(tableLayoutProvider(widget.venueId)), child: const Text('Try again')),
                    ],
                  ],
                ),
              ),
            );
          },
          data: (all) => _body(context, theme, all, floorName),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme, List<TableLayout> all, String Function(String) floorName) {
    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('This club has no tables yet. Add the kinds of table first, then place them here.', key: const Key('placement-none'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ),
      );
    }
    final selected = all.where((t) => t.typeId == _selected).firstOrNull;
    final selectedBox = selected == null ? null : _boxOf(selected);
    return ListView(
      key: const Key('placement'),
      physics: _grabbed ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Text('Drag a table to where it is on the floor. Pull the round handle to change its size.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        FloorCanvas(
          imageUrl: widget.floor.imageUrl,
          boxes: [
            for (final t in all)
              if (_boxOf(t) != null)
                FloorBoxData(id: t.typeId, box: _boxOf(t)!, label: t.name, color: const Color(0xFF42A5F5), selected: t.typeId == _selected),
          ],
          onTap: (id) => setState(() => _selected = id),
          onGrab: (g) {
            if (_grabbed != g) setState(() => _grabbed = g);
          },
          onMove: (id, dx, dy) {
            final b = _edited.containsKey(id) ? _edited[id] : all.firstWhere((t) => t.typeId == id).box;
            if (b != null) _set(id, moveBox(b, dx, dy));
          },
          onResize: (id, dw, dh) {
            final b = _edited.containsKey(id) ? _edited[id] : all.firstWhere((t) => t.typeId == id).box;
            if (b != null) _set(id, resizeBox(b, dw, dh));
          },
        ),
        if (selected != null && selectedBox != null) _nudges(theme, selected, selectedBox),
        const SizedBox(height: 12),
        Text('Tables', style: theme.textTheme.titleMedium),
        for (final t in all)
          Card(
            key: Key('placement-table-${t.typeId}'),
            shape: t.typeId == _selected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary, width: 2)) : null,
            child: ListTile(
              onTap: () => setState(() => _selected = t.typeId),
              title: Text(t.name),
              subtitle: Text(_status(t, floorName), key: Key('placement-status-${t.typeId}')),
              trailing: _boxOf(t) == null
                  ? TextButton(key: Key('place-${t.typeId}'), onPressed: _saving ? null : () => _putOnFloor(t, all), child: Text(t.placed ? 'Move here' : 'Put on floor'))
                  : TextButton(key: Key('unplace-${t.typeId}'), onPressed: _saving ? null : () => _set(t.typeId, null), child: const Text('Take off')),
            ),
          ),
        if (_problems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ProblemsBox(problems: _problems),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('placement-save'),
          onPressed: _saving || !_dirty ? null : () => _save(all),
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  String _status(TableLayout t, String Function(String) floorName) {
    final box = _boxOf(t);
    if (box != null) return _edited.containsKey(t.typeId) ? 'On this floor (not saved yet)' : 'On this floor';
    if (_edited.containsKey(t.typeId) && t.placed && t.floorId == widget.floor.floorId) return 'Taken off (not saved yet)';
    return placementStatus(t, floorName, widget.floor.floorId);
  }

  /// The buttons that do what dragging does, a step at a time: for precision, and for anyone who cannot drag.
  Widget _nudges(ThemeData theme, TableLayout t, PlacedBox b) {
    Widget btn(String key, IconData icon, String tip, PlacedBox Function() next) =>
        IconButton(key: Key(key), tooltip: tip, onPressed: _saving ? null : () => _set(t.typeId, next()), icon: Icon(icon));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.name}: ${b.x.toStringAsFixed(0)}% across, ${b.y.toStringAsFixed(0)}% down, ${b.w.toStringAsFixed(0)}% wide, ${b.h.toStringAsFixed(0)}% high', key: const Key('placement-numbers'), style: theme.textTheme.bodySmall),
          Wrap(
            children: [
              btn('nudge-left', Icons.arrow_back, 'Left', () => moveBox(b, -1, 0)),
              btn('nudge-right', Icons.arrow_forward, 'Right', () => moveBox(b, 1, 0)),
              btn('nudge-up', Icons.arrow_upward, 'Up', () => moveBox(b, 0, -1)),
              btn('nudge-down', Icons.arrow_downward, 'Down', () => moveBox(b, 0, 1)),
              btn('wider', Icons.unfold_more, 'Wider', () => resizeBox(b, 1, 0)),
              btn('narrower', Icons.unfold_less, 'Narrower', () => resizeBox(b, -1, 0)),
              btn('taller', Icons.height, 'Taller', () => resizeBox(b, 0, 1)),
              btn('shorter', Icons.vertical_align_center, 'Shorter', () => resizeBox(b, 0, -1)),
            ],
          ),
        ],
      ),
    );
  }
}
