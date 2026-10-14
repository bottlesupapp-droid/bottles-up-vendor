import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/setup_forms.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/setup_common.dart';
import 'bottle_form_screen.dart';

/// Bottle menu (owner): the bottles guests can order. Taking one off the menu or marking it sold out is one tap, without opening
/// the form; those taps send only that one field. Removing a bottle never changes a past order, which keeps its own copy of the
/// name and price.
class BottleMenuEditor extends ConsumerStatefulWidget {
  const BottleMenuEditor({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<BottleMenuEditor> createState() => _BottleMenuEditorState();
}

class _BottleMenuEditorState extends ConsumerState<BottleMenuEditor> {
  bool _busy = false;

  void _refresh() => refreshAfterChange(
    ref,
    widget.venueId,
    () => ref.invalidate(bottlesProvider(widget.venueId)),
  );

  Future<void> _quick(BottleRow b, Map<String, dynamic> details) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(venueSetupServiceProvider)
          .saveBottle(widget.venueId, b.bottleId, details);
      if (mounted) _refresh();
    } on SetupEditException catch (e) {
      if (mounted) say(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm(BottleRow? row) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BottleFormScreen(venueId: widget.venueId, row: row),
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      say(context, row == null ? 'Bottle added.' : 'Bottle saved.');
    }
  }

  Future<void> _remove(BottleRow b) async {
    final yes = await confirmRemove(
      context,
      title: 'Remove ${b.name}?',
      body:
          'It leaves the menu. Past orders keep the name and price they were bought at.',
    );
    if (!yes || !mounted) return;
    try {
      await ref
          .read(venueSetupServiceProvider)
          .removeBottle(widget.venueId, b.bottleId);
      if (!mounted) return;
      _refresh();
      say(context, 'Bottle removed.');
    } on SetupEditException catch (e) {
      if (mounted) say(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottles = ref.watch(bottlesProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Bottle menu')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-bottle'),
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Add a bottle'),
      ),
      body: bottles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => EditorLoadError(
              error: e,
              onRetry: () => ref.invalidate(bottlesProvider(widget.venueId)),
            ),
        data:
            (list) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  'Bottles guests can order for their table.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Container(
                    key: const Key('no-bottles'),
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'No bottles yet. Add the first one to start your menu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final b in list) _tile(context, b),
              ],
            ),
      ),
    );
  }

  Widget _tile(BuildContext context, BottleRow b) {
    final theme = Theme.of(context);
    final (label, color) = switch (bottleState(b)) {
      BottleState.available => ('On menu', const Color(0xFF66BB6A)),
      BottleState.soldOut => ('Sold out', const Color(0xFFFFB300)),
      BottleState.offMenu => ('Off the menu', const Color(0xFF9E9E9E)),
    };
    return Card(
      key: Key('bottle-${b.bottleId}'),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${b.name}${b.size == null ? '' : '  ${b.size}'}',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: Key('state-${b.bottleId}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            Text(
              '${formatDollars(b.priceCents)}${b.category == null ? '' : ' · ${b.category}'}${b.stockQuantity == null ? '' : ' · ${b.stockQuantity} in stock'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('On menu'),
                Switch(
                  key: Key('on-menu-${b.bottleId}'),
                  value: b.isAvailable,
                  onChanged:
                      _busy ? null : (v) => _quick(b, {'is_available': v}),
                ),
                const SizedBox(width: 8),
                const Text('Sold out'),
                Switch(
                  key: Key('sold-out-${b.bottleId}'),
                  value: b.isSoldOut,
                  onChanged:
                      _busy ? null : (v) => _quick(b, {'is_sold_out': v}),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('edit-${b.bottleId}'),
                  onPressed: () => _openForm(b),
                  child: const Text('Edit'),
                ),
                TextButton(
                  key: Key('remove-${b.bottleId}'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                  ),
                  onPressed: () => _remove(b),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
