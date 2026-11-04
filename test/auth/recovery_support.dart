import 'package:bottles_up_vendor/features/auth/services/password_recovery_service.dart';

/// A scripted stand-in for Supabase's side of "forgot password". It records what it was asked, in order, and fails when told to.
class FakeRecoveryAuth implements RecoveryAuth {
  FakeRecoveryAuth({this.session = false});

  final List<String> calls = [];

  /// Is there a reset session right now? Verifying a code or a token opens one; signing out closes it.
  bool session;
  Object? sendError;
  Object? codeError;
  Object? tokenError;
  Object? setPasswordError;
  Object? signOutError;

  @override
  Future<void> sendResetEmail(String email) async {
    calls.add('send:$email');
    if (sendError != null) throw sendError!;
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    calls.add('code:$email:$code');
    if (codeError != null) throw codeError!;
    session = true;
  }

  @override
  Future<void> verifyTokenHash(String tokenHash) async {
    calls.add('token:$tokenHash');
    // Let a second, simultaneous arrival of the same link overlap with this one.
    await Future<void>.delayed(Duration.zero);
    if (tokenError != null) throw tokenError!;
    session = true;
  }

  @override
  bool get hasSession => session;

  @override
  Future<void> setPassword(String password) async {
    calls.add('set:$password');
    if (setPasswordError != null) throw setPasswordError!;
  }

  @override
  Future<void> signOutHere() async {
    calls.add('signOut');
    if (signOutError != null) throw signOutError!;
    session = false;
  }
}

/// The reset service over a [FakeRecoveryAuth], with a record of when the app was told a reset began and ended.
class RecoveryHarness {
  RecoveryHarness({bool session = false}) : auth = FakeRecoveryAuth(session: session) {
    service = PasswordRecoveryService(
      auth: auth,
      begin: () => events.add('begin'),
      end: () async {
        events.add('end');
      },
    );
  }

  final FakeRecoveryAuth auth;
  late final PasswordRecoveryService service;
  final List<String> events = [];
}
