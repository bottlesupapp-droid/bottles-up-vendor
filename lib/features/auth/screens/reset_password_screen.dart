import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/password_recovery_logic.dart';
import '../providers/password_recovery_provider.dart';
import '../services/password_recovery_service.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// Where "forgot password" ends: choose a new password. The person arrives with a reset session already open (from the code screen), or with a
/// one-time [tokenHash] from the link in the email, which is spent here before the form is shown.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.tokenHash, this.expired = false});

  final String? tokenHash;

  /// The link that led here was already refused (used, or too old).
  final bool expired;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _Phase { checking, form, dead }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final PasswordRecoveryService _service = ref.read(passwordRecoveryServiceProvider);
  late _Phase _phase;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _deadReason;

  @override
  void initState() {
    super.initState();
    if (widget.expired) {
      _phase = _Phase.dead;
    } else if (widget.tokenHash != null) {
      _phase = _Phase.checking;
      WidgetsBinding.instance.addPostFrameCallback((_) => _spendLink(widget.tokenHash!));
    } else {
      // Came from the code screen: the session is open already. Without one there is nothing to change.
      _phase = _service.hasRecoverySession ? _Phase.form : _Phase.dead;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _spendLink(String tokenHash) async {
    try {
      await _service.verifyLink(tokenHash);
      if (mounted) setState(() => _phase = _Phase.form);
    } on PasswordRecoveryException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.dead;
          _deadReason = e.problem == RecoveryProblem.network ? e.message : null;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _service.updatePassword(_passwordController.text);
      // The reset session was only for this: the person signs in with the new password.
      await _service.finish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Sign in with your new password.')));
        context.go('/login');
      }
    } on PasswordRecoveryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _backToLogin() async {
    // Leaving without a new password: end the reset session so the app is back to normal.
    await _service.abandon();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_phase == _Phase.checking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password'), backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(key: Key('reset-checking')),
              const SizedBox(height: 16),
              Text('Checking your link...', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_phase == _Phase.dead) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password'), backgroundColor: Colors.transparent, elevation: 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.timer_off_outlined, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('This reset has expired', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  _deadReason ?? 'Reset links and codes work once and only for a short time. Ask for a new one.',
                  key: const Key('reset-dead-reason'),
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AuthButton(key: const Key('reset-expired-new'), text: 'Ask for a new email', onPressed: () => context.go('/forgot-password')),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Back to Login')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text('Choose a new password', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('At least 8 characters.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      key: const Key('reset-new-password'),
                      controller: _passwordController,
                      label: 'New password',
                      obscureText: _obscurePassword,
                      enabled: !_saving,
                      validator: validateNewPassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      key: const Key('reset-confirm-password'),
                      controller: _confirmController,
                      label: 'Confirm new password',
                      obscureText: _obscureConfirm,
                      enabled: !_saving,
                      validator: (value) => validateConfirmPassword(value, _passwordController.text),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AuthButton(key: const Key('reset-submit'), text: 'Update password', onPressed: _saving ? null : _save, isLoading: _saving),
              const SizedBox(height: 12),
              TextButton(key: const Key('reset-back'), onPressed: _saving ? null : _backToLogin, child: const Text('Back to Login')),
            ],
          ),
        ),
      ),
    );
  }
}
