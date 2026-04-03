import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/supabase_auth_provider.dart';

class VenueOnboardingScreen extends ConsumerStatefulWidget {
  const VenueOnboardingScreen({super.key});

  @override
  ConsumerState<VenueOnboardingScreen> createState() => _VenueOnboardingScreenState();
}

class _VenueOnboardingScreenState extends ConsumerState<VenueOnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;

  // Step 1: Venue Basic Info
  final _venueNameController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 2: Gallery Photos
  final List<String> _galleryPhotos = [];

  // Step 3: Legal Documents
  final Map<String, String?> _legalDocuments = {
    'barLicense': null,
    'fssai': null,
    'gst': null,
    'fireNoc': null,
    'shopAct': null,
  };

  // Step 4: Floorplan (simplified - just zones/areas)
  final List<Map<String, dynamic>> _zones = [];
  final _zoneNameController = TextEditingController();

  // Step 5: Bottle Menu (optional)
  final List<Map<String, dynamic>> _bottles = [];

  // Step 6: Payout Setup
  bool _payoutConnected = false;

  @override
  void dispose() {
    _pageController.dispose();
    _venueNameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    _zoneNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_canProceed()) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

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
            _addressLine1Controller.text.isNotEmpty &&
            _cityController.text.isNotEmpty &&
            _stateController.text.isNotEmpty &&
            _zipController.text.isNotEmpty &&
            _capacityController.text.isNotEmpty;
      case 1: // Gallery - minimum 5 photos
        return _galleryPhotos.length >= 5;
      case 2: // Legal Documents - at least bar license
        return _legalDocuments['barLicense'] != null;
      case 3: // Floorplan - optional
      case 4: // Bottle Menu - optional
      case 5: // Payout - optional for now
        return true;
      case 6: // Review
        return true;
      default:
        return false;
    }
  }

  Future<void> _pickGalleryPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _galleryPhotos.add('https://placehold.co/600x400/png?text=Photo+${_galleryPhotos.length + 1}');
      });
    }
  }

  Future<void> _pickDocument(String documentType) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _legalDocuments[documentType] = 'document_${documentType}_uploaded.pdf';
      });
    }
  }

  void _addZone() {
    if (_zoneNameController.text.isNotEmpty) {
      setState(() {
        _zones.add({
          'name': _zoneNameController.text,
          'tables': 0,
        });
        _zoneNameController.clear();
      });
    }
  }

  Future<void> _completeOnboarding() async {
    // TODO: Save all venue data to Supabase

    final currentUser = ref.read(currentVendorUserProvider);
    if (currentUser != null) {
      final updatedUser = currentUser.copyWith(onboardingCompleted: true);
      await ref.read(supabaseAuthProvider.notifier).updateVendorUser(updatedUser);
    }

    if (mounted) {
      context.go('/dashboard');
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
                _buildGalleryStep(theme),
                _buildLegalDocumentsStep(theme),
                _buildFloorplanStep(theme),
                _buildBottleMenuStep(theme),
                _buildPayoutStep(theme),
                _buildReviewStep(theme),
              ],
            ),
          ),

          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
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
                  flex: _currentStep == 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _canProceed()
                        ? (_currentStep == _totalSteps - 1
                            ? _completeOnboarding
                            : _nextStep)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
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
            'Venue Basic Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your venue',
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
              hintText: 'e.g., The Grand Club',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Address Line 1
          TextFormField(
            controller: _addressLine1Controller,
            decoration: InputDecoration(
              labelText: 'Address Line 1 *',
              hintText: 'Street address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Address Line 2
          TextFormField(
            controller: _addressLine2Controller,
            decoration: InputDecoration(
              labelText: 'Address Line 2 (Optional)',
              hintText: 'Apartment, suite, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),

          const SizedBox(height: 16),

          // City, State, ZIP in Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City *',
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
                    labelText: 'State *',
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
                  controller: _zipController,
                  decoration: InputDecoration(
                    labelText: 'ZIP *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Capacity
          TextFormField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: 'Capacity *',
              hintText: 'Maximum number of guests',
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
              labelText: 'Description (Optional)',
              hintText: 'Brief description of your venue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Venue Gallery',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least 5-6 photos (interior, exterior, bar, dance floor)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Photos Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _galleryPhotos.length + 1,
            itemBuilder: (context, index) {
              if (index == _galleryPhotos.length) {
                // Add Photo Button
                return GestureDetector(
                  onTap: _pickGalleryPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Photo Card
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(_galleryPhotos[index]),
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
                          _galleryPhotos.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
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

          const SizedBox(height: 16),

          // Photo Count
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _galleryPhotos.length >= 5
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _galleryPhotos.length >= 5
                      ? Icons.check_circle
                      : Icons.info,
                  color: _galleryPhotos.length >= 5
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _galleryPhotos.length >= 5
                        ? '${_galleryPhotos.length} photos uploaded ✓'
                        : 'Upload at least ${5 - _galleryPhotos.length} more photos',
                    style: TextStyle(
                      color: _galleryPhotos.length >= 5
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalDocumentsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Legal Documents',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload business and compliance documents',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Document Upload Cards
          _buildDocumentCard(theme, 'Bar License', 'barLicense', required: true),
          const SizedBox(height: 12),
          _buildDocumentCard(theme, 'FSSAI Certificate', 'fssai'),
          const SizedBox(height: 12),
          _buildDocumentCard(theme, 'GST Registration', 'gst'),
          const SizedBox(height: 12),
          _buildDocumentCard(theme, 'Fire NOC', 'fireNoc'),
          const SizedBox(height: 12),
          _buildDocumentCard(theme, 'Shop Act License', 'shopAct'),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ThemeData theme, String title, String key, {bool required = false}) {
    final isUploaded = _legalDocuments[key] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? Colors.green : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUploaded ? Icons.check_circle : Icons.upload_file,
            color: isUploaded ? Colors.green : theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title + (required ? ' *' : ''),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isUploaded)
                  Text(
                    'Uploaded ✓',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _pickDocument(key),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded ? Colors.green : null,
            ),
            child: Text(isUploaded ? 'Replace' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorplanStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Floorplan Setup (Optional)',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add zones/areas like VIP, General, Dance Floor',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Add Zone Input
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _zoneNameController,
                  decoration: InputDecoration(
                    labelText: 'Zone Name',
                    hintText: 'e.g., VIP Section',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addZone,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Zones List
          if (_zones.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No zones added yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can skip this step',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _zones.length,
              itemBuilder: (context, index) {
                final zone = _zones[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(zone['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _zones.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottleMenuStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bottle Menu (Optional)',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add bottles to your menu - you can do this later',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Skip Message
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.wine_bar,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can add bottles later',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Skip this step and add your bottle menu from the dashboard',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout Setup',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with Stripe for payments',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Stripe Connect Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _payoutConnected ? Colors.green : theme.dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _payoutConnected ? Icons.check_circle : Icons.account_balance,
                  size: 64,
                  color: _payoutConnected ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _payoutConnected ? 'Stripe Connected' : 'Connect with Stripe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _payoutConnected
                      ? 'Your account is ready to receive payments'
                      : 'Connect your bank account to receive payments',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_payoutConnected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement Stripe Connect
                        setState(() {
                          _payoutConnected = true;
                        });
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Connect Stripe'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Skip Option
          if (!_payoutConnected)
            Center(
              child: TextButton(
                onPressed: _nextStep,
                child: const Text('Skip for now'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Complete',
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
              'Address: ${_addressLine1Controller.text}, ${_cityController.text}',
              'Capacity: ${_capacityController.text}',
            ],
          ),

          const SizedBox(height: 16),

          // Gallery Summary
          _buildSummaryCard(
            theme,
            'Gallery',
            ['${_galleryPhotos.length} photos uploaded'],
          ),

          const SizedBox(height: 16),

          // Documents Summary
          _buildSummaryCard(
            theme,
            'Legal Documents',
            _legalDocuments.entries
                .where((e) => e.value != null)
                .map((e) => '✓ ${_getDocumentTitle(e.key)}')
                .toList(),
          ),

          const SizedBox(height: 16),

          // Optional Items
          if (_zones.isNotEmpty)
            _buildSummaryCard(
              theme,
              'Zones',
              _zones.map((z) => '• ${z['name']}').toList(),
            ),

          if (_payoutConnected) ...[
            const SizedBox(height: 16),
            _buildSummaryCard(
              theme,
              'Payout',
              ['✓ Stripe Connected'],
            ),
          ],

          const SizedBox(height: 24),

          // Completion Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your venue is ready to go live!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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

  String _getDocumentTitle(String key) {
    switch (key) {
      case 'barLicense':
        return 'Bar License';
      case 'fssai':
        return 'FSSAI Certificate';
      case 'gst':
        return 'GST Registration';
      case 'fireNoc':
        return 'Fire NOC';
      case 'shopAct':
        return 'Shop Act License';
      default:
        return key;
    }
  }
}
