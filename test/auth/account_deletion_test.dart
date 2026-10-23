import 'dart:io';

import 'package:bottles_up_vendor/features/auth/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Deleting the account is the website's `delete-account` function (it removes the sign-in whatever else the account has), not the old database function that only removed the classic
// vendors row. These keep it that way, and keep a failed deletion from signing the person out.
void main() {
  late List<(String, Map<String, dynamic>)> calls;
  late int cleared;

  SupabaseAuthService service(Future<dynamic> Function(String name, Map<String, dynamic> body) invoke, {Future<void> Function()? clear}) {
    return SupabaseAuthService(
      invoker: (name, body) {
        calls.add((name, body));
        return invoke(name, body);
      },
      clearSession: clear ?? () async => cleared++,
    );
  }

  setUp(() {
    calls = [];
    cleared = 0;
  });

  group('deleteAccount', () {
    test('calls the website function once, as the signed-in person, and forgets the sign-in afterwards', () async {
      await service((n, b) async => {'success': true}).deleteAccount();
      expect(calls.length, 1);
      expect(calls.single.$1, 'delete-account');
      expect(calls.single.$2, isEmpty);
      expect(cleared, 1);
    });

    test('the sign-in is forgotten only after the function said it was done', () async {
      final order = <String>[];
      await service(
        (n, b) async {
          order.add('invoked');
          return {'success': true};
        },
        clear: () async => order.add('cleared'),
      ).deleteAccount();
      expect(order, ['invoked', 'cleared']);
    });

    test('an answer that is not "success" is not taken as done: the person stays signed in and is told', () async {
      for (final odd in <dynamic>[null, 'ok', {'success': false}, {'error': 'x'}, <dynamic>[], {'success': 'true'}]) {
        cleared = 0;
        await expectLater(
          service((n, b) async => odd).deleteAccount(),
          throwsA(isA<AccountDeletionException>().having((e) => e.message, 'message', 'We could not confirm that your account was deleted. Check your connection and try again.')),
          reason: '$odd',
        );
        expect(cleared, 0, reason: '$odd');
      }
    });

    test('a refusal because the sign-in expired says so, and keeps the person signed in', () async {
      await expectLater(
        service((n, b) async => throw const FunctionException(status: 401, details: {'error': 'Invalid or expired session'})).deleteAccount(),
        throwsA(isA<AccountDeletionException>().having((e) => e.message, 'message', 'Your sign-in has expired. Sign in again, then try again.')),
      );
      expect(cleared, 0);
    });

    test('a server error or a lost connection is a plain sentence, and keeps the person signed in', () async {
      for (final error in <Object>[const FunctionException(status: 500, details: {'error': 'Failed to delete account'}), Exception('socket closed'), StateError('x')]) {
        await expectLater(
          service((n, b) async => throw error).deleteAccount(),
          throwsA(isA<AccountDeletionException>().having((e) => e.message, 'message', 'We could not delete your account. Check your connection and try again.')),
          reason: '$error',
        );
      }
      expect(cleared, 0);
    });

    test('no technical text reaches the person', () async {
      try {
        await service((n, b) async => throw const FunctionException(status: 500, details: {'error': 'update or delete on table "users" violates foreign key constraint'})).deleteAccount();
        fail('should have thrown');
      } on AccountDeletionException catch (e) {
        expect(e.message, isNot(contains('violates')));
        expect(e.message, isNot(contains('foreign key')));
        expect(e.message, isNot(contains('500')));
      }
    });

    test('if forgetting the sign-in fails after the account is gone, the deletion still counts as done', () async {
      await service((n, b) async => {'success': true}, clear: () async => throw Exception('storage')).deleteAccount();
      expect(calls.length, 1);
    });
  });

  group('agrees with the website and the rest of the app', () {
    final fn = File('../bottles-up-website-main/supabase/functions/delete-account/index.ts');
    const why = 'website repo is not checked out next to this app';

    test('the function the app calls exists, wants a POST from a signed-in person and answers {success: true}', () {
      final ts = fn.readAsStringSync();
      expect(ts, contains("req.method !== 'POST'"));
      expect(ts, contains("req.headers.get('Authorization')"));
      expect(ts, contains('json({ success: true })'));
      expect(ts, contains('auth.admin.deleteUser(userId)'));
      expect(ts, contains('401'));
    }, skip: fn.existsSync() ? false : why);

    test('the app no longer calls the database function that only removed the classic vendors row', () {
      final service = File('lib/features/auth/services/supabase_auth_service.dart').readAsStringSync();
      expect(service, isNot(contains("rpc('delete_account'")));
      expect(service, contains("'delete-account'"));
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync(), isNot(contains("rpc('delete_account'")), reason: f.path);
      }
    });
  });
}
