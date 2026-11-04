import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/password_recovery_logic.dart';
import '../providers/password_recovery_provider.dart';
import '../services/password_recovery_service.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// Step two of "forgot password" for anyone whose email button did not open the app (or who read the email on another device): type the 6-digit code
/// from the email, and the next screen is the new password.
class ResetCodeScreen extends ConsumerStatefulWidget {
  const ResetCodeScreen({super.key, required this.email});

  /// The address the code was sent to, carried over from the "forgot password" screen.
  final String email;

  @override
  ConsumerState<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends ConsumerState<ResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  late final PasswordRecoveryService _service = ref.read(passwordRecoveryServiceProvider);
  Timer? _ticker;
  // The email went out a moment ago, so the next one has to wait the full minute.
  int _secondsLeft = recoveryResendCooldown.inSeconds;
  bool _checking = false;
  bool _resending = false;
  String? _problem;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // Counts the wait down once a second. Never calls setState itself, so initState can start it.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _checking = true;
      _problem = null;
      _notice = null;
    });
    try {
      await _service.verifyCode(email: widget.email, code: _codeController.text);
      if (mounted) context.go('/reset-password');
    } on PasswordRecoveryException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _problem = null;
      _notice = null;
    });
    try {
      await _service.sendEmail(widget.email);
      if (mounted) {
        _codeController.clear();
        setState(() {
          _notice = 'We sent a new email. Only the newest code works.';
          _secondsLeft = recoveryResendCooldown.inSeconds;
        });
        _startTicker();
      }
    } on PasswordRecoveryException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.email.trim().isEmpty) {
      // Reached without an address (a stale link): there is no email to check a code against.
      return Scaffold(
        appBar: AppBar(title: const Text('Enter the code'), backgroundColor: Colors.transparent, elevation: 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start from Forgot password', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('We need your email address to check the code.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                AuthButton(key: const Key('reset-code-start-over'), text: 'Forgot password', onPressed: () => context.go('/forgot-password')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enter the code'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Enter the 6-digit code', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('We emailed a code to', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(widget.email, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: AuthTextField(
                  key: const Key('reset-code-field'),
                  controller: _codeController,
                  label: '6-digit code',
                  hintText: '123456',
                  keyboardType: TextInputType.number,
                  enabled: !_checking,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]')), LengthLimitingTextInputFormatter(recoveryCodeLength + 2)],
                  validator: validateRecoveryCode,
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 12),
                Text(_problem!, key: const Key('reset-code-problem'), style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!, key: const Key('reset-code-notice'), style: TextStyle(color: Colors.green.shade300), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              AuthButton(key: const Key('reset-code-submit'), text: 'Continue', onPressed: _checking ? null : _verify, isLoading: _checking),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('reset-code-resend'),
                onPressed: (_secondsLeft > 0 || _resending || _checking) ? null : _resend,
                child: Text(_secondsLeft > 0 ? 'Send a new code in ${_secondsLeft}s' : (_resending ? 'Sending...' : 'Send a new code')),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
