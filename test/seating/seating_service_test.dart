import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_seating_backend.dart';

void main() {
  late FakeSeatingBackend db;
  setUp(() {
    db = FakeSeatingBackend();
    db.bookings.add(FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace'));
    db.bookings.add(FakeSeatBooking('b2', 'GRC222', 'Grace Hopper', owner: 'other'));
  });

  test('finding sends the club, the night and the trimmed query, and only this server\'s tables come back', () async {
    final found = await db.service.find('v1', '2026-10-09', '  ada ');
    expect(db.calledWith('desk_find_booking').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_query': 'ada'});
    expect(found.map((m) => m.bookingId), ['b1']);
    expect(await db.service.find('v1', '2026-10-09', 'GRC222'), isEmpty, reason: 'another server\'s table is not found');
  });

  test('a short query is refused with the database\'s sentence', () async {
    await expectLater(
      db.service.find('v1', '2026-10-09', 'ad'),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Type at least 3 letters of the name, or the booking code.')),
    );
  });

  test('seating by scan sends scan, no detail and the estimate', () async {
    final outcome = await db.service.seat('b1', estimateMinutes: 25);
    expect(db.calledWith('desk_mark_seated').single, {'p_booking': 'b1', 'p_method': 'scan', 'p_confirmation': null, 'p_estimate_minutes': 25});
    expect(outcome.already, isFalse);
    expect(outcome.estimateMinutes, 25);
    expect(db.bookings.first.seated, isTrue);
    expect(db.outbox.map((m) => m.kind), ['seated_ack']);
  });

  test('seating by hand sends the trimmed detail', () async {
    await db.service.seat('b1', manual: true, detail: '  asked for their email ');
    expect(db.calledWith('desk_mark_seated').single['p_method'], 'manual');
    expect(db.calledWith('desk_mark_seated').single['p_confirmation'], 'asked for their email');
  });

  test('a second tap says it was already done', () async {
    await db.service.seat('b1');
    final again = await db.service.seat('b1', estimateMinutes: 40);
    expect(again.already, isTrue);
    expect(db.outbox, hasLength(1), reason: 'nothing more is queued');
  });

  test('refusals are the database\'s own sentences', () async {
    await expectLater(db.service.seat('b2'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', "You don't have access to do that.")));
    await expectLater(
      db.service.seat('b1', manual: true, detail: 'ok'),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Say what you checked with the guest.')),
    );
    await expectLater(
      db.service.seat('b1', estimateMinutes: 900),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The estimate is between 1 and 480 minutes.')),
    );
  });

  test('the estimate: set, unchanged, cleared', () async {
    await db.service.seat('b1');
    expect(await db.service.setEstimate('b1', 30), isTrue);
    expect(await db.service.setEstimate('b1', 30), isFalse);
    expect(await db.service.setEstimate('b1', null), isTrue);
    expect(db.bookings.first.estimate, isNull);
    expect(db.outbox.where((m) => m.kind == 'estimate_updated'), hasLength(1), reason: 'clearing tells the guest nothing');
  });

  test('an estimate before seating is refused in words', () async {
    await expectLater(db.service.setEstimate('b1', 30), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Seat the guest first.')));
  });

  test('un-seating is for a manager and needs a reason', () async {
    await db.service.seat('b1');
    await expectLater(db.service.unseat('b1', 'wrong table'), throwsA(isA<OpsActionException>()));
    db.role = 'manager';
    await expectLater(db.service.unseat('b1', 'x'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Say why this guest is being un-seated.')));
    await db.service.unseat('b1', ' tapped the wrong table ');
    expect(db.calledWith('desk_unseat').last['p_reason'], 'tapped the wrong table');
    expect(db.bookings.first.seated, isFalse);
  });

  test('the state and the messages of one booking', () async {
    await db.service.seat('b1', estimateMinutes: 20);
    final s = await db.service.state('b1');
    expect([s.seated, s.method, s.estimateMinutes, s.seatedByName], [true, 'scan', 20, 'Me Myself']);
    final msgs = await db.service.messages('b1');
    expect(msgs.map((m) => m.statusLabel), ['Queued, not sent yet']);
  });

  test('reading failures say what happened', () async {
    db.missing = true;
    await expectLater(db.service.state('b1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.messages('b1'), throwsA(isA<OpsLoadException>().having((e) => e.message, 'message', contains('could not be loaded'))));
    await expectLater(db.service.find('v1', '2026-10-09', 'ada'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The search could not be done. Check your connection and try again.')));
    await expectLater(db.service.seat('b1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The guest could not be seated. Check your connection and try again.')));
  });
}
