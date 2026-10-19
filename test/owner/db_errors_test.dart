import 'package:bottles_up_vendor/features/owner/services/db_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException raised(String m) => PostgrestException(message: m, code: 'P0001');

void main() {
  group('a lack of access', () {
    test('is the database\'s own short refusal, as the whole message', () {
      for (final m in ['not allowed', 'not authorized', 'not authorised', 'not authenticated', ' Not Allowed ', 'not allowed.']) {
        expect(isNoAccess(raised(m)), isTrue, reason: m);
      }
    });

    test('is also an access that has ended, or a sign-out', () {
      expect(isNoAccess(StateError('Your access has ended')), isTrue);
      expect(isNoAccess(StateError('you are signed out')), isTrue);
    });

    test('is NOT a longer sentence that merely contains those words: that is a reason to show', () {
      for (final m in [
        'the club has not allowed door staff for this event',
        'this action is not allowed while the night is closed',
        'a manager is not authorized to change an owner',
        'user not authenticated by the provider',
      ]) {
        expect(isNoAccess(raised(m)), isFalse, reason: m);
      }
    });

    test('so a reason is shown as it is, and a real refusal says access', () {
      expect(actionMessage(raised('the club has not allowed door staff for this event')), 'the club has not allowed door staff for this event');
      expect(actionMessage(raised('not allowed')), "You don't have access to do that.");
      expect(actionMessage(StateError('socket'), generic: 'Try again.'), 'Try again.');
    });
  });
}
