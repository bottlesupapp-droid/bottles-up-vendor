import 'dart:async';

import 'package:bottles_up_vendor/features/auth/services/social_sign_in_service.dart';
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

void main() {
  late List<String> events;
  late SocialCredential? lastCredential;

  SocialSignInService service({
    Future<SocialCredential> Function(SocialProvider)? credentials,
    Future<AuthResponse> Function(SocialProvider, SocialCredential)? signIn,
    Future<void> Function()? signOut,
  }) =>
      SocialSignInService(
        credentials: credentials ??
            (p) async {
              events.add('credential ${p.name}');
              return const SocialCredential(idToken: 'token', accessToken: 'access', nonce: 'raw');
            },
        signInWithToken: signIn ??
            (p, c) async {
              events.add('supabase ${p.name}');
              lastCredential = c;
              return AuthResponse(user: _user());
            },
        signOutLocally: signOut ??
            () async {
              events.add('signed out');
            },
      );

  setUp(() {
    events = [];
    lastCredential = null;
  });

  group('an account that already existed', () {
    test('signs in with what the sheet handed back, for either provider, and is not signed out', () async {
      for (final provider in SocialProvider.values) {
        events.clear();
        await service().signIn(provider);
        expect(events, ['credential ${provider.name}', 'supabase ${provider.name}'], reason: provider.name);
      }
      expect(lastCredential?.idToken, 'token');
      expect(lastCredential?.accessToken, 'access');
      expect(lastCredential?.nonce, 'raw');
    });

    test('Google goes to Supabase as the google provider and Apple as the apple provider', () {
      expect(SocialProvider.google.oauth, OAuthProvider.google);
      expect(SocialProvider.apple.oauth, OAuthProvider.apple);
      expect(SocialProvider.google.label, 'Google');
      expect(SocialProvider.apple.label, 'Apple');
    });
  });

  group('a sign-in that just made a new account', () {
    Future<AuthResponse> newAccount(SocialProvider p, SocialCredential c) async {
      events.add('supabase ${p.name}');
      return AuthResponse(user: _user(brandNew: true));
    }

    test('is undone on this phone and the person is told, because this app never makes accounts', () async {
      await expectLater(
        service(signIn: newAccount).signIn(SocialProvider.google),
        throwsA(isA<SocialSignInException>()
            .having((e) => e.cancelled, 'cancelled', isFalse)
            .having((e) => e.message, 'message', allOf(contains('No BottlesUp Business account'), contains('Google'), contains('our website')))),
      );
      expect(events, ['credential google', 'supabase google', 'signed out']);
    });

    test('names Apple when it was Apple', () async {
      await expectLater(
        service(signIn: newAccount).signIn(SocialProvider.apple),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', contains('this Apple sign-in'))),
      );
    });

    test('is kept when the person came to accept an invitation', () async {
      await service(signIn: newAccount).signIn(SocialProvider.google, allowNewAccount: true);
      expect(events, ['credential google', 'supabase google']);
    });

    test('still tells the person even if signing out on the phone fails', () async {
      await expectLater(
        service(signIn: newAccount, signOut: () async => throw Exception('storage')).signIn(SocialProvider.google),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', contains('No BottlesUp Business account'))),
      );
    });
  });

  group('when it goes wrong', () {
    test('closing the Google or Apple sheet passes through as a cancel and Supabase is never asked', () async {
      await expectLater(
        service(credentials: (p) async => throw const SocialSignInException('cancelled', cancelled: true)).signIn(SocialProvider.apple),
        throwsA(isA<SocialSignInException>().having((e) => e.cancelled, 'cancelled', isTrue)),
      );
      expect(events, isEmpty);
    });

    test('a sheet error is passed on as it is', () async {
      await expectLater(
        service(credentials: (p) async => throw const SocialSignInException('Network error.')).signIn(SocialProvider.google),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', 'Network error.')),
      );
    });

    test('a token Supabase will not accept for this app is told as a set-up problem', () async {
      for (final message in ['Unacceptable audience in id_token: [x]', 'Nonces mismatch', 'Provider is not enabled', 'Unsupported provider: provider is not enabled']) {
        await expectLater(
          service(signIn: (p, c) async => throw AuthException(message)).signIn(SocialProvider.google),
          throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', 'Google sign-in is not set up for this app yet. Please contact support.')),
          reason: message,
        );
      }
    });

    test('any other Supabase answer is a plain "try again"', () async {
      await expectLater(
        service(signIn: (p, c) async => throw const AuthException('something else')).signIn(SocialProvider.apple),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', 'We could not sign you in with Apple. Please try again.')),
      );
    });

    test('a connection failure is told as one', () async {
      await expectLater(
        service(signIn: (p, c) async => throw TimeoutException('slow')).signIn(SocialProvider.google),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', 'We could not sign you in with Google. Check your connection and try again.')),
      );
    });

    test('an answer with no person in it is not taken as signed in', () async {
      await expectLater(
        service(signIn: (p, c) async => AuthResponse()).signIn(SocialProvider.google),
        throwsA(isA<SocialSignInException>().having((e) => e.message, 'message', 'We could not sign you in with Google. Please try again.')),
      );
      expect(events, ['credential google']);
    });
  });
}
