import 'package:bottles_up_vendor/features/booking_conflicts/logic/conflict_rules.dart';
import 'package:bottles_up_vendor/features/booking_conflicts/providers/conflict_providers.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_conflict_backend.dart';

late FakeConflictBackend db;

// the plain sentence a person reads for one of the database's own
String said(String raw) => '${raw[0].toUpperCase()}${raw.substring(1)}.';

Future<String> failure(Future<void> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  return 'accepted';
}

void main() {
  setUp(() {
    db = FakeConflictBackend();
    db.add('k1');
    db.add('k2', status: 'resolved');
    db.add('k3', venue: 'v2');
  });

  test('a query for the open ones and a query that also wants the settled ones are different questions (they must not share an answer)', () {
    expect(const ConflictsQuery('v1') == const ConflictsQuery('v1'), isTrue);
    expect(const ConflictsQuery('v1').hashCode, const ConflictsQuery('v1').hashCode);
    expect(const ConflictsQuery('v1') == const ConflictsQuery('v1', includeSettled: true), isFalse);
    expect(const ConflictsQuery('v1') == const ConflictsQuery('v2'), isFalse);
    expect(const ConflictsQuery('v1', includeSettled: true) == const ConflictsQuery('v1', includeSettled: true), isTrue);
  });

  group('the list', () {
    test('asks for the club\'s open ones, by name', () async {
      final list = await db.service.list('v1');
      expect(db.calls.single.$1, 'desk_booking_conflicts');
      expect(db.calls.single.$2, {'p_venue': 'v1', 'p_include_resolved': false});
      expect([for (final c in list) c.conflictId], ['k1']);
    });

    test('and, when asked, the settled ones after the open ones', () async {
      final list = await db.service.list('v1', includeSettled: true);
      expect(db.calls.single.$2, {'p_venue': 'v1', 'p_include_resolved': true});
      expect([for (final c in list) c.conflictId], ['k1', 'k2']);
    });

    test('rows it cannot use are dropped, not guessed at', () async {
      db.failOn.clear();
      final svc = db.service;
      db.rows.add(FakeConflict('k9', status: 'weird'));
      final list = await svc.list('v1', includeSettled: true);
      expect(list.any((c) => c.conflictId == 'k9'), isFalse);
    });

    test('a database without the migration says so, with nothing to retry', () async {
      db.failAll = PostgrestExceptionFor.missing();
      try {
        await db.service.list('v1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [true, false]);
        expect(e.message, 'The double-booked tables are not set up on this server yet.');
      }
    });

    test('someone who may not see them is told their access has ended, not shown a blank', () async {
      db.level = 'server';
      try {
        await db.service.list('v1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [false, true]);
      }
    });

    test('a dropped connection is a plain failure that can be tried again', () async {
      db.failAll = Exception('SocketException: Failed host lookup');
      try {
        await db.service.list('v1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [false, false]);
        expect(e.message, isNot(contains('Socket')));
      }
    });
  });

  group('closing one', () {
    test('sends the conflict, the way and the trimmed words, and the database records it', () async {
      db.rows.firstWhere((r) => r.id == 'k1').stillOverbooked = false;
      await db.service.resolve('k1', ConflictResolution.moved, '  Moved to table 4  ');
      expect(db.calls.single.$1, 'desk_resolve_booking_conflict');
      expect(db.calls.single.$2, {'p_conflict': 'k1', 'p_resolution': 'moved', 'p_note': 'Moved to table 4'});
      final c = db.rows.firstWhere((r) => r.id == 'k1');
      expect([c.status, c.resolution, c.note], ['resolved', 'moved', 'Moved to table 4']);
    });

    test('what is missing is said before anything is sent', () async {
      expect(await failure(() => db.service.resolve('k1', null, 'Moved to table 4')), 'Say how it was settled.');
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.kept, ' ')), 'Say what was done, in a few words.');
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.kept, 'x' * 501)), 'Keep the note to 500 characters or fewer.');
      expect(db.calls, isEmpty);
    });

    test('each refusal by the database is its own sentence', () async {
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.moved, 'Moved to table 4')), said('that table is still double-booked: move the booking to another table first'));
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.refunded, 'Paid back')), said('refund or cancel the booking first'));
      db.rows.firstWhere((r) => r.id == 'k1').bookingStatus = 'cancelled';
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.moved, 'Moved to table 4')), said('the booking is not paid any more: close this as refunded'));
      expect(await failure(() => db.service.resolve('k2', ConflictResolution.kept, 'Closed again')), said('this has already been dealt with'));
      expect(await failure(() => db.service.resolve('nope', ConflictResolution.kept, 'Closed again')), 'You don\'t have access to do that.');
      db.level = 'server';
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.kept, 'Closed again')), 'You don\'t have access to do that.');
    });

    test('"kept" needs no proof, and a cancelled booking can be closed as refunded', () async {
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.kept, 'Opened another booth')), 'accepted');
      db.add('k5', bookingStatus: 'cancelled');
      expect(await failure(() => db.service.resolve('k5', ConflictResolution.refunded, 'Cancelled and paid back')), 'accepted');
    });

    test('a dropped connection gets a plain sentence, not the technical one', () async {
      db.failAll = Exception('SocketException: Failed host lookup');
      expect(await failure(() => db.service.resolve('k1', ConflictResolution.kept, 'Opened another booth')), 'This could not be saved. Check your connection and look at the list before trying again.');
    });
  });
}

