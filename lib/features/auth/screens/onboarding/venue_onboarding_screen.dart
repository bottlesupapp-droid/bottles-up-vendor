import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/supabase_config.dart';
import '../../providers/supabase_auth_provider.dart';

class VenueOnboardingScreen extends ConsumerStatefulWidget {
  const VenueOnboardingScreen({super.key});

  @override
  ConsumerState<VenueOnboardingScreen> createState() => _VenueOnboardingScreenState();
}

class _VenueOnboardingScreenState extends ConsumerState<VenueOnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4; // Basic Info -> Details -> Photos -> Review
  bool _isSubmitting = false;
  final Set<int> _skippedSteps = {};

  // Step 1: Venue Basic Info
  final _venueNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController(text: 'Canada');
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 2: Venue Details
  final _venueTypeController = TextEditingController();
  final _minAgeController = TextEditingController(text: '19');
  final _dressCodeController = TextEditingController();
  final _vipBoothsController = TextEditingController();
  final _sideTablesController = TextEditingController();

  // Music genres (checkboxes)
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

  // Amenities (checkboxes)
  final Map<String, bool> _amenities = {
    'VIP Booth Reservations': false,
    'Reserved Table Service': false,
    'Bottle Service': false,
    'Birthday Celebrations': false,
    'Private Events': false,
    'Professional DJ Entertainment': false,
    'Group Reservations': false,
    'Guest List Access': false,
  };

  // Step 3: Gallery Photos
  String? _bannerPhoto;
  final List<String> _menuPhotos = [];
  final List<String> _interiorPhotos = [];

  @override
  void dispose() {
    _pageController.dispose();
    _venueNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    _venueTypeController.dispose();
    _minAgeController.dispose();
    _dressCodeController.dispose();
    _vipBoothsController.dispose();
    _sideTablesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_canProceed()) {
        setState(() {
          _skippedSteps.remove(_currentStep);
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _skipStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _skippedSteps.add(_currentStep);
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canSkip => _currentStep == 1 || _currentStep == 2;

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Venue Basic Info
        return _venueNameController.text.isNotEmpty &&
            _streetController.text.isNotEmpty &&
            _cityController.text.isNotEmpty &&
            _stateController.text.isNotEmpty &&
            _capacityController.text.isNotEmpty;
      case 1: // Venue Details - all optional
        return true;
      case 2: // Photos - banner required unless skipping
        return _bannerPhoto != null;
      case 3: // Review
        return true;
      default:
        return false;
    }
  }

  Future<void> _pickPhoto(String category) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      // For now, use placeholder URL - in production you'd upload to Supabase Storage
      setState(() {
        switch (category) {
          case 'banner':
            _bannerPhoto = 'https://placehold.co/1200x400/png?text=Venue+Banner';
            break;
          case 'menu':
            _menuPhotos.add('https://placehold.co/600x800/png?text=Menu+${_menuPhotos.length + 1}');
            break;
          case 'interior':
            _interiorPhotos.add('https://placehold.co/800x600/png?text=Interior+${_interiorPhotos.length + 1}');
            break;
        }
      });
    }
  }

  List<String> _getSelectedGenres() {
    return _musicGenres.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  List<String> _getSelectedAmenities() {
    return _amenities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  Future<void> _completeOnboarding() async {
    // Prevent double submission
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(currentVendorUserProvider);
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final supabase = SupabaseConfig.client;

      // Build address JSON object matching Venue model
      final address = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip': _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        'country': _countryController.text.trim(),
      };

      // Combine all photos in gallery
      final allPhotos = <String>[];
      if (_bannerPhoto != null) allPhotos.add(_bannerPhoto!);
      allPhotos.addAll(_menuPhotos);
      allPhotos.addAll(_interiorPhotos);

      // Build social links with music and amenities
      final socialLinks = <String, dynamic>{};

      final selectedGenres = _getSelectedGenres();
      if (selectedGenres.isNotEmpty) {
        socialLinks['music_genres'] = selectedGenres;
      }

      final selectedAmenities = _getSelectedAmenities();
      if (selectedAmenities.isNotEmpty) {
        socialLinks['amenities'] = selectedAmenities;
      }

      if (_venueTypeController.text.isNotEmpty) {
        socialLinks['venue_type'] = _venueTypeController.text.trim();
      }

      if (_minAgeController.text.isNotEmpty) {
        socialLinks['min_age'] = int.tryParse(_minAgeController.text.trim());
      }

      if (_dressCodeController.text.isNotEmpty) {
        socialLinks['dress_code'] = _dressCodeController.text.trim();
      }

      if (_vipBoothsController.text.isNotEmpty) {
        socialLinks['vip_booths'] = int.tryParse(_vipBoothsController.text.trim());
      }

      if (_sideTablesController.text.isNotEmpty) {
        socialLinks['side_tables'] = int.tryParse(_sideTablesController.text.trim());
      }

      // Save to clubs table (the main venues table)
      final clubData = {
        'owner_id': currentUser.id,
        'name': _venueNameController.text.trim(),
        'address': address,
        'gallery': allPhotos,
        'license_documents': [], // Empty for now - can add documents later
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
        'status': 'pending', // Pending approval
        'social_links': socialLinks.isEmpty ? null : socialLinks,
        'floorplan_data': _descriptionController.text.isEmpty
            ? null
            : {'description': _descriptionController.text.trim()},
      };

      await supabase.from('clubs').insert(clubData);

      // Update vendor onboarding_completed flag
      final updatedUser = currentUser.copyWith(onboardingCompleted: true);
      await ref.read(supabaseAuthProvider.notifier).updateVendorUser(updatedUser);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue created successfully! Pending approval.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create venue: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
      ),
      body: Column(
        children: [
          // Progress Indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: theme.dividerColor,
          ),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(theme),
                _buildDetailsStep(theme),
                _buildPhotosStep(theme),
                _buildReviewStep(theme),
              ],
            ),
          ),

          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_canProceed() && !_isSubmitting)
                            ? (_currentStep == _totalSteps - 1
                                ? _completeOnboarding
                                : _nextStep)
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _currentStep == _totalSteps - 1 ? 'Complete' : 'Next',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                if (_canSkip) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _skipStep,
                      child: Text(
                        'Skip for now — complete later',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Basic details about your venue',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Venue Name
          TextFormField(
            controller: _venueNameController,
            decoration: InputDecoration(
              labelText: 'Venue Name *',
              hintText: 'e.g., XnO Lounge',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Street Address
          TextFormField(
            controller: _streetController,
            decoration: InputDecoration(
              labelText: 'Street Address *',
              hintText: 'e.g., 1800 Davenport Road',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // City and State
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City *',
                    hintText: 'e.g., Toronto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: 'State/Province *',
                    hintText: 'e.g., Ontario',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ZIP and Country
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: InputDecoration(
                    labelText: 'Postal Code',
                    hintText: 'Optional',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: 'Country *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Capacity
          TextFormField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: 'Maximum Capacity *',
              hintText: 'e.g., 250',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.people),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'About the Venue (Optional)',
              hintText: 'Describe your venue, atmosphere, and what makes it unique',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue Details',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Additional information (all optional)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Venue Type
          TextFormField(
            controller: _venueTypeController,
            decoration: InputDecoration(
              labelText: 'Venue Type',
              hintText: 'e.g., Lounge & Nightclub',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),

          const SizedBox(height: 16),

          // Min Age and VIP Booths
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minAgeController,
                  decoration: InputDecoration(
                    labelText: 'Minimum Age',
                    hintText: '19',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    suffixText: '+',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _vipBoothsController,
                  decoration: InputDecoration(
                    labelText: 'VIP Booths',
                    hintText: 'e.g., 11',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Side Tables
          TextFormField(
            controller: _sideTablesController,
            decoration: InputDecoration(
              labelText: 'Reserved Side Tables',
              hintText: 'e.g., 7',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),

          // Dress Code
          TextFormField(
            controller: _dressCodeController,
            decoration: InputDecoration(
              labelText: 'Dress Code',
              hintText: 'e.g., Fashionable nightlife attire',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 24),

          // Music Genres
          Text(
            'Music Genres',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _musicGenres.keys.map((genre) {
              return FilterChip(
                label: Text(genre),
                selected: _musicGenres[genre]!,
                onSelected: (selected) {
                  setState(() {
                    _musicGenres[genre] = selected;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Amenities
          Text(
            'Amenities & Services',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenities.keys.map((amenity) {
              return FilterChip(
                label: Text(amenity),
                selected: _amenities[amenity]!,
                onSelected: (selected) {
                  setState(() {
                    _amenities[amenity] = selected;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue Photos',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload banner, menus, and interior photos',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Banner Photo (Required)
          Text(
            'Club Banner *',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickPhoto('banner'),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bannerPhoto != null ? Colors.green : theme.dividerColor,
                  width: 2,
                ),
                image: _bannerPhoto != null
                    ? DecorationImage(
                        image: NetworkImage(_bannerPhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _bannerPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Banner Photo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // Menu Photos (Optional)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Photos',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickPhoto('menu'),
                icon: const Icon(Icons.add),
                label: const Text('Add Menu'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_menuPhotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Center(
                child: Text(
                  'No menu photos added (optional)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _menuPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(_menuPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _menuPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 24),

          // Interior Photos (Optional)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Club Interior',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickPhoto('interior'),
                icon: const Icon(Icons.add),
                label: const Text('Add Photo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_interiorPhotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Center(
                child: Text(
                  'No interior photos added (optional)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.33,
              ),
              itemCount: _interiorPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(_interiorPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _interiorPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    final selectedGenres = _getSelectedGenres();
    final selectedAmenities = _getSelectedAmenities();
    final totalPhotos = (_bannerPhoto != null ? 1 : 0) + _menuPhotos.length + _interiorPhotos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Submit',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your venue information',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Venue Info Summary
          _buildSummaryCard(
            theme,
            'Venue Information',
            [
              'Name: ${_venueNameController.text}',
              'Address: ${_streetController.text}, ${_cityController.text}, ${_stateController.text}',
              'Country: ${_countryController.text}',
              'Capacity: ${_capacityController.text} guests',
              if (_venueTypeController.text.isNotEmpty) 'Type: ${_venueTypeController.text}',
              if (_minAgeController.text.isNotEmpty) 'Age: ${_minAgeController.text}+',
            ],
          ),

          const SizedBox(height: 16),

          // Details Summary
          if (_vipBoothsController.text.isNotEmpty ||
              _sideTablesController.text.isNotEmpty ||
              selectedGenres.isNotEmpty ||
              selectedAmenities.isNotEmpty) ...[
            _buildSummaryCard(
              theme,
              'Details',
              [
                if (_vipBoothsController.text.isNotEmpty) 'VIP Booths: ${_vipBoothsController.text}',
                if (_sideTablesController.text.isNotEmpty) 'Side Tables: ${_sideTablesController.text}',
                if (selectedGenres.isNotEmpty) 'Music: ${selectedGenres.join(", ")}',
                if (selectedAmenities.isNotEmpty) 'Amenities: ${selectedAmenities.length} selected',
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Photos Summary
          _buildSummaryCard(
            theme,
            'Photos',
            [
              '$totalPhotos photo(s) uploaded',
              if (_bannerPhoto != null) '✓ Banner photo',
              if (_menuPhotos.isNotEmpty) '✓ ${_menuPhotos.length} menu photo(s)',
              if (_interiorPhotos.isNotEmpty) '✓ ${_interiorPhotos.length} interior photo(s)',
            ],
          ),

          const SizedBox(height: 24),

          // Pending items banner (shown when steps were skipped)
          if (_skippedSteps.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending info to complete',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_skippedSteps.contains(1))
                          Text('• Venue details (type, age limit, music, amenities)',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade700)),
                        if (_skippedSteps.contains(2))
                          Text('• Photos (banner, menu, interior)',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade700)),
                        const SizedBox(height: 4),
                        Text(
                          'You can complete these from your venue profile after submission.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Completion Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to submit!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your venue will be pending approval',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: theme.textTheme.bodyMedium,
                ),
              )),
        ],
      ),
    );
  }
}
