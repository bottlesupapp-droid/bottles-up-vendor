import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../features/auth/providers/supabase_auth_provider.dart';
import '../../../features/venues/providers/venues_provider.dart';
import '../../../features/venues/services/venue_request_service.dart';
import '../../../shared/models/venue_model.dart';

class EditVenueScreen extends ConsumerStatefulWidget {
  final String venueId;
  final Venue? initialVenue;

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
    'Afrobeats': false,
    'Amapiano': false,
    'Hip-Hop': false,
    'Dancehall': false,
    'R&B': false,
    'Open Format': false,
    'EDM': false,
    'Reggae': false,
  };
  final Map<String, bool> _amenities = {
    'VIP Booth Reservations': false,
    'Reserved Table Service': false,
    'Bottle Service': false,
    'Birthday Celebrations': false,
    'Private Events': false,
    'Digital Ticketing': false,
    'QR Code Entry': false,
    'Professional DJ Entertainment': false,
    'Group Reservations': false,
    'Guest List Access': false,
  };

  // Categorised photos
  String? _bannerPhoto;
  List<String> _interiorPhotos = [];
  List<String> _menuPhotos = [];
  bool _isUploadingPhoto = false;

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
    _capacityCtrl =
        TextEditingController(text: v?.capacity?.toString() ?? '');
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

    // Categorised photos – read from social_links
    _bannerPhoto = sl['banner_photo'] as String?;
    _interiorPhotos = List<String>.from(sl['interior_photos'] ?? []);
    _menuPhotos = List<String>.from(sl['menu_photos'] ?? []);

    // Fallback: if we have a flat gallery but no categorised photos yet,
    // treat the first image as the banner and the rest as interior.
    if (_bannerPhoto == null && _interiorPhotos.isEmpty) {
      final flat = List<String>.from(v?.gallery ?? []);
      if (flat.isNotEmpty) {
        _bannerPhoto = flat.first;
        if (flat.length > 1) _interiorPhotos = flat.sublist(1);
      }
    }
  }

  // ── Photo upload ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto(String category) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Uploading image...'),
          ]),
          duration: Duration(seconds: 30),
        ),
      );

      final currentUser = ref.read(currentVendorUserProvider);
      if (currentUser == null) throw Exception('Not authenticated');

      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${currentUser.id}/${category}_$ts.$ext';

      await SupabaseConfig.client.storage.from('venue-gallery').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
          );

      final url = SupabaseConfig.client.storage
          .from('venue-gallery')
          .getPublicUrl(fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          switch (category) {
            case 'banner':
              _bannerPhoto = url;
              break;
            case 'interior':
              _interiorPhotos.add(url);
              break;
            case 'menu':
              _menuPhotos.add(url);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

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

      final selectedGenres = _musicGenres.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (selectedGenres.isNotEmpty)
        socialLinks['music_genres'] = selectedGenres;

      final selectedAmenities = _amenities.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (selectedAmenities.isNotEmpty)
        socialLinks['amenities'] = selectedAmenities;

      // Categorised photos
      if (_bannerPhoto != null) socialLinks['banner_photo'] = _bannerPhoto;
      socialLinks['interior_photos'] = _interiorPhotos;
      socialLinks['menu_photos'] = _menuPhotos;

      // Preserve any extra keys from the original social_links
      final existing = widget.initialVenue?.socialLinks ?? {};
      for (final key in [
        'bottlesup_features',
        'reservation_options',
      ]) {
        if (existing[key] != null) socialLinks[key] = existing[key];
      }

      // Build flat gallery for backward compat (card previews etc.)
      final gallery = [
        if (_bannerPhoto != null) _bannerPhoto!,
        ..._interiorPhotos,
        ..._menuPhotos,
      ];

      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'address': address,
        'location':
            '${_streetCtrl.text.trim()}, ${_cityCtrl.text.trim()}, '
            '${_stateCtrl.text.trim()}, ${_countryCtrl.text.trim()}',
        'social_links': socialLinks.isEmpty ? null : socialLinks,
        'gallery': gallery,
        // Mark venue as active when the owner saves completed details
        'status': 'active',
        'is_active': true,
        if (_capacityCtrl.text.isNotEmpty)
          'capacity': int.tryParse(_capacityCtrl.text.trim()),
        if (_descCtrl.text.isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty)
          'contact_number': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
      };

      final service = ref.read(venueRequestServiceProvider);
      await service.updateVenue(venueId: widget.venueId, updates: updates);

      ref.invalidate(myVenuesProvider);
      ref.invalidate(venueByIdProvider(widget.venueId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              // ── Basic Info ──────────────────────────────────────────────
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
                Expanded(
                    flex: 2,
                    child: _field(_cityCtrl, 'City *',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_stateCtrl, 'Province *',
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

              // ── Venue Details ───────────────────────────────────────────
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
                Expanded(
                    child: _field(_vipBoothsCtrl, 'VIP Booths',
                        keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_sideTablesCtrl, 'Side Tables',
                        keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              _field(_dressCodeCtrl, 'Dress Code', maxLines: 2),

              // ── Music Genres ────────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle(theme, 'Music Genres'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _musicGenres.keys
                    .map((g) => FilterChip(
                          label: Text(g),
                          selected: _musicGenres[g]!,
                          onSelected: (v) =>
                              setState(() => _musicGenres[g] = v),
                        ))
                    .toList(),
              ),

              // ── Amenities ───────────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle(theme, 'Amenities'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amenities.keys
                    .map((a) => FilterChip(
                          label: Text(a),
                          selected: _amenities[a]!,
                          onSelected: (v) =>
                              setState(() => _amenities[a] = v),
                        ))
                    .toList(),
              ),

              // ── Photos (categorised) ────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle(theme, 'Photos'),
              const SizedBox(height: 4),
              Text(
                'Add categorised photos to help guests know your venue.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),

              // Banner / Logo
              const SizedBox(height: 16),
              _photoSubtitle(theme, 'Banner / Logo',
                  'Main image shown on listings'),
              const SizedBox(height: 8),
              _buildBannerSection(theme),

              // Interior
              const SizedBox(height: 20),
              _photoSubtitle(
                  theme, 'Interior Photos', 'Dance floor, VIP area, décor'),
              const SizedBox(height: 8),
              if (_interiorPhotos.isNotEmpty) ...[
                _buildPhotoGrid(theme, _interiorPhotos, 'interior'),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed:
                    _isUploadingPhoto ? null : () => _pickPhoto('interior'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Interior Photo'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16)),
              ),

              // Menu
              const SizedBox(height: 20),
              _photoSubtitle(theme, 'Menu Photos',
                  'Bottle menu, food menu, pricing'),
              const SizedBox(height: 8),
              if (_menuPhotos.isNotEmpty) ...[
                _buildPhotoGrid(theme, _menuPhotos, 'menu'),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed:
                    _isUploadingPhoto ? null : () => _pickPhoto('menu'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Menu Photo'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16)),
              ),

              // ── Contact ─────────────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle(theme, 'Contact'),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone Number',
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email',
                  keyboard: TextInputType.emailAddress),

              // ── Submit ──────────────────────────────────────────────────
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.white)))
                      : const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo widgets ──────────────────────────────────────────────────────────

  Widget _buildBannerSection(ThemeData theme) {
    if (_isUploadingPhoto && _bannerPhoto == null) {
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
            Text('Uploading...'),
          ]),
        ),
      );
    }
    if (_bannerPhoto != null) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _bannerPhoto!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 160,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(children: [
            _overlayBtn(
                Icons.edit_outlined,
                _isUploadingPhoto
                    ? null
                    : () => _pickPhoto('banner')),
            const SizedBox(width: 4),
            _overlayBtn(
                Icons.close,
                () => setState(() => _bannerPhoto = null),
                color: Colors.red),
          ]),
        ),
      ]);
    }
    return OutlinedButton.icon(
      onPressed: _isUploadingPhoto ? null : () => _pickPhoto('banner'),
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('Add Banner Photo'),
      style: OutlinedButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
    );
  }

  Widget _buildPhotoGrid(
      ThemeData theme, List<String> photos, String category) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photos[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _overlayBtn(Icons.close, () {
              setState(() {
                if (category == 'interior') {
                  _interiorPhotos.removeAt(index);
                } else if (category == 'menu') {
                  _menuPhotos.removeAt(index);
                }
              });
            }, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _overlayBtn(IconData icon, VoidCallback? onTap,
          {Color? color}) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 16),
        ),
      );

  // ── Field / section helpers ────────────────────────────────────────────────

  Widget _sectionTitle(ThemeData theme, String title) => Text(
        title,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _photoSubtitle(ThemeData theme, String title, String sub) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(sub,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
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
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          prefixIcon: prefix,
          suffixText: suffix,
          alignLabelWithHint: maxLines > 1,
        ),
      );
}
