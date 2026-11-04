import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/password_reset_config.dart';
import '../logic/password_recovery_logic.dart';

/// What the reset flow needs from Supabase, so the flow can be tested without a server.
abstract class RecoveryAuth {
  Future<void> sendResetEmail(String email);
  Future<void> verifyCode({required String email, required String code});
  Future<void> verifyTokenHash(String tokenHash);
  bool get hasSession;
  Future<void> setPassword(String password);

  /// Ends the session on this phone only; other devices stay signed in.
  Future<void> signOutHere();
}

class SupabaseRecoveryAuth implements RecoveryAuth {
  // Read on use, not on construction: nothing here may touch Supabase before the app has started it.
  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Future<void> sendResetEmail(String email) => _auth.resetPasswordForEmail(email, redirectTo: passwordResetRedirect);

  @override
  Future<void> verifyCode({required String email, required String code}) => _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);

  @override
  Future<void> verifyTokenHash(String tokenHash) => _auth.verifyOTP(tokenHash: tokenHash, type: OtpType.recovery);

  @override
  bool get hasSession => _auth.currentSession != null;

  @override
  Future<void> setPassword(String password) => _auth.updateUser(UserAttributes(password: password));

  @override
  Future<void> signOutHere() => _auth.signOut(scope: SignOutScope.local);
}

/// Forgot password, from the email to the new password. Every failure is a [PasswordRecoveryException] holding a sentence for the person.
///
/// Checking a code or a link opens a Supabase session. The person has not signed in, so [begin] tells the app to ignore that session (it must not carry
/// them to the dashboard before they have chosen a password) until [finish] or [abandon] calls [end].
class PasswordRecoveryService {
  PasswordRecoveryService({required RecoveryAuth auth, required void Function() begin, required Future<void> Function() end})
      : _auth = auth,
        _begin = begin,
        _end = end;

  final RecoveryAuth _auth;
  final void Function() _begin;
  final Future<void> Function() _end;

  // A link can reach the app twice (the system hands it to the router and to the link listener), and its token works once. These make the second
  // arrival a no-op instead of "expired".
  String? _spentToken;
  String? _checkingToken;
  Future<void>? _checking;

  Future<void> sendEmail(String email) async {
    try {
      await _auth.sendResetEmail(email.trim());
    } catch (e) {
      throw recoveryExceptionFor(e);
    }
  }

  /// Checks the 6-digit code from the email. On success there is a reset session, good only for [updatePassword].
  Future<void> verifyCode({required String email, required String code}) async {
    _begin();
    try {
      await _auth.verifyCode(email: email.trim(), code: normaliseRecoveryCode(code));
    } catch (e) {
      await _end();
      throw recoveryExceptionFor(e, duringCode: true);
    }
  }

  /// Spends the one-time token from a link that reached the app.
  Future<void> verifyLink(String tokenHash) {
    if (_spentToken == tokenHash && _auth.hasSession) return Future<void>.value();
    if (_checkingToken == tokenHash && _checking != null) return _checking!;
    _checkingToken = tokenHash;
    final run = _spend(tokenHash);
    _checking = run;
    return run.whenComplete(() {
      _checkingToken = null;
      _checking = null;
    });
  }

  Future<void> _spend(String tokenHash) async {
    _begin();
    try {
      await _auth.verifyTokenHash(tokenHash);
      _spentToken = tokenHash;
    } catch (e) {
      await _end();
      throw recoveryExceptionFor(e, duringCode: true);
    }
  }

  bool get hasRecoverySession => _auth.hasSession;

  Future<void> updatePassword(String newPassword) async {
    if (!_auth.hasSession) throw const PasswordRecoveryException(RecoveryProblem.linkExpired, 'This reset has expired. Ask for a new link or code.');
    try {
      await _auth.setPassword(newPassword);
    } catch (e) {
      throw recoveryExceptionFor(e);
    }
  }

  /// The password is set: the person signs in with it, so nobody stays signed in on this phone because of the reset. Never throws.
  Future<void> finish() => _close();

  /// The person left without choosing a password: end the reset session and let the app go back to normal. Never throws.
  Future<void> abandon() => _close();

  Future<void> _close() async {
    _spentToken = null;
    try {
      await _auth.signOutHere();
    } catch (_) {
      // Failing to clear the local session must not look like a failure of the reset.
    }
    try {
      await _end();
    } catch (_) {
      // Same: the app state is re-read on the next sign-in anyway.
    }
  }
}
