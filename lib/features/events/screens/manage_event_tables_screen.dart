import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Table',
            onPressed: () => _showAddTableDialog(context, ref),
          ),
        ],
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.table_restaurant_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tables yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                    'Add tables so customers can make\nVIP table reservations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTableDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Table'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventTablesProvider(eventId)),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 80),
              itemCount: tables.length,
              itemBuilder: (context, index) =>
                  _TableCard(table: tables[index], eventId: eventId),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: tablesAsync.maybeWhen(
        data: (t) => t.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showAddTableDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Table'),
              ),
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
    final isActive = table['is_active'] as bool? ?? true;
    final isVip = table['is_vip'] as bool? ?? false;
    final price = (table['price'] as num?)?.toDouble() ?? 0;
    final capacity = table['capacity'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isVip
              ? Colors.orange.withOpacity(0.15)
              : Colors.blue.withOpacity(0.15),
          child: Icon(
            isVip ? Icons.star : Icons.table_restaurant,
            color: isVip ? Colors.orange : Colors.blue,
          ),
        ),
        title: Row(
          children: [
            Text(
              table['name'] ?? 'Unnamed',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isVip) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Capacity: $capacity guests · Deposit: \$${price.toStringAsFixed(0)}'),
            if (table['location_description'] != null)
              Text(
                table['location_description'],
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isActive,
              onChanged: (val) => _toggleActive(context, ref, val),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, ref),
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              content: Text('Failed to add table: $e'),
              backgroundColor: Colors.red),
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
                  color: Colors.grey[300],
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
                border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Location description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Location / Description — optional',
                hintText: 'e.g. Front left, near stage',
                border: OutlineInputBorder(),
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
