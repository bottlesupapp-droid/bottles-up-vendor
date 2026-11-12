import 'dart:async';

import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/services/supabase_auth_service.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user() => User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-09-01T09:00:00Z');

AuthState _event(AuthChangeEvent event, User? user) =>
    AuthState(event, user == null ? null : Session(accessToken: 'a', tokenType: 'bearer', user: user));

/// The part of the auth service the notifier uses, without a Supabase client.
class _FakeAuthService implements SupabaseAuthService {
  final controller = StreamController<AuthState>.broadcast();
  User? current;
  int vendorLookups = 0;
  Object? resetError;
  final List<String> resetRequests = [];

  @override
  Stream<AuthState> get authStateChanges => controller.stream;

  @override
  User? get currentUser => current;

  @override
  Future<VendorUser?> findVendorUser(String uid) async {
    vendorLookups++;
    return null;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetRequests.add(email);
    if (resetError != null) throw resetError!;
  }

  @override
  Future<AuthResponse> signInWithEmailAndPassword({required String email, required String password}) async => AuthResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthService auth;
  late SupabaseAuthNotifier notifier;

  setUp(() {
    auth = _FakeAuthService();
    notifier = SupabaseAuthNotifier(auth);
  });

  Future<void> signedInEvent() async {
    auth.current = _user();
    auth.controller.add(_event(AuthChangeEvent.signedIn, _user()));
    await Future<void>.delayed(Duration.zero);
  }

  test('without a reset, a session that opens signs the person in to the app', () async {
    await signedInEvent();
    expect(notifier.state.supabaseUser, isNotNull);
    expect(auth.vendorLookups, 1);
  });

  test('while a reset is open, the session it opens does not sign the person in, and no vendor lookup is made', () async {
    notifier.beginPasswordRecovery();
    await signedInEvent();
    expect(notifier.state.supabaseUser, isNull);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(auth.vendorLookups, 0);
  });

  test('a sign-out during the reset is ignored too, so the app does not flicker', () async {
    await signedInEvent();
    notifier.beginPasswordRecovery();
    auth.current = null;
    auth.controller.add(_event(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.supabaseUser, isNotNull, reason: 'the held state is only brought up to date when the reset ends');
  });

  test('ending the reset with nobody signed in leaves the app signed out', () async {
    notifier.beginPasswordRecovery();
    await signedInEvent();
    auth.current = null;
    await notifier.endPasswordRecovery();
    expect(notifier.state.supabaseUser, isNull);
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test('ending a reset that failed puts back the person who was already signed in', () async {
    await signedInEvent();
    notifier.beginPasswordRecovery();
    // The link was bad, so nothing changed: the earlier session is still the current one.
    await notifier.endPasswordRecovery();
    expect(notifier.state.supabaseUser?.id, 'u1');
    expect(auth.vendorLookups, 2);
  });

  test('after the reset ends, sessions are followed again', () async {
    notifier.beginPasswordRecovery();
    await notifier.endPasswordRecovery();
    await signedInEvent();
    expect(notifier.state.supabaseUser, isNotNull);
  });

  test('signing in for real replaces a reset that was left open, so the login is not swallowed', () async {
    notifier.beginPasswordRecovery();
    await notifier.signIn(email: 'a@b.co', password: 'secret-pass');
    await signedInEvent();
    expect(notifier.state.supabaseUser, isNotNull);
  });

  test('asking for the reset email says whether it went out', () async {
    expect(await notifier.resetPassword('a@b.co'), isTrue);
    expect(auth.resetRequests, ['a@b.co']);
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
  });

  test('a refused request says false, and the reason is in the state', () async {
    auth.resetError = Exception('Email rate limit exceeded');
    expect(await notifier.resetPassword('a@b.co'), isFalse);
    expect(notifier.state.error, contains('Email rate limit exceeded'));
    expect(notifier.state.isLoading, isFalse);
  });
}
