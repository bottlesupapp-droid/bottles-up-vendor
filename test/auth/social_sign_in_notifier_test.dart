import 'dart:async';

import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/services/social_sign_in_service.dart';
import 'package:bottles_up_vendor/features/auth/services/supabase_auth_service.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({bool brandNew = false}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: brandNew ? '2026-10-28T10:00:00Z' : '2026-09-01T09:00:00Z',
      lastSignInAt: '2026-10-28T10:00:00Z',
    );

AuthState _event(AuthChangeEvent event, User? user) => AuthState(event, user == null ? null : Session(accessToken: 'a', tokenType: 'bearer', user: user));

/// The part of the auth service the notifier uses, without a Supabase client.
class _FakeAuthService implements SupabaseAuthService {
  final controller = StreamController<AuthState>.broadcast();
  User? current;
  int vendorLookups = 0;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthService auth;
  late List<SupabaseAuthState> states;
  late SupabaseAuthNotifier notifier;
  late bool sessionSeenDuringSignIn;

  /// A Google/Apple sign-in whose Supabase step opens a session the way the real client does (sets the user and announces it) before the service looks at the account.
  SupabaseAuthNotifier build({required User user, Future<SocialCredential> Function(SocialProvider)? credentials}) {
    final social = SocialSignInService(
      credentials: credentials ?? (p) async => const SocialCredential(idToken: 't'),
      signInWithToken: (p, c) async {
        auth.current = user;
        auth.controller.add(_event(AuthChangeEvent.signedIn, user));
        await Future<void>.delayed(Duration.zero);
        sessionSeenDuringSignIn = notifier.state.supabaseUser != null;
        return AuthResponse(user: user);
      },
      signOutLocally: () async {
        auth.current = null;
        auth.controller.add(_event(AuthChangeEvent.signedOut, null));
      },
    );
    notifier = SupabaseAuthNotifier(auth, social: social);
    notifier.addListener(states.add, fireImmediately: false);
    return notifier;
  }

  setUp(() {
    auth = _FakeAuthService();
    states = [];
    sessionSeenDuringSignIn = false;
  });

  tearDown(() => auth.controller.close());

  test('an existing account: signed in, the vendor row looked up, no error', () async {
    build(user: _user());
    await notifier.signInWithSocial(SocialProvider.google);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.vendorChecked, isTrue);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNull);
    expect(auth.vendorLookups, 1, reason: 'looked up once, not once for the session event and once more afterwards');
    expect(sessionSeenDuringSignIn, isFalse, reason: 'the session event is held back until the check is done');
  });

  test('a sign-in that made a new account is undone: never authenticated at any moment, and the person is told', () async {
    build(user: _user(brandNew: true));
    await notifier.signInWithSocial(SocialProvider.apple);
    await Future<void>.delayed(Duration.zero);

    expect(states.where((s) => s.supabaseUser != null), isEmpty, reason: 'the app must never see this session (it would open the dashboard for a moment)');
    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, contains('No BottlesUp Business account'));
    expect(notifier.state.error, contains('Apple'));
    expect(auth.vendorLookups, 0);
  });

  test('a new account is kept for a person who came to accept an invitation', () async {
    build(user: _user(brandNew: true));
    await notifier.signInWithSocial(SocialProvider.google, allowNewAccount: true);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.error, isNull);
  });

  test('closing the Google or Apple sheet leaves a clean login page: no error, not loading', () async {
    build(user: _user(), credentials: (p) async => throw const SocialSignInException('cancelled', cancelled: true));
    await notifier.signInWithSocial(SocialProvider.google);

    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(states.first.isLoading, isTrue, reason: 'it showed that it was working');
  });

  test('a sheet error is shown as its sentence', () async {
    build(user: _user(), credentials: (p) async => throw const SocialSignInException('Network error. Please check your internet connection and try again.'));
    await notifier.signInWithSocial(SocialProvider.google);

    expect(notifier.state.error, 'Network error. Please check your internet connection and try again.');
    expect(notifier.state.isLoading, isFalse);
  });

  test('an unexpected error becomes a plain sentence, not the raw exception', () async {
    build(user: _user(), credentials: (p) async => throw StateError('boom'));
    await notifier.signInWithSocial(SocialProvider.apple);

    expect(notifier.state.error, 'We could not sign you in with Apple. Please try again.');
  });

  test('after a failed attempt a later sign-in is not held back', () async {
    build(user: _user(), credentials: (p) async => throw const SocialSignInException('Network error.'));
    await notifier.signInWithSocial(SocialProvider.google);
    expect(notifier.state.isAuthenticated, isFalse);

    auth.current = _user();
    auth.controller.add(_event(AuthChangeEvent.signedIn, _user()));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isAuthenticated, isTrue, reason: 'e-mail sign-in and a restored session must still be honoured');
  });
}
