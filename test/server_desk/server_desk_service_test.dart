import 'package:bottles_up_vendor/features/floor/logic/bookings_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/services/server_desk_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_desk_backend.dart';

void main() {
  late FakeDeskBackend db;
  setUp(() {
    db = FakeDeskBackend();
    db.addBooking('b1', code: 'AB12CD');
    db.assignments['b1'] = 'm-me';
  });

  Matcher loadFailure({bool unavailable = false, bool accessEnded = false}) => throwsA(isA<ServerDeskLoadException>()
      .having((e) => e.unavailable, 'unavailable', unavailable)
      .having((e) => e.accessEnded, 'accessEnded', accessEnded));

  Matcher actionFailure(String message) => throwsA(isA<ServerDeskActionException>().having((e) => e.message, 'message', message));

  group('my tables', () {
    test('asks for one night by the argument name the database defines, and reads the rows', () async {
      final tables = await db.service.myTables('2026-10-09');
      expect(db.calls.map((c) => c.$1), ['my_assigned_tables']);
      expect(db.params, [
        {'p_night': '2026-10-09'},
      ]);
      expect(tables.map((t) => t.bookingId), ['b1']);
      expect(tables.single.customerName, 'Ada Lovelace');
    });

    test('a night that is not a date never leaves the phone', () async {
      for (final bad in ['', 'tonight', '2026-02-30', '09/10/2026']) {
        expect(() => db.service.myTables(bad), throwsArgumentError, reason: bad);
      }
      expect(db.calls, isEmpty);
    });

    test('a row it cannot read is dropped and the rest kept; no rows, or something that is not a list, is no tables', () async {
      final svc = ServerDeskService(rpc: (f, {params}) async => [
            {'booking_id': 'x'},
            'not a row',
            {'booking_id': 'b2', 'venue_id': 'v1', 'night_date': '2026-10-09'},
          ]);
      expect((await svc.myTables('2026-10-09')).map((t) => t.bookingId), ['b2']);
      expect(await ServerDeskService(rpc: (f, {params}) async => null).myTables('2026-10-09'), isEmpty);
      expect(await ServerDeskService(rpc: (f, {params}) async => {'oops': 1}).myTables('2026-10-09'), isEmpty);
    });

    test('a database without the migration is "unavailable", which retrying cannot fix', () async {
      for (final code in ['42883', 'PGRST202', '42P01']) {
        db.failAll = PostgrestException(message: 'function does not exist', code: code);
        await expectLater(db.service.myTables('2026-10-09'), loadFailure(unavailable: true), reason: code);
      }
      db.failAll = PostgrestException(message: 'x', code: '42883');
      try {
        await db.service.myTables('2026-10-09');
      } on ServerDeskLoadException catch (e) {
        expect(e.message, 'Tables are not set up on this server yet.');
      }
    });

    test('a person who lost their access is told so, and a dropped connection is a plain failure', () async {
      for (final m in ['not allowed', 'not authenticated', 'Your access has ended']) {
        db.failAll = PostgrestException(message: m, code: 'P0001');
        await expectLater(db.service.myTables('2026-10-09'), loadFailure(accessEnded: true), reason: m);
      }
      db.failAll = Exception('SocketException: connection lost');
      await expectLater(db.service.myTables('2026-10-09'), loadFailure());
    });
  });

  group('requests', () {
    test('asks for a club\'s open requests; the finished ones only when asked', () async {
      db.addRequest('b1', 'water_ice_mixers', assigned: 'm-me', rid: 'r1');
      final open = await db.service.requests('v1');
      await db.service.requests('v1', includeClosed: true);
      expect(db.calls.map((c) => c.$2), [
        {'p_venue': 'v1', 'p_include_closed': false},
        {'p_venue': 'v1', 'p_include_closed': true},
      ]);
      expect(open.single.kind, ServiceKind.waterIceMixers);
    });

    test('a request with a status or kind it does not know is dropped', () async {
      final svc = ServerDeskService(rpc: (f, {params}) async => [
            {'request_id': 'r1', 'booking_id': 'b1', 'kind': 'assistance', 'status': 'new', 'created_at': '2026-10-09T21:00:00Z'},
            {'request_id': 'r2', 'booking_id': 'b1', 'kind': 'assistance', 'status': 'vanished', 'created_at': '2026-10-09T21:00:00Z'},
          ]);
      expect((await svc.requests('v1')).map((r) => r.requestId), ['r1']);
    });

    test('failures are reported as the screen needs them', () async {
      db.failAll = PostgrestException(message: 'nope', code: '42883');
      try {
        await db.service.requests('v1');
        fail('should have thrown');
      } on ServerDeskLoadException catch (e) {
        expect(e.unavailable, isTrue);
        expect(e.message, 'Requests are not set up on this server yet.');
      }
      db.failAll = PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.requests('v1'), loadFailure(accessEnded: true));
    });
  });

  group('asking for something', () {
    test('sends the booking, the kind and a trimmed note, and returns the request', () async {
      final id = await db.service.ask('b1', ServiceKind.waterIceMixers, note: '  two limes ');
      expect(db.calls.single.$1, 'create_service_request');
      expect(db.calls.single.$2, {'p_booking': 'b1', 'p_kind': 'water_ice_mixers', 'p_note': 'two limes'});
      expect(db.requests.single.id, id);
      expect(db.requests.single.assigned, 'm-me', reason: 'it goes to the table\'s server');
    });

    test('asking twice for the same thing is one request (a double tap is harmless)', () async {
      final a = await db.service.ask('b1', ServiceKind.billRequest);
      final b = await db.service.ask('b1', ServiceKind.billRequest);
      expect(b, a);
      expect(db.requests, hasLength(1));
    });

    test('a note over the limit is refused before anything is sent', () async {
      await expectLater(db.service.ask('b1', ServiceKind.assistance, note: 'x' * 301), actionFailure('Keep it to 300 characters or fewer.'));
      expect(db.calls, isEmpty);
    });

    test('the database\'s refusals come back as sentences', () async {
      db.assignments['b1'] = 'm-colleague';
      await expectLater(db.service.ask('b1', ServiceKind.assistance), actionFailure('This table belongs to another server.'));
      db.bookings['b1']!.status = 'refunded';
      db.assignments.remove('b1');
      await expectLater(db.service.ask('b1', ServiceKind.assistance), actionFailure('Only a paid booking can have service requests.'));
    });

    test('a person without access is told so; a dropped connection is a plain failure; an odd answer is not taken for a request', () async {
      db.level = 'none';
      await expectLater(db.service.ask('b1', ServiceKind.assistance), actionFailure('You don\'t have access to do that.'));
      db.level = 'server';
      db.failAll = Exception('SocketException: connection lost');
      await expectLater(db.service.ask('b1', ServiceKind.assistance), actionFailure('The request could not be made. Check your connection and try again.'));
      await expectLater(ServerDeskService(rpc: (f, {params}) async => null).ask('b1', ServiceKind.assistance), actionFailure('The request could not be made.'));
      await expectLater(ServerDeskService(rpc: (f, {params}) async => '').ask('b1', ServiceKind.assistance), actionFailure('The request could not be made.'));
    });
  });

  group('moving a request along', () {
    test('sends the request, the move and the reason', () async {
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      await db.service.act('r1', RequestAction.acknowledge);
      await db.service.act('r1', RequestAction.escalate, note: ' guest wants the owner ');
      expect(db.calls.map((c) => c.$1), ['update_service_request', 'update_service_request']);
      expect(db.params, [
        {'p_request': 'r1', 'p_action': 'acknowledge', 'p_note': null},
        {'p_request': 'r1', 'p_action': 'escalate', 'p_note': 'guest wants the owner'},
      ]);
      expect(db.requests.single.status, 'escalated');
    });

    test('escalating or cancelling without a reason never leaves the phone', () async {
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      for (final a in [RequestAction.escalate, RequestAction.cancel]) {
        await expectLater(db.service.act('r1', a), actionFailure('Say why.'));
        await expectLater(db.service.act('r1', a, note: '   '), actionFailure('Say why.'));
        await expectLater(db.service.act('r1', a, note: 'x' * 301), actionFailure('Keep it to 300 characters or fewer.'));
      }
      expect(db.calls, isEmpty);
    });

    test('a move that needs no reason can carry a remark, within the limit', () async {
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      await expectLater(db.service.act('r1', RequestAction.complete, note: 'x' * 301), actionFailure('Keep it to 300 characters or fewer.'));
      await db.service.act('r1', RequestAction.complete, note: 'sorted');
      expect(db.requests.single.statusNote, 'sorted');
    });

    test('a colleague who tries next is told someone else has it', () async {
      db.addRequest('b1', 'assistance', status: 'acknowledged', assigned: 'm-colleague', rid: 'r1');
      await expectLater(db.service.act('r1', RequestAction.acknowledge), actionFailure('Someone else has already taken this request.'));
    });

    test('the other refusals, in the database\'s words', () async {
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      await expectLater(db.service.act('r1', RequestAction.start), actionFailure('Acknowledge the request first.'));
      db.requests.single.status = 'escalated';
      await expectLater(db.service.act('r1', RequestAction.complete), actionFailure('This request was passed to a manager.'));
      db.requests.single
        ..status = 'completed'
        ..closedAt = db.now;
      await expectLater(db.service.act('r1', RequestAction.cancel, note: 'oops'), actionFailure('This request is already closed.'));
    });

    test('a dropped connection is a plain failure', () async {
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      db.failAll = Exception('SocketException: connection lost');
      await expectLater(db.service.act('r1', RequestAction.acknowledge), actionFailure('That could not be done. Check your connection and try again.'));
    });
  });

  group('giving a table to a server (the manager\'s side)', () {
    const range = NightRange('2026-10-09', '2026-10-11');
    setUp(() {
      db.level = 'manager';
      db.staff['m-sam'] = 'ok';
    });

    test('who has which booking, for these nights', () async {
      final list = await db.service.bookingServers('v1', range);
      expect(db.calls.single.$1, 'list_venue_booking_servers');
      expect(db.calls.single.$2, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-11'});
      expect((list.single.bookingId, list.single.membershipId, list.single.available), ('b1', 'm-me', true));
    });

    test('a range the database would refuse never leaves the phone', () async {
      for (final bad in [const NightRange('2026-10-11', '2026-10-09'), const NightRange('', '2026-10-09'), NightRange('2026-10-09', addDays('2026-10-09', maxNights))]) {
        expect(() => db.service.bookingServers('v1', bad), throwsArgumentError, reason: '$bad');
      }
      expect(db.calls, isEmpty);
    });

    test('a server who is not a manager is refused, and a missing migration is "unavailable"', () async {
      db.level = 'server';
      await expectLater(db.service.bookingServers('v1', range), loadFailure(accessEnded: true));
      db.failAll = PostgrestException(message: 'x', code: 'PGRST202');
      await expectLater(db.service.bookingServers('v1', range), loadFailure(unavailable: true));
    });

    test('gives a booking to a server and takes it away, by the argument names the database defines', () async {
      await db.service.assignServer('b1', 'm-sam');
      expect(db.calls.last.$1, 'assign_booking_server');
      expect(db.calls.last.$2, {'p_booking': 'b1', 'p_membership': 'm-sam'});
      expect(db.assignments['b1'], 'm-sam');
      await db.service.unassignServer('b1');
      expect(db.calls.last.$1, 'unassign_booking_server');
      expect(db.calls.last.$2, {'p_booking': 'b1'});
      expect(db.assignments, isEmpty);
    });

    test('the database\'s refusals come back as sentences', () async {
      db.staff['m-old'] = 'revoked';
      db.staff['m-door'] = 'door';
      await expectLater(db.service.assignServer('b1', 'm-old'), actionFailure('That person no longer has access to this club.'));
      await expectLater(db.service.assignServer('b1', 'm-door'), actionFailure('That person is not a server at this club.'));
      await expectLater(db.service.assignServer('b1', 'nobody'), actionFailure('That person is not a server at this club.'));
      db.bookings['b1']!.status = 'pending';
      await expectLater(db.service.assignServer('b1', 'm-sam'), actionFailure('Only a paid booking can be given to a server.'));
      db.level = 'server';
      await expectLater(db.service.assignServer('b1', 'm-sam'), actionFailure('You don\'t have access to do that.'));
      await expectLater(db.service.unassignServer('b1'), actionFailure('You don\'t have access to do that.'));
    });

    test('a dropped connection is a plain failure', () async {
      db.failAll = Exception('SocketException: connection lost');
      await expectLater(db.service.assignServer('b1', 'm-sam'), actionFailure('The table could not be given to this server. Check your connection and try again.'));
      await expectLater(db.service.unassignServer('b1'), actionFailure('The server could not be taken off this table. Check your connection and try again.'));
    });
  });
}
