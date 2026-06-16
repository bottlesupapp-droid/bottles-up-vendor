import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/venues/providers/venues_provider.dart';
import '../../../features/venues/services/venue_request_service.dart';
import '../../../shared/models/venue_model.dart';

class EditVenueScreen extends ConsumerStatefulWidget {
  final String venueId;
  final Venue? initialVenue; // passed via route extra

  const EditVenueScreen({
    super.key,
    required this.venueId,
    this.initialVenue,
  });

  @override
  ConsumerState<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends ConsumerState<EditVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Basic info
  late final TextEditingController _nameCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _descCtrl;

  // Details
  late final TextEditingController _venueTypeCtrl;
  late final TextEditingController _minAgeCtrl;
  late final TextEditingController _dressCodeCtrl;
  late final TextEditingController _vipBoothsCtrl;
  late final TextEditingController _sideTablesCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  // Toggles
  final Map<String, bool> _musicGenres = {
    'Afrobeats': false, 'Amapiano': false, 'Hip-Hop': false,
    'Dancehall': false, 'R&B': false, 'Open Format': false,
    'EDM': false, 'Reggae': false,
  };
  final Map<String, bool> _amenities = {
    'VIP Booth Reservations': false, 'Reserved Table Service': false,
    'Bottle Service': false, 'Birthday Celebrations': false,
    'Private Events': false, 'Digital Ticketing': false,
    'QR Code Entry': false, 'Professional DJ Entertainment': false,
    'Group Reservations': false, 'Guest List Access': false,
  };

  @override
  void initState() {
    super.initState();
    final v = widget.initialVenue;
    final addr = v?.address ?? {};
    final sl = v?.socialLinks ?? {};

    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _streetCtrl = TextEditingController(text: addr['street'] ?? '');
    _cityCtrl = TextEditingController(text: addr['city'] ?? '');
    _stateCtrl = TextEditingController(text: addr['state'] ?? '');
    _zipCtrl = TextEditingController(text: addr['zip'] ?? '');
    _countryCtrl = TextEditingController(text: addr['country'] ?? 'Canada');
    _capacityCtrl = TextEditingController(
        text: v?.capacity?.toString() ?? '');
    _descCtrl = TextEditingController(text: v?.description ?? '');
    _venueTypeCtrl =
        TextEditingController(text: sl['venue_type']?.toString() ?? '');
    _minAgeCtrl =
        TextEditingController(text: sl['min_age']?.toString() ?? '19');
    _dressCodeCtrl =
        TextEditingController(text: sl['dress_code']?.toString() ?? '');
    _vipBoothsCtrl =
        TextEditingController(text: sl['vip_booths']?.toString() ?? '');
    _sideTablesCtrl =
        TextEditingController(text: sl['side_tables']?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: v?.phone ?? '');
    _emailCtrl = TextEditingController(text: v?.email ?? '');

    // Pre-select genres & amenities
    for (final g in (sl['music_genres'] as List? ?? [])) {
      if (_musicGenres.containsKey(g)) _musicGenres[g] = true;
    }
    for (final a in (sl['amenities'] as List? ?? [])) {
      if (_amenities.containsKey(a)) _amenities[a] = true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _streetCtrl, _cityCtrl, _stateCtrl, _zipCtrl,
      _countryCtrl, _capacityCtrl, _descCtrl, _venueTypeCtrl,
      _minAgeCtrl, _dressCodeCtrl, _vipBoothsCtrl, _sideTablesCtrl,
      _phoneCtrl, _emailCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final address = {
        'street': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'zip': _zipCtrl.text.trim().isEmpty ? null : _zipCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
      };

      final socialLinks = <String, dynamic>{};
      if (_venueTypeCtrl.text.isNotEmpty)
        socialLinks['venue_type'] = _venueTypeCtrl.text.trim();
      if (_minAgeCtrl.text.isNotEmpty)
        socialLinks['min_age'] = int.tryParse(_minAgeCtrl.text.trim());
      if (_dressCodeCtrl.text.isNotEmpty)
        socialLinks['dress_code'] = _dressCodeCtrl.text.trim();
      if (_vipBoothsCtrl.text.isNotEmpty)
        socialLinks['vip_booths'] = int.tryParse(_vipBoothsCtrl.text.trim());
      if (_sideTablesCtrl.text.isNotEmpty)
        socialLinks['side_tables'] =
            int.tryParse(_sideTablesCtrl.text.trim());

      final selectedGenres =
          _musicGenres.entries.where((e) => e.value).map((e) => e.key).toList();
      if (selectedGenres.isNotEmpty) socialLinks['music_genres'] = selectedGenres;

      final selectedAmenities =
          _amenities.entries.where((e) => e.value).map((e) => e.key).toList();
      if (selectedAmenities.isNotEmpty)
        socialLinks['amenities'] = selectedAmenities;

      // Keep existing bottlesup_features / reservation_options if present
      final existing = widget.initialVenue?.socialLinks ?? {};
      if (existing['bottlesup_features'] != null)
        socialLinks['bottlesup_features'] = existing['bottlesup_features'];
      if (existing['reservation_options'] != null)
        socialLinks['reservation_options'] = existing['reservation_options'];

      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'address': address,
        'location':
            '${_streetCtrl.text.trim()}, ${_cityCtrl.text.trim()}, ${_stateCtrl.text.trim()}, ${_countryCtrl.text.trim()}',
        'social_links': socialLinks.isEmpty ? null : socialLinks,
        if (_capacityCtrl.text.isNotEmpty)
          'capacity': int.tryParse(_capacityCtrl.text.trim()),
        if (_descCtrl.text.isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty)
          'contact_number': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty)
          'email': _emailCtrl.text.trim(),
      };

      final service = ref.read(venueRequestServiceProvider);
      await service.updateVenue(venueId: widget.venueId, updates: updates);

      // Invalidate both providers so the list and detail refresh
      ref.invalidate(myVenuesProvider);
      ref.invalidate(venueByIdProvider(widget.venueId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Venue updated successfully'),
              backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Venue',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, 'Basic Information'),
              const SizedBox(height: 12),

              _field(_nameCtrl, 'Venue Name *',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _field(_streetCtrl, 'Street Address *',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(flex: 2, child: _field(_cityCtrl, 'City *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(child: _field(_stateCtrl, 'Province *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_zipCtrl, 'Postal Code')),
                const SizedBox(width: 12),
                Expanded(child: _field(_countryCtrl, 'Country')),
              ]),
              const SizedBox(height: 12),
              _field(_capacityCtrl, 'Capacity',
                  keyboard: TextInputType.number,
                  prefix: const Icon(Icons.people_outline, size: 18)),
              const SizedBox(height: 12),
              _field(_descCtrl, 'About the Venue', maxLines: 4),

              const SizedBox(height: 24),
              _sectionTitle(theme, 'Venue Details'),
              const SizedBox(height: 12),

              _field(_venueTypeCtrl, 'Venue Type',
                  hint: 'e.g., Lounge & Nightclub'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _field(_minAgeCtrl, 'Min Age',
                        keyboard: TextInputType.number, suffix: '+')),
                const SizedBox(width: 12),
                Expanded(child: _field(_vipBoothsCtrl, 'VIP Booths',
                    keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(_sideTablesCtrl, 'Side Tables',
                    keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              _field(_dressCodeCtrl, 'Dress Code', maxLines: 2),

              const SizedBox(height: 24),
              _sectionTitle(theme, 'Music Genres'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _musicGenres.keys.map((g) => FilterChip(
                  label: Text(g),
                  selected: _musicGenres[g]!,
                  onSelected: (v) => setState(() => _musicGenres[g] = v),
                )).toList(),
              ),

              const SizedBox(height: 24),
              _sectionTitle(theme, 'Amenities'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amenities.keys.map((a) => FilterChip(
                  label: Text(a),
                  selected: _amenities[a]!,
                  onSelected: (v) => setState(() => _amenities[a] = v),
                )).toList(),
              ),

              const SizedBox(height: 24),
              _sectionTitle(theme, 'Contact'),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone Number',
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email',
                  keyboard: TextInputType.emailAddress),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) => Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    Widget? prefix,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          prefixIcon: prefix,
          suffixText: suffix,
          alignLabelWithHint: maxLines > 1,
        ),
      );
}
