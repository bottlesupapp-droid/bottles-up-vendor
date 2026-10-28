import 'dart:math';

import 'package:bottles_up_vendor/features/auth/services/social_sign_in_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({required String createdAt, String? lastSignInAt}) =>
    User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: createdAt, lastSignInAt: lastSignInAt);

void main() {
  group('nonce', () {
    test('is 32 characters from the safe alphabet by default', () {
      final nonce = newNonce();
      expect(nonce.length, 32);
      expect(RegExp(r'^[0-9A-Za-z\-._]+$').hasMatch(nonce), isTrue);
    });

    test('has the length asked for and follows the random source it is given', () {
      expect(newNonce(Random(1), 8).length, 8);
      expect(newNonce(Random(7)), newNonce(Random(7)));
      expect(newNonce(Random(7)), isNot(newNonce(Random(8))));
      expect(newNonce(), isNot(newNonce()));
    });

    test('uses the whole alphabet, not a few letters', () {
      final seen = <String>{};
      final random = Random(3);
      for (var i = 0; i < 200; i++) {
        seen.addAll(newNonce(random).split(''));
      }
      expect(seen.length, 65);
    });
  });

  test('sha256Hex matches the published test values', () {
    expect(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  });

  group('appleFullName', () {
    test('joins, trims and keeps whichever part there is', () {
      expect(appleFullName('Dana', 'Lee'), 'Dana Lee');
      expect(appleFullName('Dana', null), 'Dana');
      expect(appleFullName(null, 'Lee'), 'Lee');
      expect(appleFullName('  Dana ', ' '), 'Dana');
    });

    test('is null when Apple gave no name', () {
      expect(appleFullName(null, null), isNull);
      expect(appleFullName('', '  '), isNull);
    });
  });

  group('accountJustCreated', () {
    test('is true when the account and the sign-in are the same moment (a new account)', () {
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00.000Z', lastSignInAt: '2026-10-28T10:00:00.000Z')), isTrue);
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00.000Z', lastSignInAt: '2026-10-28T10:00:00.800Z')), isTrue);
    });

    test('is true up to 30 seconds apart, whichever came first, and false after', () {
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00Z', lastSignInAt: '2026-10-28T10:00:30Z')), isTrue);
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:30Z', lastSignInAt: '2026-10-28T10:00:00Z')), isTrue);
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00Z', lastSignInAt: '2026-10-28T10:00:31Z')), isFalse);
    });

    test('is false for an account that existed before (a returning person, or a Google identity joined to an e-mail account)', () {
      expect(accountJustCreated(_user(createdAt: '2026-09-01T09:00:00Z', lastSignInAt: '2026-10-28T10:00:00Z')), isFalse);
    });

    test('is false when the times are missing or unreadable, so nobody is turned away on a guess', () {
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00Z')), isFalse);
      expect(accountJustCreated(_user(createdAt: 'not a time', lastSignInAt: '2026-10-28T10:00:00Z')), isFalse);
      expect(accountJustCreated(_user(createdAt: '2026-10-28T10:00:00Z', lastSignInAt: 'nope')), isFalse);
    });

    test('the window can be changed', () {
      final user = _user(createdAt: '2026-10-28T10:00:00Z', lastSignInAt: '2026-10-28T10:02:00Z');
      expect(accountJustCreated(user), isFalse);
      expect(accountJustCreated(user, within: const Duration(minutes: 3)), isTrue);
    });
  });
}
