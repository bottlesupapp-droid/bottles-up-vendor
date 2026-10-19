import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_night_backend.dart';

void main() {
  late FakeNightBackend db;
  setUp(() => db = FakeNightBackend());

  Future<void> expectRefusal(Future<Object?> f, String message) =>
      expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  test('the checklist is asked for with the club and the night, and ticking reports whether anything changed', () async {
    final items = await db.service.checklist('v1', '2026-10-09');
    expect(db.calledWith('night_checklist').single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    expect(items, hasLength(9));
    expect(items.where((i) => i.isClosing), hasLength(3));
    expect(await db.service.check('v1', '2026-10-09', 'floor_ready', true), isTrue);
    expect(await db.service.check('v1', '2026-10-09', 'floor_ready', true), isFalse);
    expect(db.calledWith('night_check').first, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_key': 'floor_ready', 'p_done': true});
    expect(await db.service.check('v1', '2026-10-09', 'floor_ready', false), isTrue);
  });

  test('refusals are the database\'s own sentences', () async {
    await expectRefusal(db.service.check('v1', '2026-10-09', 'make_tea', true), 'Choose a checklist item.');
    db.role = 'server';
    await expectRefusal(db.service.check('v1', '2026-10-09', 'floor_ready', true), "You don't have access to do that.");
    await expectLater(db.service.checklist('v1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.what, 'what', 'the checklist')));
  });

  test('closing with nothing open needs no excuse; an unticked closing item is itself an exception', () async {
    expect(await db.service.close('v1', '2026-10-09', acknowledge: true, note: 'closing without the checklist'), 3, reason: 'the three closing items are exceptions too');
    db.status = 'open';
    for (final k in ['floor_cleared', 'stock_counted', 'cash_secured']) {
      await db.service.check('v1', '2026-10-09', k, true);
    }
    expect(await db.service.close('v1', '2026-10-09'), 0);
    expect(db.closedNote, isNull);
  });

  test('closing with things open says what, and the note is trimmed', () async {
    db.blockers = [
      {'key': 'payments_to_check', 'label': 'payments waiting to be checked', 'count': 3},
    ];
    await expectLater(
      db.service.close('v1', '2026-10-09'),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', startsWith('Still open: 3 payments waiting to be checked'))),
    );
    await expectRefusal(db.service.close('v1', '2026-10-09', acknowledge: true, note: 'short'), 'Say why you are closing with these still open (at least 10 characters).');
    await db.service.close('v1', '2026-10-09', acknowledge: true, note: '  Owner agreed to chase it  ');
    expect(db.calledWith('close_night').last, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_acknowledge': true, 'p_note': 'Owner agreed to chase it'});
    expect(db.closedNote, 'Owner agreed to chase it');
    await expectRefusal(db.service.close('v1', '2026-10-09', acknowledge: true, note: 'Owner agreed to chase it'), 'This night is already closed.');
  });

  test('only the owner reopens, with a reason; the night must be closed', () async {
    db.status = 'closed';
    await expectRefusal(db.service.reopen('v1', '2026-10-09', 'we forgot to count the float'), "You don't have access to do that.");
    db.role = 'owner';
    await expectRefusal(db.service.reopen('v1', '2026-10-09', 'oops'), 'Say why this night is being reopened (at least 10 characters).');
    await db.service.reopen('v1', '2026-10-09', '  we forgot to count the float ');
    expect(db.calledWith('reopen_night').last['p_reason'], 'we forgot to count the float');
    await expectRefusal(db.service.reopen('v1', '2026-10-09', 'we forgot to count the float'), 'This night is not closed.');
  });

  test('the report is filtered by role and final once closed, and no longer moves', () async {
    var r = await db.service.report('v1', '2026-10-09');
    expect(r.view, 'full');
    expect(r.isFinal, isFalse);
    expect(r.sections.keys, containsAll(['bookings', 'payments', 'cash', 'flags', 'bottles', 'service', 'security']));
    db.role = 'verifier';
    r = await db.service.report('v1', '2026-10-09');
    expect(r.view, 'finance');
    expect(r.sections.keys, isNot(contains('security')));
    db.role = 'security';
    r = await db.service.report('v1', '2026-10-09');
    expect(r.sections.keys, ['security']);
    db.role = 'manager';
    await db.service.close('v1', '2026-10-09', acknowledge: true, note: 'closing for the test run');
    (db.live['payments'] as Map)['collected_cents'] = 99999999;
    r = await db.service.report('v1', '2026-10-09');
    expect(r.isFinal, isTrue);
    expect(r.sections['payments']!['collected_cents'], 13800, reason: 'the final report does not change when the books do');
    db.role = 'server';
    await expectLater(db.service.report('v1', '2026-10-09'), throwsA(isA<OpsLoadException>()));
  });

  test('a backend without the night functions says it is not available yet; a dropped connection says to try again', () async {
    db.missing = true;
    await expectLater(db.service.status('v1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.report('v1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    await expectRefusal(db.service.close('v1', '2026-10-09'), 'The night could not be closed. Check your connection and try again.');
  });
}
