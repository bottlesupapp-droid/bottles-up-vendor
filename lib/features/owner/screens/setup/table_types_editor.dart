import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../logic/setup_forms.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/setup_common.dart';
import 'table_type_form_screen.dart';

/// Tables (owner): the kinds of table guests can book (VIP booth, dance floor table...), each with its own capacity and price. A
/// table type that bookings point at cannot be removed; the screen says so and suggests setting the number of tables to 0 to stop
/// new bookings instead.
class TableTypesEditor extends ConsumerStatefulWidget {
  const TableTypesEditor({super.key, required this.venueId, required this.orgId});

  final String venueId;

  /// The business the venue belongs to: photos are uploaded into its folder.
  final String orgId;

  @override
  ConsumerState<TableTypesEditor> createState() => _TableTypesEditorState();
}

class _TableTypesEditorState extends ConsumerState<TableTypesEditor> {
  void _refresh() => refreshAfterChange(
    ref,
    widget.venueId,
    () => ref.invalidate(tableTypesProvider(widget.venueId)),
  );

  Future<void> _openForm(TableTypeRow? row) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TableTypeFormScreen(venueId: widget.venueId, orgId: widget.orgId, row: row),
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      say(context, row == null ? 'Table added.' : 'Table saved.');
    }
  }

  Future<void> _remove(TableTypeRow t) async {
    final yes = await confirmRemove(
      context,
      title: 'Remove ${t.name}?',
      body: 'Guests will no longer be able to book it. This cannot be undone.',
    );
    if (!yes || !mounted) return;
    try {
      await ref
          .read(venueSetupServiceProvider)
          .removeTableType(widget.venueId, t.typeId);
      if (!mounted) return;
      _refresh();
      say(context, 'Table removed.');
    } on SetupEditException catch (e) {
      if (mounted) say(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = ref.watch(tableTypesProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-table'),
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Add a table'),
      ),
      body: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => EditorLoadError(
              error: e,
              onRetry: () => ref.invalidate(tableTypesProvider(widget.venueId)),
            ),
        data:
            (list) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  'Each kind of table has its own capacity, minimum spend and deposit.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (list.isEmpty)
                  Container(
                    key: const Key('no-tables'),
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No tables yet. Add the first kind of table guests can book.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final t in list)
                  Card(
                    key: Key('table-${t.typeId}'),
                    margin: const EdgeInsets.only(top: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.imageUrl != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: PhotoThumb(key: Key('thumb-${t.typeId}'), url: t.imageUrl!)),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  t.name,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (t.isFeatured) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Ionicons.star,
                                  key: Key('featured'),
                                  size: 16,
                                  color: Color(0xFFFFB300),
                                ),
                              ],
                              if (t.badgeLabel != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outline,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    t.badgeLabel!,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            describeTablePrice(t),
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${t.minGuests != null ? '${t.minGuests} to ${t.maxGuests}' : 'Up to ${t.maxGuests}'} guests · '
                            '${t.inventoryCount == 0 ? 'none available to book' : '${t.inventoryCount} ${t.inventoryCount == 1 ? 'table' : 'tables'}'}'
                            '${t.floorId != null ? ' · placed on a floor plan' : ''}'
                            '${t.bookingCount > 0 ? ' · ${t.bookingCount} ${t.bookingCount == 1 ? 'booking' : 'bookings'}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (t.bookingCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'It has bookings, so it cannot be removed. Set the number of tables to 0 to stop new bookings.',
                                key: Key('protected-${t.typeId}'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                key: Key('edit-${t.typeId}'),
                                onPressed: () => _openForm(t),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                key: Key('remove-${t.typeId}'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF5350),
                                ),
                                onPressed:
                                    t.bookingCount > 0
                                        ? null
                                        : () => _remove(t),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}
