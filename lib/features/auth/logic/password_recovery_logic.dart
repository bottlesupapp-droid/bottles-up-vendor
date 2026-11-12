import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException;

import '../../../core/config/password_reset_config.dart';

/// The rules of "forgot password", kept free of Supabase and of widgets so each one can be tested on its own.
///
/// The reset email has a button and a 6-digit code. The button goes to the website's /reset-password page, which can hand the person back to this
/// app on `bottlesupbusiness://app/reset-password?token_hash=...&type=recovery`; the code is typed on the "enter the code" screen.

/// How many digits the emailed code has (Supabase's default).
const int recoveryCodeLength = 6;

/// A new email can be asked for once a minute: Supabase refuses a second reset email for the same person sooner than that.
const Duration recoveryResendCooldown = Duration(seconds: 60);

const int minPasswordLength = 8;

/// bcrypt, which Supabase hashes passwords with, reads only the first 72 bytes and refuses more.
const int maxPasswordBytes = 72;

/// Keeps only the digits: people paste "483 920" or "483-920".
String normaliseRecoveryCode(String raw) => raw.replaceAll(RegExp(r'\D'), '');

String? validateRecoveryCode(String? raw) {
  final code = normaliseRecoveryCode(raw ?? '');
  if (code.isEmpty) return 'Enter the 6-digit code from your email';
  if (code.length != recoveryCodeLength) return 'The code has $recoveryCodeLength digits';
  return null;
}

String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < minPasswordLength) return 'Use at least $minPasswordLength characters';
  if (utf8.encode(value).length > maxPasswordBytes) return 'That password is too long. Use 72 characters or fewer';
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'Please confirm your password';
  if (value != password) return 'Passwords do not match';
  return null;
}

// Supabase token hashes are hexadecimal; anything outside this shape is not one of ours and is never sent to the server.
final RegExp _tokenHash = RegExp(r'^[A-Za-z0-9_-]{8,256}$');

bool isValidTokenHash(String? value) => value != null && _tokenHash.hasMatch(value);

/// The in-app address of the new-password screen for a link that carries a token. The router reads the token back out of it with
/// [recoveryTokenFrom].
String recoveryLocationForToken(String tokenHash) => '/reset-password?token_hash=${Uri.encodeQueryComponent(tokenHash)}&type=recovery';

/// Where the router should send a link that reached the app, or null when the link is not about resetting a password.
///
/// A link the website's page hands over is `bottlesupbusiness://app/reset-password?token_hash=...&type=recovery`. One that is dead (Supabase refused it,
/// or it holds nothing usable) still gets an answer, the "expired" page, because the person is waiting for something to happen.
String? recoveryLocationFor(Uri uri) {
  if (uri.scheme != businessAppScheme || uri.host != 'app' || uri.path != '/reset-password') return null;
  final params = uri.queryParameters;
  if (params.containsKey('error') || params.containsKey('error_code')) return '/reset-password?expired=1';
  final token = recoveryTokenFrom(params);
  return token == null ? '/reset-password?expired=1' : recoveryLocationForToken(token);
}

/// The one-time token in [params], when it is a recovery token of the shape ours are; otherwise null.
String? recoveryTokenFrom(Map<String, String> params) {
  final token = params['token_hash'];
  return params['type'] == 'recovery' && isValidTokenHash(token) ? token : null;
}

// The parts of an incoming link that act like a password for a few minutes. They are shown as "..." wherever a link is logged.
const _secretParams = {'token_hash', 'access_token', 'refresh_token', 'code', 'token'};

/// [link] with every secret value replaced, safe to print.
String redactLink(String link) => link.replaceAllMapped(
      RegExp('([?&#]|^)(${_secretParams.join('|')})=([^&#]*)'),
      (m) => '${m[1]}${m[2]}=...',
    );

/// What can go wrong between asking for a reset and having a new password, as far as the screens care.
enum RecoveryProblem { codeWrong, linkExpired, sameAsOld, tooWeak, tooManyRequests, network, other }

class PasswordRecoveryException implements Exception {
  const PasswordRecoveryException(this.problem, this.message);
  final RecoveryProblem problem;

  /// A sentence for the person.
  final String message;

  @override
  String toString() => message;
}

const Map<RecoveryProblem, String> _messages = {
  RecoveryProblem.codeWrong: 'That code is not right, or it has expired. Check it, or ask for a new one.',
  RecoveryProblem.linkExpired: 'This reset link has expired or was already used. Ask for a new one.',
  RecoveryProblem.sameAsOld: 'Your new password must be different from your old one.',
  RecoveryProblem.tooWeak: 'That password is too easy to guess. Try a longer one, with letters and numbers.',
  RecoveryProblem.tooManyRequests: 'Please wait a minute before asking for another email.',
  RecoveryProblem.network: 'We could not reach BottlesUp. Check your connection and try again.',
  RecoveryProblem.other: 'Something went wrong. Please try again.',
};

/// The sentence for [problem].
String recoveryProblemMessage(RecoveryProblem problem) => _messages[problem]!;

/// Turns what Supabase said into a [PasswordRecoveryException]. [duringCode] says the person was checking a code or a link, where a refusal means
/// "wrong or expired" and not "something broke".
PasswordRecoveryException recoveryExceptionFor(Object error, {bool duringCode = false}) {
  if (error is PasswordRecoveryException) return error;
  RecoveryProblem problem = RecoveryProblem.other;
  if (error is AuthRetryableFetchException) {
    problem = RecoveryProblem.network;
  } else if (error is AuthException) {
    final code = error.code;
    final status = error.statusCode;
    if (code == 'same_password') {
      problem = RecoveryProblem.sameAsOld;
    } else if (code == 'weak_password') {
      problem = RecoveryProblem.tooWeak;
    } else if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit' || status == '429') {
      problem = RecoveryProblem.tooManyRequests;
    } else if (code == 'otp_expired' || code == 'otp_disabled' || code == 'session_not_found' || code == 'session_expired' || status == '401' || status == '403') {
      problem = duringCode ? RecoveryProblem.codeWrong : RecoveryProblem.linkExpired;
    } else if (duringCode && (status == '400' || status == '422')) {
      problem = RecoveryProblem.codeWrong;
    }
  } else if (error.toString().contains('SocketException') || error.toString().contains('ClientException')) {
    problem = RecoveryProblem.network;
  }
  return PasswordRecoveryException(problem, recoveryProblemMessage(problem));
}
