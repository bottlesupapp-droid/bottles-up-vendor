import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/supabase_auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState?.validate() ?? false) {
      final phoneNumber = _phoneController.text.trim();

      // Format phone number with country code if not present
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+1$phoneNumber'; // Default to US
      }

      await ref
          .read(supabaseAuthProvider.notifier)
          .signInWithPhone(formattedPhone);

      // Check if OTP was sent successfully
      if (mounted && ref.read(authErrorProvider) == null) {
        // Navigate to OTP verification screen
        context.push('/verify-otp', extra: formattedPhone);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(supabaseAuthProvider);
    final theme = Theme.of(context);

    // Listen to auth state changes
    ref.listen<String?>(authErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(supabaseAuthProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          centerContent: true,
          maxWidth: 500,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              utils.ResponsiveUtils.getResponsivePadding(context),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context),
                  ),

                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context) *
                        1.5,
                  ),

                  // Title
                  ResponsiveText.headlineMedium(
                    'Phone Login',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context) *
                        0.5,
                  ),

                  // Subtitle
                  ResponsiveText.bodyLarge(
                    'We\'ll send you a verification code to your phone number',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context) *
                        2,
                  ),

                  // Phone Number Field
                  AuthTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context) *
                        0.75,
                  ),

                  // Info text
                  ResponsiveText.bodySmall(
                    'Format: 10 digits without country code',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context) *
                        2,
                  ),

                  // Send OTP Button
                  AuthButton(
                    text: 'Send OTP',
                    onPressed: _sendOTP,
                    isLoading: authState.isLoading,
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context),
                  ),

                  // Or divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ResponsiveText.bodySmall(
                          'OR',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(
                    height:
                        utils.ResponsiveUtils.getResponsiveSpacing(context),
                  ),

                  // Back to email login
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: ResponsiveText.bodyMedium(
                        'Login with Email',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
