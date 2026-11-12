import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/supabase_auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      final requested = await ref
          .read(supabaseAuthProvider.notifier)
          .resetPassword(_emailController.text.trim());

      // Only say "sent" when it was: a failure is already shown as a message, and a person told the email is on its way waits for one that never comes.
      if (mounted && requested) {
        setState(() {
          _emailSent = true;
        });
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
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              if (!_emailSent) ...[
                // Title and Description
                Text(
                  'Forgot Password?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email Field
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          // Deliberately loose: the server decides. The old pattern refused "sam+work@example.com" and any address ending in
                          // more than 4 letters (".london"), so those people could never reset their password.
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Reset Button
                      AuthButton(
                        text: 'Send Reset Link',
                        onPressed: _resetPassword,
                        isLoading: authState.isLoading,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Success Message
                Text(
                  'Email Sent!',
                  key: const Key('forgot-sent-title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ve sent a reset link and a 6-digit code to ${_emailController.text.trim()}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'Tap the button in the email, or enter the 6-digit code here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // The email also carries a 6-digit code, for when its button does not open the app (or it was read on another device).
                AuthButton(
                  key: const Key('forgot-enter-code'),
                  text: 'Enter the 6-digit code',
                  onPressed: () => context.push('/reset-code?email=${Uri.encodeQueryComponent(_emailController.text.trim())}'),
                ),

                const SizedBox(height: 12),

                // Back to Login Button
                AuthButton(
                  text: 'Back to Login',
                  onPressed: () {
                    context.pop();
                  },
                  isSecondary: true,
                ),

                const SizedBox(height: 16),

                // Resend Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _emailSent = false;
                    });
                  },
                  child: Text(
                    'Didn\'t receive the email? Resend',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              if (!_emailSent)
                // Back to Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Remember your password? ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        context.pop();
                      },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
