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

class PromoterOnboardingScreen extends ConsumerStatefulWidget {
  const PromoterOnboardingScreen({super.key});

  @override
  ConsumerState<PromoterOnboardingScreen> createState() => _PromoterOnboardingScreenState();
}

class _PromoterOnboardingScreenState extends ConsumerState<PromoterOnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;
  bool _isSubmitting = false;

  // Step 1: Basic Info
  final _phoneController = TextEditingController();
  String? _photoUrl;

  // Step 2: Promo Code Info
  String? _promoCode;

  // Step 3: Payout Setup (optional)
  bool _payoutConnected = false;
  bool _isConnectingStripe = false;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _photoUrl = 'https://placehold.co/400x400/png?text=Profile';
      });
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

      // Save promoter profile to promoter_profiles table
      await supabase.from('promoter_profiles').upsert({
        'vendor_id': currentUser.id,
        'phone_number': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'profile_photo_url': _photoUrl,
        // promo_code will be assigned by organizers later
        'promo_code': null,
        'total_sales': 0,
        'total_commission': 0,
      });

      // Update vendor onboarding_completed flag
      final updatedUser = currentUser.copyWith(onboardingCompleted: true);
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
                _buildBasicInfoStep(theme),
                _buildPromoCodeStep(theme),
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
                    onPressed: !_isSubmitting
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

  Widget _buildBasicInfoStep(ThemeData theme) {
    final currentUser = ref.watch(currentVendorUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your promoter profile',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Profile Photo
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.cardColor,
                  border: Border.all(
                    color: _photoUrl != null ? BuTokens.dark.amber : theme.dividerColor,
                    width: 2,
                  ),
                ),
                child: _photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _photoUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.camera_outline,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Email (from auth)
          TextFormField(
            initialValue: currentUser?.email ?? '',
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              enabled: false,
              prefixIcon: const Icon(Ionicons.mail_outline),
            ),
          ),

          const SizedBox(height: 16),

          // Phone Number
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: '+1 (555) 123-4567',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Ionicons.call_outline),
            ),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BuTokens.dark.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BuTokens.dark.amber),
            ),
            child: Row(
              children: [
                Icon(Ionicons.information_circle_outline, color: BuTokens.dark.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'As a promoter, you\'ll earn commissions by promoting events',
                    style: theme.textTheme.bodyMedium?.copyWith(
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

  Widget _buildPromoCodeStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promo Code Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your unique promo code details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Promo Code Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(
                  Ionicons.gift_outline,
                  size: 64,
                  color: BuTokens.dark.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  _promoCode ?? 'Waiting for Assignment',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _promoCode != null ? BuTokens.dark.amber : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _promoCode != null
                      ? 'This is your unique promo code'
                      : 'Your promo code will be assigned when an organizer invites you to an event',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // How it Works
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BuTokens.dark.orangeSoft.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Ionicons.bulb_outline, color: BuTokens.dark.orangeSoft),
                    const SizedBox(width: 12),
                    Text(
                      'How Promo Codes Work',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BuTokens.dark.orangeSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(theme, '1', 'Get invited to events by organizers'),
                const SizedBox(height: 12),
                _buildInfoRow(theme, '2', 'Share your promo code with your followers'),
                const SizedBox(height: 12),
                _buildInfoRow(theme, '3', 'Earn commission on every ticket sold'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: BuTokens.dark.orangeSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BuTokens.dark.orangeSoft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout Setup (Optional)',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up payments for commission earnings',
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
                  _payoutConnected ? 'Payout Connected' : 'Connect Bank Account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _payoutConnected
                      ? 'You\'re ready to receive commission payments'
                      : 'Connect your bank account to receive commission payments',
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
                        // TODO: Implement Stripe/Bank Connect
                        setState(() {
                          _payoutConnected = true;
                        });
                      },
                      icon: const Icon(Ionicons.link_outline),
                      label: const Text('Connect Account'),
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
                    'You can set this up later when you start earning',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
