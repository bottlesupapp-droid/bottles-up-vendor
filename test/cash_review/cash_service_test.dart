import 'package:bottles_up_vendor/features/cash_review/logic/cash_rules.dart';
import 'package:bottles_up_vendor/features/cash_review/services/cash_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_cash_backend.dart';

void main() {
  late FakeCashBackend db;
  setUp(() {
    db = FakeCashBackend();
    db.collected['u-sam'] = 7800;
    db.collected['u-me'] = 2000;
  });

  group('reading', () {
    test('the cash position goes to desk_cash_position with the club and the night', () async {
      final lines = await db.service.position('v1', '2026-10-09');
      expect(db.calledWith('desk_cash_position').single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(lines.map((l) => l.collectorName), ['Me Myself', 'Sam Server']);
      expect(lines.first.isMe, isTrue);
      expect(lines.last.heldCents, 7800);
    });

    test('handovers, flags and the summary', () async {
      db.flags.add(FakeFlag('f1', 'p1', 'Ada', 'VIP booth', 'debit', 3000, 'off', 'u-sam', DateTime(2026, 10, 9)));
      expect(await db.service.handovers('v1', '2026-10-09'), isEmpty);
      expect((await db.service.flags('v1')).single.customerName, 'Ada');
      expect(db.calledWith('desk_list_flags').single, {'p_venue': 'v1', 'p_status': 'open'});
      await db.service.flags('v1', resolved: true);
      expect(db.calledWith('desk_list_flags').last['p_status'], 'resolved');
      expect((await db.service.summary('v1', '2026-10-09')).flagsOpen, 1);
    });
  });

  group('doing', () {
    test('handing in sends the amount and the note and returns the id', () async {
      final id = await db.service.submit('v1', '2026-10-09', 1200, note: ' part ');
      expect(id, 'h1');
      expect(db.calledWith('desk_submit_handover').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_amount_cents': 1200, 'p_note': 'part'});
    });

    test('a refusal is the database\'s own sentence, with a full stop', () async {
      await expectLater(
        db.service.submit('v1', '2026-10-09', 99999),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You only hold 20.00 for this night.')),
      );
    });

    test('counting returns the difference and sends the count', () async {
      db.handovers.add(FakeHandover('h9', 'u-sam', 3000, DateTime(2026, 10, 9)));
      final difference = await db.service.receive('h9', 2900, note: 'torn');
      expect(difference, -100);
      expect(db.calledWith('desk_receive_handover').single, {'p_handover': 'h9', 'p_counted_cents': 2900, 'p_note': 'torn'});
    });

    test('counting your own handover is refused in words', () async {
      db.handovers.add(FakeHandover('h8', 'u-me', 500, DateTime(2026, 10, 9)));
      await expectLater(
        db.service.receive('h8', 500),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You handed this in, so someone else has to count it.')),
      );
    });

    test('flagging trims the reason, and resolving without a note sends none', () async {
      await db.service.flagPayment('p1', '  till says 30.00 ');
      expect(db.calledWith('desk_flag_payment').single, {'p_payment': 'p1', 'p_reason': 'till says 30.00'});
      db.role = 'manager';
      await db.service.resolveFlag(db.flags.single.id, 'confirmed_ok');
      expect(db.calledWith('desk_resolve_flag').single, {'p_flag': db.flags.single.id, 'p_resolution': 'confirmed_ok', 'p_note': null});
    });

    test('a dropped connection is a plain sentence, not a stack trace', () async {
      db.offline = true;
      await expectLater(
        db.service.submit('v1', '2026-10-09', 100),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The handover could not be sent. Check your connection and try again.')),
      );
    });

    test('no access is said as no access', () async {
      db.role = 'server';
      db.handovers.add(FakeHandover('h7', 'u-sam', 500, DateTime(2026, 10, 9)));
      await expectLater(
        db.service.receive('h7', 500),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', "You don't have access to do that.")),
      );
    });
  });

  group('failing to read', () {
    test('a server without the migration is "not set up", and offers no retry', () async {
      db.missing = true;
      await expectLater(
        db.service.position('v1', '2026-10-09'),
        throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true).having((e) => e.message, 'message', 'Cash figures are not set up on this server yet.')),
      );
    });

    test('a dropped connection is a retryable failure', () async {
      db.offline = true;
      await expectLater(
        db.service.handovers('v1', '2026-10-09'),
        throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false).having((e) => e.message, 'message', contains('could not be loaded'))),
      );
    });

    test('no access to the club is said so', () async {
      db.role = 'server';
      await expectLater(
        db.service.flags('v1'),
        throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', true)),
      );
    });

    test('a row that cannot be used is dropped, not a crash', () async {
      final service = CashService(caller: (f, {params}) async => [
            {'handover_id': 'h1', 'claimed_cents': 100},
            {'claimed_cents': 5},
            'junk',
          ]);
      final list = await service.handovers('v1', '2026-10-09');
      expect(list.map((h) => h.id), ['h1']);
    });

    test('an answer that is not a list is nothing', () async {
      final service = CashService(caller: (f, {params}) async => null);
      expect(await service.handovers('v1', '2026-10-09'), isEmpty);
    });

    test('the summary with no row is a failure that says so', () async {
      final service = CashService(caller: (f, {params}) async => <dynamic>[]);
      await expectLater(service.summary('v1', '2026-10-09'), throwsA(isA<OpsLoadException>()));
    });

    test('PostgrestException is what the real client throws, and the fake raises the same kind', () {
      expect(refuse('x'), isA<PostgrestException>());
    });
  });
}
