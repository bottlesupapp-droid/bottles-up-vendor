import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The production database has no foreign key from `inquiries` or `events_bookings` to `events`, so the embedded form of a query (`events!inner(...)`) is answered
// with PGRST200 ("Could not find a relationship ...") and the whole Reports page stays on its error. (Seen on a real account, 15 Nov: every tab said it could
// not load.) The providers read the account's own event ids first and filter with `inFilter`; this keeps an embedded form from coming back by accident.
void main() {
  // (Comments are left out: the file explains the embedded form in words.)
  final source = File('lib/features/analytics/providers/analytics_provider.dart').readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('no query asks the database to follow a relationship from inquiries or bookings to events', () {
    expect(source.contains('events!inner'), isFalse);
    expect(RegExp(r"select\([^)]*\bevents\s*\(").hasMatch(source), isFalse);
  });

  test('inquiries and bookings are read for the account\'s own events, by their ids', () {
    expect(source, contains("from('events').select('id, name').eq('user_id', userId)"));
    expect(RegExp(r"inFilter\('event_id', myEventIds\)").allMatches(source).length, 3, reason: 'inquiries, the last seven days, and the last three months');
  });

  test('an account with no events asks nothing of inquiries or bookings', () {
    expect(RegExp(r'myEventIds\.isEmpty\s*\?\s*const \[\]').allMatches(source).length, 3);
  });
}
