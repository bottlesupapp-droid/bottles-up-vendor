import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../features/auth/providers/supabase_auth_provider.dart';
import '../../../features/venues/providers/venues_provider.dart';
import '../providers/event_list_provider.dart';

// ── Ticket tier data model ──────────────────────────────────────────────────

class _TicketTier {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController capacityCtrl;
  String type;

  _TicketTier({
    String name = 'General Admission',
    String type = 'general',
    String price = '0',
    String capacity = '100',
  })  : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price),
        capacityCtrl = TextEditingController(text: capacity),
        type = type;

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    capacityCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'name': nameCtrl.text.trim(),
        'type': type,
        'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
        'capacity': int.tryParse(capacityCtrl.text.trim()) ?? 0,
      };
}

// ── Screen ──────────────────────────────────────────────────────────────────

class SimpleCreateEventScreen extends ConsumerStatefulWidget {
  const SimpleCreateEventScreen({super.key});

  @override
  ConsumerState<SimpleCreateEventScreen> createState() =>
      _SimpleCreateEventScreenState();
}

class _SimpleCreateEventScreenState
    extends ConsumerState<SimpleCreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dressCodeCtrl = TextEditingController();
  final _minAgeCtrl = TextEditingController(text: '19');

  String? _selectedVenueId;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 3, minute: 0);

  String? _flyerImageUrl;
  bool _isUploadingFlyer = false;
  bool _isSubmitting = false;

  final List<_TicketTier> _tiers = [];

  static const _tierTypes = ['general', 'vip', 'table', 'vvip'];
  static const _tierLabels = {
    'general': 'General',
    'vip': 'VIP',
    'table': 'Table',
    'vvip': 'VVIP',
  };

  @override
  void initState() {
    super.initState();
    // Default: one General Admission tier
    _tiers.add(_TicketTier());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _dressCodeCtrl.dispose();
    _minAgeCtrl.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _eventDate = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (t != null) {
      setState(() => isStart ? _startTime = t : _endTime = t);
    }
  }

  Future<void> _pickFlyer() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _isUploadingFlyer = true);

      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final userId = ref.read(currentVendorUserProvider)?.id ?? 'unknown';
      final fileName =
          'flyers/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseConfig.client.storage.from('media').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url = SupabaseConfig.client.storage
          .from('media')
          .getPublicUrl(fileName);

      if (mounted) setState(() => _flyerImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload flyer: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingFlyer = false);
    }
  }

  // ── Tier management ────────────────────────────────────────────────────────

  void _addTier() {
    setState(() {
      _tiers.add(_TicketTier(
        name: 'New Zone',
        type: 'general',
        price: '0',
        capacity: '50',
      ));
    });
  }

  void _removeTier(int index) {
    if (_tiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one ticket zone is required')),
      );
      return;
    }
    setState(() {
      _tiers[index].dispose();
      _tiers.removeAt(index);
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(currentVendorUserProvider);
      if (user == null) throw Exception('Not authenticated');

      final totalCapacity = _tiers.fold<int>(
        0,
        (sum, t) => sum + (int.tryParse(t.capacityCtrl.text.trim()) ?? 0),
      );
      final basePrice =
          double.tryParse(_tiers.first.priceCtrl.text.trim()) ?? 0.0;
      final ticketTiers = _tiers.map((t) => t.toJson()).toList();

      String _fmt(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'club_id': _selectedVenueId,
        'user_id': user.id,
        'event_date': _eventDate.toIso8601String().split('T')[0],
        'start_time': _fmt(_startTime),
        'end_time': _fmt(_endTime),
        'ticket_price': basePrice,
        'max_capacity': totalCapacity,
        'status': 'active',
        'is_active': true,
        'ticket_tiers': ticketTiers,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_flyerImageUrl != null) 'flyer_image_url': _flyerImageUrl,
        if (_dressCodeCtrl.text.trim().isNotEmpty)
          'dress_code': _dressCodeCtrl.text.trim(),
        if (_minAgeCtrl.text.trim().isNotEmpty)
          'min_age': int.tryParse(_minAgeCtrl.text.trim()),
      };

      await SupabaseConfig.client.from('events').insert(data);

      // Refresh the events list
      for (final tab in ['active', 'draft', 'past', 'templates']) {
        ref.invalidate(filteredEventsProvider(tab));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create event: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venuesAsync = ref.watch(myVenuesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Event',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _createEvent,
              child: Text('Create',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
        ],
      ),
      body: venuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load venues: $e')),
        data: (venues) {
          if (venues.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_city, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No Venues Found',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Create a venue first before creating events.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/clubs/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Venue'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildForm(theme, venues);
        },
      ),
    );
  }

  Widget _buildForm(ThemeData theme, List venues) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom + 80),
        children: [
          // ── Event Info ──────────────────────────────────────────────────
          _sectionTitle(theme, 'Event Info'),
          const SizedBox(height: 12),
          _field(_nameCtrl, 'Event Name *',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          _field(_descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedVenueId,
            decoration: InputDecoration(
              labelText: 'Venue *',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            items: venues
                .map<DropdownMenuItem<String>>((v) => DropdownMenuItem(
                      value: v.id as String,
                      child: Text(v.name as String),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedVenueId = v),
            validator: (v) => v == null ? 'Select a venue' : null,
          ),
          const SizedBox(height: 24),

          // ── Date & Time ──────────────────────────────────────────────────
          _sectionTitle(theme, 'Date & Time'),
          const SizedBox(height: 12),
          _pickerTile(
            theme,
            icon: Icons.calendar_today_outlined,
            label: 'Event Date',
            value:
                '${_eventDate.day.toString().padLeft(2, '0')}/${_eventDate.month.toString().padLeft(2, '0')}/${_eventDate.year}',
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _pickerTile(theme,
                    icon: Icons.access_time_outlined,
                    label: 'Start',
                    value: _startTime.format(context),
                    onTap: () => _pickTime(true))),
            const SizedBox(width: 12),
            Expanded(
                child: _pickerTile(theme,
                    icon: Icons.access_time_outlined,
                    label: 'End',
                    value: _endTime.format(context),
                    onTap: () => _pickTime(false))),
          ]),
          const SizedBox(height: 24),

          // ── Ticket Zones ─────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _sectionTitle(theme, 'Ticket Zones')),
            TextButton.icon(
              onPressed: _addTier,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Zone'),
            ),
          ]),
          Text(
            'Define ticket types and prices. Total capacity = sum of all zones.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ..._tiers.asMap().entries.map((e) => _buildTierCard(theme, e.key, e.value)),
          const SizedBox(height: 24),

          // ── Event Flyer ──────────────────────────────────────────────────
          _sectionTitle(theme, 'Event Flyer'),
          const SizedBox(height: 12),
          _buildFlyerSection(theme),
          const SizedBox(height: 24),

          // ── Optional Details ─────────────────────────────────────────────
          _sectionTitle(theme, 'Optional Details'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_minAgeCtrl, 'Min Age',
                    keyboard: TextInputType.number, suffix: '+')),
            const SizedBox(width: 12),
            Expanded(
                flex: 2, child: _field(_dressCodeCtrl, 'Dress Code')),
          ]),
          const SizedBox(height: 32),

          // ── Submit ────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _createEvent,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white)))
                  : const Text('Create Event',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Tier card ──────────────────────────────────────────────────────────────

  Widget _buildTierCard(ThemeData theme, int index, _TicketTier tier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Zone ${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (_tiers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _removeTier(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Name + Type row
            Row(children: [
              Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: tier.nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Zone Name *',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      isDense: true,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  )),
              const SizedBox(width: 8),
              Expanded(
                  child: DropdownButtonFormField<String>(
                value: tier.type,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  isDense: true,
                ),
                items: _tierTypes
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_tierLabels[t]!,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => tier.type = v ?? 'general'),
              )),
            ]),
            const SizedBox(height: 8),

            // Price + Capacity row
            Row(children: [
              Expanded(
                  child: TextFormField(
                controller: tier.priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                },
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                controller: tier.capacityCtrl,
                decoration: InputDecoration(
                  labelText: 'Capacity',
                  suffixText: 'spots',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                },
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Flyer section ──────────────────────────────────────────────────────────

  Widget _buildFlyerSection(ThemeData theme) {
    if (_isUploadingFlyer) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text('Uploading flyer...'),
          ]),
        ),
      );
    }
    if (_flyerImageUrl != null) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _flyerImageUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(children: [
            _iconBtn(Icons.edit_outlined, _pickFlyer),
            const SizedBox(width: 4),
            _iconBtn(Icons.close,
                () => setState(() => _flyerImageUrl = null),
                color: Colors.red),
          ]),
        ),
      ]);
    }
    return OutlinedButton.icon(
      onPressed: _pickFlyer,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('Upload Event Flyer'),
      style: OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle),
          child: Icon(icon, color: color ?? Colors.white, size: 16),
        ),
      );

  Widget _pickerTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Text(value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      );

  Widget _sectionTitle(ThemeData theme, String title) => Text(
        title,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    String? suffix,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          alignLabelWithHint: maxLines > 1,
        ),
      );
}
