import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_agreement_backend.dart';

void main() {
  late FakeAgreementBackend db;
  setUp(() => db = FakeAgreementBackend());

  Future<void> expectRefusal(Future<Object?> f, String message) =>
      expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  test('the two lists ask for a club or for a business, never both', () async {
    db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
    final rows = await db.service.listForVenue('v1');
    expect(db.calledWith('agreement_list').single, {'p_venue': 'v1', 'p_org': null});
    expect(rows.single.waitingOn, 'venue');
    await db.service.listForOrg('o1');
    expect(db.calledWith('agreement_list').last, {'p_venue': null, 'p_org': 'o1'});
  });

  test('searching clubs offers only clubs that belong to a business', () async {
    final found = await db.service.searchClubs(' club ');
    expect(db.calledWith('search_venues').single, {'p_query': 'club'});
    expect(found.map((c) => c.name), ['Club A', 'Club Alpha'], reason: 'Club Alone is not claimed');
  });

  test('asking sends the event, the club and the trimmed message; only an organizer may; a second open request is refused', () async {
    db.side = 'organizer';
    final id = await db.service.request('e1', 'v1', message: '  Friday, 400 guests  ');
    expect(db.calledWith('agreement_request').single, {'p_event': 'e1', 'p_venue': 'v1', 'p_message': 'Friday, 400 guests'});
    expect(db.agreement(id).requestNote, 'Friday, 400 guests');
    await expectRefusal(db.service.request('e1', 'v1'), 'This event already has an agreement with that club.');
    db.side = 'venue';
    await expectRefusal(db.service.request('e1', 'v2'), "You don't have access to do that.");
  });

  test('proposing makes numbered versions; accepting is of the latest only; accepting twice changes nothing', () async {
    final a = FakeAgreement('a1', 'Night One', 'Club A');
    db.agreements.add(a);
    await expectRefusal(db.service.accept('a1', 1), 'Nothing has been proposed yet.');
    expect(await db.service.propose('a1', {'capacity': 400}, note: ' first '), 1);
    expect(db.calledWith('agreement_propose').single, {'p_agreement': 'a1', 'p_terms': {'capacity': 400}, 'p_note': 'first'});
    db.otherProposes('a1', {'capacity': 350});
    await expectRefusal(db.service.accept('a1', 1), 'That version was replaced: read the latest one.');
    expect(await db.service.accept('a1', 2), isTrue);
    expect(a.status, 'active');
    expect(await db.service.accept('a1', 2), isFalse);
  });

  test('a share of bar sales without a threshold is refused in the database\'s words', () async {
    db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
    await expectRefusal(db.service.propose('a1', {'bar_percent': 10}), 'A share of bar sales needs a threshold (0 if it applies from the first sale).');
    await expectRefusal(db.service.propose('a1', {}), 'Propose at least one term.');
  });

  test('closing needs a reason; a club declines before anything is active, an organizer withdraws; a closed one is closed', () async {
    db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
    await expectRefusal(db.service.close('a1', ' '), 'Say why.');
    await db.service.close('a1', '  We are closed that night ');
    expect(db.agreement('a1').status, 'declined');
    expect(db.calledWith('agreement_close').last['p_reason'], 'We are closed that night');
    await expectRefusal(db.service.close('a1', 'again'), 'This agreement is already closed.');
    await expectRefusal(db.service.propose('a1', {'capacity': 1}), 'This agreement is closed.');
    db.agreements.add(FakeAgreement('a2', 'Night Two', 'Club B'));
    db.side = 'organizer';
    await db.service.close('a2', 'Event cancelled');
    expect(db.agreement('a2').status, 'cancelled');
  });

  test('notes are trimmed and cannot be empty', () async {
    db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
    await db.service.note('a1', '  Can we move the threshold?  ');
    expect(db.calledWith('agreement_note').single, {'p_agreement': 'a1', 'p_body': 'Can we move the threshold?'});
    await expectRefusal(db.service.note('a1', ' '), 'Write the note first.');
  });

  test('a backend without agreements says it is not available yet; a dropped connection says to try again', () async {
    db.missing = true;
    await expectLater(db.service.listForVenue('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.detail('a1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    await expectRefusal(db.service.accept('a1', 1), 'That could not be recorded. Check your connection and try again.');
  });
}
