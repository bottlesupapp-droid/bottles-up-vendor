import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/venue_profile_rules.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/setup_common.dart';
import 'floor_form_screen.dart';

/// Floor plans (owner and manager): the pictures of the rooms (main room, terrace, VIP lounge) guests see when they choose a table.
/// Removing a floor leaves its tables, just unplaced. Where each table sits on a floor is arranged by the BottlesUp team for now.
class FloorsEditor extends ConsumerStatefulWidget {
  const FloorsEditor({super.key, required this.venueId, required this.orgId});

  final String venueId;
  final String orgId;

  @override
  ConsumerState<FloorsEditor> createState() => _FloorsEditorState();
}

class _FloorsEditorState extends ConsumerState<FloorsEditor> {
  void _refresh() => refreshAfterChange(ref, widget.venueId, () => ref.invalidate(floorsProvider(widget.venueId)));

  Future<void> _openForm(FloorRow? row) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => FloorFormScreen(venueId: widget.venueId, orgId: widget.orgId, floor: row)),
    );
    if (saved == true && mounted) {
      _refresh();
      say(context, row == null ? 'Floor added.' : 'Floor saved.');
    }
  }

  Future<void> _remove(FloorRow f) async {
    final yes = await confirmRemove(
      context,
      title: 'Remove ${f.label}?',
      body: f.tableCount == 0
          ? 'Guests will no longer see this floor plan. This cannot be undone.'
          : 'Guests will no longer see this floor plan. The ${f.tableCount} ${f.tableCount == 1 ? 'table' : 'tables'} placed on it stay, but are no longer placed. This cannot be undone.',
    );
    if (!yes || !mounted) return;
    try {
      await ref.read(venueSetupServiceProvider).removeFloor(widget.venueId, f.floorId);
      if (!mounted) return;
      _refresh();
      say(context, 'Floor removed.');
    } on SetupEditException catch (e) {
      if (mounted) say(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floors = ref.watch(floorsProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Floor plans')),
      floatingActionButton: FloatingActionButton.extended(key: const Key('add-floor'), onPressed: () => _openForm(null), icon: const Icon(Icons.add), label: const Text('Add a floor')),
      body: floors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EditorLoadError(error: e, onRetry: () => ref.invalidate(floorsProvider(widget.venueId))),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text('The pictures of your rooms. Guests see them when they choose a table.', style: theme.textTheme.bodyMedium),
            if (list.isEmpty)
              Container(
                key: const Key('no-floors'),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(14)),
                child: const Text('No floor plans yet. Add a picture of your main room first.', textAlign: TextAlign.center),
              ),
            for (final f in list)
              Card(
                key: Key('floor-${f.floorId}'),
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: f.imageUrl.isEmpty
                          ? const Center(child: Icon(Icons.image_outlined))
                          : Image.network(f.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Text(f.label, style: theme.textTheme.titleMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(describeFloorTables(f.tableCount), key: Key('tables-${f.floorId}'), style: theme.textTheme.bodySmall),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(key: Key('edit-${f.floorId}'), onPressed: () => _openForm(f), child: const Text('Edit')),
                        TextButton(
                          key: Key('remove-${f.floorId}'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                          onPressed: () => _remove(f),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
