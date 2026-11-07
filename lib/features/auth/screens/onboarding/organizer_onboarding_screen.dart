import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ionicons/ionicons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/services/stripe_service.dart';
import '../../providers/supabase_auth_provider.dart';

class OrganizerOnboardingScreen extends ConsumerStatefulWidget {
  const OrganizerOnboardingScreen({super.key});

  @override
  ConsumerState<OrganizerOnboardingScreen> createState() => _OrganizerOnboardingScreenState();
}

class _OrganizerOnboardingScreenState extends ConsumerState<OrganizerOnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isSubmitting = false;

  // Step 1: Organization Info
  final _organizationNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 2: Logo
  String? _logoUrl;

  // Step 3: Social Links
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();

  // Step 4: Payout Setup
  bool _payoutConnected = false;
  bool _isConnectingStripe = false;

  @override
  void dispose() {
    _pageController.dispose();
    _organizationNameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
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
      case 0: // Organization Info
        return _organizationNameController.text.isNotEmpty;
      case 1: // Logo
        return _logoUrl != null;
      case 2: // Social Links - at least Instagram
        return _instagramController.text.isNotEmpty;
      case 3: // Payout - optional
        return true;
      default:
        return false;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _logoUrl = 'https://placehold.co/400x400/png?text=Logo';
      });
    }
  }

  Future<void> _connectStripeAccount() async {
    setState(() => _isConnectingStripe = true);

    try {
      final currentUser = ref.read(currentVendorUserProvider);
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final stripeService = StripeService();

      // Call create-connect-account edge function
      final result = await stripeService.createConnectAccount(
        vendorId: currentUser.id,
        email: currentUser.email,
        businessName: _organizationNameController.text.trim(),
        returnUrl: 'https://app.bottlesup.com/onboarding-complete',
        refreshUrl: 'https://app.bottlesup.com/onboarding',
      );

      // Launch Stripe onboarding URL
      final url = Uri.parse(result['url'] as String);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        if (mounted) {
          setState(() => _payoutConnected = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Complete Stripe onboarding in your browser'),
              backgroundColor: BuTokens.dark.orangeSoft,
            ),
          );
        }
      } else {
        throw Exception('Could not launch Stripe onboarding');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('We could not connect Stripe. Try again.'),
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
        setState(() => _isConnectingStripe = false);
      }
    }
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

      // Save organizer profile to organizer_profiles table
      await supabase.from('organizer_profiles').upsert({
        'vendor_id': currentUser.id,
        'organization_name': _organizationNameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'instagram_handle': _instagramController.text.trim(),
        'facebook_page': _facebookController.text.trim().isEmpty ? null : _facebookController.text.trim(),
      });

      // Update vendor logo_url if logo was uploaded
      if (_logoUrl != null) {
        await supabase.from('vendors').update({
          'logo_url': _logoUrl,
        }).eq('id', currentUser.id);
      }

      // Update vendor onboarding_completed flag
      final updatedUser = currentUser.copyWith(
        onboardingCompleted: true,
        logoUrl: _logoUrl ?? currentUser.logoUrl,
      );
      await ref.read(supabaseAuthProvider.notifier).updateVendorUser(updatedUser);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: BuTokens.dark.green,
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
            content: Text('We could not save profile. Your entries are still here. Try again.'),
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
                icon: const Icon(Ionicons.arrow_back),
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
                _buildOrganizationInfoStep(theme),
                _buildLogoStep(theme),
                _buildSocialLinksStep(theme),
                _buildPayoutStep(theme),
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
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationInfoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your organization',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Organization Name
          TextFormField(
            controller: _organizationNameController,
            decoration: InputDecoration(
              labelText: 'Organization Name *',
              hintText: 'e.g., Epic Events Co.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Ionicons.business_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Brief description of what you do',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            maxLines: 4,
          ),

          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BuTokens.dark.orangeSoft.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BuTokens.dark.orangeSoft),
            ),
            child: Row(
              children: [
                Icon(Ionicons.information_circle_outline, color: BuTokens.dark.orangeSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'As an organizer, you can browse venues and send event proposals',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BuTokens.dark.orangeSoft,
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

  Widget _buildLogoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Logo',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your organization logo',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Logo Upload
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _logoUrl != null ? BuTokens.dark.green : theme.dividerColor,
                    width: 2,
                  ),
                ),
                child: _logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _logoUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.image_outline,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload Logo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          if (_logoUrl != null) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Ionicons.create_outline),
                label: const Text('Change Logo'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialLinksStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Social Media Links',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your social media handles for marketing',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Instagram
          TextFormField(
            controller: _instagramController,
            decoration: InputDecoration(
              labelText: 'Instagram Handle *',
              hintText: '@yourhandle',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Ionicons.camera_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Facebook
          TextFormField(
            controller: _facebookController,
            decoration: InputDecoration(
              labelText: 'Facebook Page (Optional)',
              hintText: 'facebook.com/yourpage',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Ionicons.logo_facebook),
            ),
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BuTokens.dark.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Ionicons.bulb_outline, color: BuTokens.dark.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These links will be visible to venue owners when you send proposals',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BuTokens.dark.amber,
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
                color: _payoutConnected ? BuTokens.dark.green : theme.dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _payoutConnected ? Ionicons.checkmark_circle : Ionicons.business_outline,
                  size: 64,
                  color: _payoutConnected ? BuTokens.dark.green : theme.colorScheme.primary,
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
                      onPressed: _isConnectingStripe ? null : _connectStripeAccount,
                      icon: _isConnectingStripe
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Ionicons.link_outline),
                      label: Text(_isConnectingStripe ? 'Connecting...' : 'Connect Stripe'),
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
              child: Column(
                children: [
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip for now'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can set this up later from settings',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
