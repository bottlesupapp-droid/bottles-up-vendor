import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../core/ui/bu_kit.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final eventTablesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final response = await SupabaseConfig.client
      .from('event_tables')
      .select()
      .eq('event_id', eventId)
      .order('created_at', ascending: true);
  return (response as List<dynamic>)
      .map((t) => Map<String, dynamic>.from(t))
      .toList();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ManageEventTablesScreen extends ConsumerWidget {
  final String eventId;
  const ManageEventTablesScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(eventTablesProvider(eventId));
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BuDetailAppBar(
        eyebrow: 'Event',
        title: 'Table Management',
        actions: [IconButton(key: const Key('tables-add'), icon: const Icon(Ionicons.add), tooltip: 'Add Table', onPressed: () => _showAddTableDialog(context, ref))],
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  key: const Key('tables-empty'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BuIconTile(icon: Icons.table_restaurant_outlined, size: 56),
                    const SizedBox(height: BuSpace.l),
                    Text('No tables yet', style: text.titleLarge),
                    const SizedBox(height: BuSpace.s),
                    Text('Add tables so customers can make\nVIP table reservations.', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: bu.muted)),
                    const SizedBox(height: BuSpace.xl),
                    FilledButton.icon(key: const Key('tables-add-first'), onPressed: () => _showAddTableDialog(context, ref), icon: const Icon(Ionicons.add), label: const Text('Add First Table')),
                  ],
                ),
              ),
            );
          }
          final active = tables.where((t) => (t['is_active'] as bool? ?? true)).length;
          final vip = tables.where((t) => (t['is_vip'] as bool? ?? false)).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventTablesProvider(eventId)),
            child: ListView(
              key: const Key('tables-list'),
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 88), // room for the Add button
              children: [
                Row(
                  children: [
                    Expanded(child: _Figure(label: 'Tables', value: '${tables.length}', figureKey: const Key('tables-total'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'On sale', value: '$active', figureKey: const Key('tables-active'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'VIP', value: '$vip', figureKey: const Key('tables-vip'))),
                  ],
                ),
                const SizedBox(height: BuSpace.l),
                for (final t in tables) _TableCard(table: t, eventId: eventId),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(couldNotLoad('this page', e))),
      ),
      floatingActionButton: tablesAsync.maybeWhen(
        data: (t) => t.isEmpty ? null : FloatingActionButton.extended(key: const Key('tables-fab'), onPressed: () => _showAddTableDialog(context, ref), icon: const Icon(Ionicons.add), label: const Text('Add Table')),
        orElse: () => null,
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddTableSheet(
        eventId: eventId,
        onSaved: () => ref.invalidate(eventTablesProvider(eventId)),
      ),
    );
  }
}

// ─── Table card ──────────────────────────────────────────────────────────────

class _TableCard extends ConsumerWidget {
  final Map<String, dynamic> table;
  final String eventId;
  const _TableCard({required this.table, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final isActive = table['is_active'] as bool? ?? true;
    final isVip = table['is_vip'] as bool? ?? false;
    final price = (table['price'] as num?)?.toDouble() ?? 0;
    final capacity = table['capacity'] as int? ?? 0;
    final tint = isVip ? bu.amber : bu.orangeSoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('table-${table['id']}'),
        padding: const EdgeInsets.all(BuSpace.m + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(BuRadius.control)),
              child: Icon(isVip ? Ionicons.star : Icons.table_restaurant, color: tint, size: 22),
            ),
            const SizedBox(width: BuSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(table['name'] ?? 'Unnamed', style: text.titleMedium),
                      if (isVip) const BuStatusPill('VIP', tone: BuTone.attention),
                      if (!isActive) const BuStatusPill('Off sale'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Capacity: $capacity guests · Deposit: \$${price.toStringAsFixed(0)}', style: text.bodySmall?.copyWith(color: bu.muted)),
                  if (table['location_description'] != null) Text('${table['location_description']}', style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              children: [
                Switch(key: Key('table-switch-${table['id']}'), value: isActive, onChanged: (val) => _toggleActive(context, ref, val)),
                IconButton(key: Key('table-delete-${table['id']}'), icon: Icon(Ionicons.trash_outline, color: bu.red), onPressed: () => _confirmDelete(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, bool active) async {
    await SupabaseConfig.client
        .from('event_tables')
        .update({'is_active': active})
        .eq('id', table['id']);
    ref.invalidate(eventTablesProvider(eventId));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete table?'),
        content: Text('Remove "${table['name']}" from this event?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: BuTokens.dark.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseConfig.client
          .from('event_tables')
          .delete()
          .eq('id', table['id']);
      ref.invalidate(eventTablesProvider(eventId));
    }
  }
}

// ─── Add table bottom sheet ───────────────────────────────────────────────────

class _AddTableSheet extends StatefulWidget {
  final String eventId;
  final VoidCallback onSaved;
  const _AddTableSheet({required this.eventId, required this.onSaved});

  @override
  State<_AddTableSheet> createState() => _AddTableSheetState();
}

class _AddTableSheetState extends State<_AddTableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '4');
  final _priceCtrl = TextEditingController(text: '100');
  final _minSpendCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isVip = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _minSpendCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseConfig.client.from('event_tables').insert({
        'event_id': widget.eventId,
        'name': _nameCtrl.text.trim(),
        'capacity': int.parse(_capacityCtrl.text.trim()),
        'price': double.parse(_priceCtrl.text.trim()),
        'minimum_spend': _minSpendCtrl.text.trim().isEmpty
            ? null
            : double.parse(_minSpendCtrl.text.trim()),
        'location_description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'is_vip': _isVip,
        'is_active': true,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(couldNot('add table', e)),
              backgroundColor: BuTokens.dark.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BuTokens.dark.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Table',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Table Name *',
                hintText: 'e.g. VIP Booth 1, Table A',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a table name' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Capacity
                Expanded(
                  child: TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity *',
                      hintText: '4',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Deposit price
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Deposit (\$) *',
                      hintText: '100',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Min spend
            TextFormField(
              controller: _minSpendCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Spend (\$) — optional',
                hintText: 'e.g. 500',
              ),
            ),
            const SizedBox(height: 12),

            // Location description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Location / Description — optional',
                hintText: 'e.g. Front left, near stage',
              ),
            ),
            const SizedBox(height: 12),

            // VIP toggle
            SwitchListTile(
              value: _isVip,
              onChanged: (v) => setState(() => _isVip = v),
              title: const Text('Mark as VIP table'),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Table'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the figures at the top of a list page: a big number over a small label.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.figureKey});

  final String label;
  final String value;
  final Key figureKey;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, key: figureKey, style: text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
