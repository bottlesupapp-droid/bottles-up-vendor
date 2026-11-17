import 'dart:io';

import 'package:bottles_up_vendor/features/settlements/logic/settlement_adjustment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settlement_backend.dart';

// The app and the database must agree on names. This reads the website repo's migration when it is checked out next to this app (the monorepo); on its own it is skipped.
void main() {
  final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
  final sql = File('$website/supabase/migrations/20261125100000_settlement_adjustments.sql');
  const skip = 'website repo is not checked out next to this app (or does not have the adjustments migration)';

  group('agrees with the website', () {
    late String text;
    setUpAll(() {
      if (sql.existsSync()) text = sql.readAsStringSync();
    });

    String signatureOf(String function) {
      final start = text.indexOf('create function public.$function(');
      expect(start, greaterThanOrEqualTo(0), reason: function);
      return text.substring(start, text.indexOf('returns', start));
    }

    test('every function the service calls is defined, and every argument it sends is one the function takes', () {
      final calls = {
        'settlement_adjustments': ['p_agreement'],
        'settlement_adjustment_flags_for_venue': ['p_venue'],
        'settlement_adjustment_flags_for_organizer': ['p_org'],
        'settlement_adjustment_record': ['p_settlement', 'p_kind', 'p_amount_cents', 'p_reason', 'p_ref'],
        'settlement_adjustment_question': ['p_adjustment', 'p_reason'],
        'settlement_adjustment_answer': ['p_adjustment', 'p_note'],
        'settlement_adjustment_acknowledge': ['p_adjustment'],
        'settlement_adjustment_settle': ['p_adjustment', 'p_amount_cents', 'p_paid_on', 'p_reference', 'p_evidence'],
        'settlement_adjustment_waive': ['p_adjustment', 'p_reason'],
      };
      for (final entry in calls.entries) {
        final signature = signatureOf(entry.key);
        for (final arg in entry.value) {
          expect(signature, contains(arg), reason: '${entry.key} takes $arg');
        }
      }
    });

    test('the service sends exactly the arguments listed above (nothing the function does not take)', () async {
      final db = FakeSettlementBackend();
      await db.service.adjustments('a');
      await db.service.adjustmentFlagsForVenue('v');
      await db.service.adjustmentFlagsForOrganizer('o');
      await db.service.recordAdjustment('s', kind: 'refund', amountCents: -1, reason: 'abc', reference: 'abc');
      await db.service.questionAdjustment('x', 'abcde');
      await db.service.answerAdjustment('x', 'abc');
      await db.service.acknowledgeAdjustment('x');
      await db.service.settleAdjustment('x', amountCents: 1, paidOn: DateTime(2026, 1, 1), reference: 'abc');
      await db.service.waiveAdjustment('x', 'abc');
      expect(db.calls.length, 9);
      for (final c in db.calls) {
        final signature = signatureOf(c.$1);
        for (final arg in c.$2!.keys) {
          expect(signature, contains(arg), reason: '${c.$1} is sent $arg');
        }
      }
    });

    test('the two lists\' columns, and every key of the payload the app reads, are ones the migration writes', () {
      final columns = RegExp(r'returns table \(([^)]*)\)', dotAll: true).allMatches(text).map((m) => m.group(1)!).toList();
      expect(columns, hasLength(2));
      for (final c in columns) {
        for (final k in flagRow().keys) {
          expect(c, contains(k), reason: 'list column $k');
        }
      }
      const payloadKeys = [
        'agreement_id', 'settlement_id', 'side', 'applies', 'currency', 'paid_amount_cents', 'paid_on', 'count', 'adjustments_cents', 'net_cents', 'open_to_organizer_cents', 'open_to_club_cents', 'items', 'log', 'can',
        // an adjustment
        'id', 'kind', 'amount_cents', 'direction', 'reason', 'source_ref', 'status', 'recorded_at', 'recorded_by_name', 'disputed_reason', 'disputed_at', 'organizer_ack_at', 'organizer_ack_by_name',
        'resolved_amount_cents', 'resolved_on', 'resolution_reference', 'resolution_note', 'resolved_at', 'resolved_by_name', 'resolution_label',
        // what the person can do
        'record', 'acknowledge', 'question', 'answer', 'settle', 'waive',
        // the history
        'adjustment_id', 'at', 'action', 'from_status', 'to_status', 'note', 'by_name', 'by_me',
      ];
      for (final k in payloadKeys) {
        expect(text, contains("'$k'"), reason: 'payload key $k');
      }
    });

    test('the fake gives exactly the keys the migration\'s payload has, so it cannot drift from what the app reads', () {
      final payload = adjustmentsPayload(items: [adjustmentJson()], log: [adjustmentLogJson('recorded')], canRecord: true);
      final item = adjustmentJson();
      for (final k in [...payload.keys, ...(payload['can'] as Map).keys, ...item.keys, ...(item['can'] as Map).keys, ...adjustmentLogJson('recorded').keys]) {
        expect(text, contains("'$k'"), reason: 'key $k');
      }
    });

    test('the kinds, the statuses and the history actions the app words are the ones the database writes', () {
      for (final k in adjustmentKinds) {
        expect(text, contains("'$k'"), reason: k);
        expect(adjustmentKindLabel(k), isNot('Adjustment'), reason: k);
        expect(adjustmentKindHint(k), isNotEmpty, reason: k);
      }
      expect(RegExp(r"kind text not null check \(kind in \(([^)]*)\)").firstMatch(text)!.group(1)!.split(',').map((s) => s.trim().replaceAll("'", '')).toList(), adjustmentKinds);
      for (final s in ['open', 'disputed', 'settled', 'waived']) {
        expect(text, contains("'$s'"), reason: s);
        expect(adjustmentStatusInfo(s).label, isNot('Unknown'), reason: s);
      }
      for (final a in ['recorded', 'acknowledged', 'questioned', 'answered', 'settled', 'waived']) {
        expect(text, contains("'$a'"), reason: a);
        final line = adjustmentLogLine(parseSettlementAdjustments(adjustmentsPayload(log: [adjustmentLogJson(a)]))!.log.single);
        expect(line, isNot(startsWith('$a ')), reason: 'the app has words for $a');
      }
      for (final d in ['organizer_owes_club', 'club_owes_organizer']) {
        expect(text, contains("'$d'"), reason: d);
      }
      for (final label in ['Recorded external payment', 'Not recovered']) {
        expect(text, contains("'$label'"), reason: label);
      }
    });

    test('the limits the app checks are the limits the database has', () {
      expect(text, contains('char_length(v_reason) < 3 or char_length(v_reason) > 300 then raise exception \'say why (3 to 300'));
      expect(text, contains('char_length(v_ref) < 3 or char_length(v_ref) > 120'));
      expect(text, contains('char_length(v_evidence) > 300'));
      expect(text, contains('char_length(v_reason) < 5 or char_length(v_reason) > 500'));
      expect(text, contains('char_length(v_note) < 3 or char_length(v_note) > 500'));
      expect(text, contains('char_length(v_reason) < 3 or char_length(v_reason) > 300 then raise exception \'say why it is not being recovered'));
      expect(text, contains('if v_count >= 50 then'));
      expect(text, contains("if p_kind in ('refund', 'chargeback') and p_amount_cents > 0 then"));
      expect(text, contains('s.paid_amount_cents + v_total + p_amount_cents < 0'));
      expect(text, contains('abs(p_amount_cents) > 100000000000'));
    });

    test('a refund and a chargeback are a minus and only a correction may add: the app\'s form and the database\'s sign rule say the same', () {
      expect(text, contains("check (kind = 'correction' or amount_cents < 0)"));
      expect(checkAdjustmentRecordForm(kind: 'refund', amount: '5', reason: 'abc', reference: '', netCents: 10000).cents, lessThan(0));
      expect(checkAdjustmentRecordForm(kind: 'chargeback', amount: '5', reason: 'abc', reference: '', netCents: 10000).cents, lessThan(0));
      expect(checkAdjustmentRecordForm(kind: 'correction', amount: '+5', reason: 'abc', reference: '', netCents: 10000).cents, greaterThan(0));
    });

    test('the amount owed to the organizer cannot be waived: the app offers it only when the database says so, and the database refuses it', () {
      expect(text, contains("'waive', v_owner and x.status = 'open' and x.amount_cents < 0"));
      expect(text, contains('an amount owed to the organizer cannot be waived'));
    });
  }, skip: sql.existsSync() ? false : skip);
}
