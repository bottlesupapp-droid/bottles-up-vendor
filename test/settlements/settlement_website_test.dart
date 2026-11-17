import 'dart:io';

import 'package:bottles_up_vendor/features/settlements/logic/settlement_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settlement_backend.dart';

// The app and the database must agree on names. This reads the website repo's migration when it is checked out next to this app (the monorepo); on its own it is skipped.
void main() {
  final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
  final sql = File('$website/supabase/migrations/20261122120000_organizer_settlements.sql');
  const skip = 'website repo is not checked out next to this app';

  group('agrees with the website', () {
    late String text;
    setUpAll(() {
      if (sql.existsSync()) text = sql.readAsStringSync();
    });

    test('every function the service calls is defined, and every argument it sends is one the function takes', () {
      final calls = {
        'settlements_for_venue': ['p_venue'],
        'settlements_for_organizer': ['p_org'],
        'settlement_detail': ['p_agreement'],
        'settlement_save_sales': ['p_agreement', 'p_eligible_sales_cents', 'p_note'],
        'settlement_adjust': ['p_settlement', 'p_amount_cents', 'p_note'],
        'settlement_review': ['p_settlement'],
        'settlement_approve': ['p_settlement'],
        'settlement_record_payment': ['p_settlement', 'p_amount_cents', 'p_paid_on', 'p_reference', 'p_evidence'],
        'settlement_question': ['p_settlement', 'p_reason'],
        'settlement_resolve': ['p_settlement', 'p_note'],
        'settlement_acknowledge': ['p_settlement'],
      };
      for (final entry in calls.entries) {
        final start = text.indexOf('create function public.${entry.key}(');
        expect(start, greaterThanOrEqualTo(0), reason: entry.key);
        final signature = text.substring(start, text.indexOf('returns', start));
        for (final arg in entry.value) {
          expect(signature, contains(arg), reason: '${entry.key} takes $arg');
        }
      }
    });

    test('the service sends exactly the arguments listed above (nothing the function does not take)', () async {
      final db = FakeSettlementBackend();
      await db.service.forVenue('v');
      await db.service.forOrganizer('o');
      await db.service.detail('a');
      await db.service.saveSales('a', 1, 'abc');
      await db.service.adjust('s', 1, 'abc');
      await db.service.review('s');
      await db.service.approve('s');
      await db.service.recordPayment('s', amountCents: 1, paidOn: DateTime(2026, 1, 1), reference: 'abc');
      await db.service.question('s', 'abcde');
      await db.service.resolve('s', 'abc');
      await db.service.acknowledge('s');
      for (final c in db.calls) {
        final start = text.indexOf('create function public.${c.$1}(');
        final signature = text.substring(start, text.indexOf('returns', start));
        for (final arg in c.$2!.keys) {
          expect(signature, contains(arg), reason: '${c.$1} is sent $arg');
        }
      }
    });

    test('every column of the two lists, and every key of the detail, the app reads is one the migration writes', () {
      final listColumns = RegExp(r'returns table \(([^)]*)\)', dotAll: true).firstMatch(text)!.group(1)!;
      for (final k in listRow().keys) {
        expect(listColumns, contains(k), reason: 'list column $k');
      }
      const detailKeys = [
        'agreement_id', 'side', 'event_title', 'event_start', 'venue_name', 'organizer_name', 'agreement_status', 'agreement_version', 'terms', 'has_share', 'settlement', 'log', 'can',
        // the terms
        'bar_percent', 'threshold_cents', 'formula', 'eligible_revenue', 'refunds', 'taxes_tips_fees', 'settlement_timing',
        // the settlement
        'id', 'status', 'currency', 'eligible_sales_cents', 'sales_note', 'base_cents', 'share_cents', 'adjustment_cents', 'adjustment_note', 'payable_cents', 'entered_at', 'entered_by_name',
        'reviewed_at', 'reviewed_by_name', 'approved_at', 'approved_by_name', 'paid_amount_cents', 'paid_on', 'payment_reference', 'payment_evidence', 'paid_recorded_at', 'paid_recorded_by_name',
        'payment_label', 'disputed_reason', 'disputed_at', 'organizer_ack_at', 'organizer_ack_by_name',
        // the history
        'at', 'action', 'from_status', 'to_status', 'amount_cents', 'note', 'by_name', 'by_me',
        // what the person can do
        'save_sales', 'adjust', 'review', 'approve', 'record_payment', 'acknowledge', 'question', 'resolve',
      ];
      for (final k in detailKeys) {
        expect(text, contains("'$k'"), reason: 'detail key $k');
      }
    });

    test('the fake gives exactly the keys the migration\'s detail has, so it cannot drift from what the app reads', () {
      final fake = settlementJson();
      for (final k in fake.keys) {
        if (k == 'updated_at') continue;
        expect(text, contains("'$k'"), reason: 'settlement key $k');
      }
      final d = detail(log: [logJson('reviewed')]);
      for (final k in [...d.keys, ...(d['can'] as Map).keys, ...logJson('reviewed').keys, ...(d['terms'] as Map).keys]) {
        expect(text, contains("'$k'"), reason: 'key $k');
      }
    });

    test('the statuses and the history actions the app words are the ones the database writes', () {
      for (final s in ['estimated', 'reviewed', 'approved', 'paid', 'disputed']) {
        expect(text, contains("'$s'"), reason: s);
        expect(settlementStatusInfo(s).label, isNot('Unknown'), reason: s);
      }
      for (final a in ['sales_saved', 'adjusted', 'reviewed', 'approved', 'payment_recorded', 'questioned', 'resolved', 'acknowledged']) {
        expect(text, contains("'$a'"), reason: a);
        final line = logLine(parseSettlementDetail(detail(log: [logJson(a)]))!.log.single);
        expect(line, isNot(startsWith('$a ')), reason: 'the app has words for $a');
      }
    });

    test('the limits the app checks are the limits the database has', () {
      expect(text, contains('char_length(v_note) < 3 or char_length(v_note) > 300'));
      expect(text, contains('char_length(v_ref) < 3 or char_length(v_ref) > 120'));
      expect(text, contains('char_length(v_evidence) > 300'));
      expect(text, contains('char_length(v_reason) < 5 or char_length(v_reason) > 500'));
      expect(text, contains('char_length(v_note) < 3 or char_length(v_note) > 500'));
      expect(text, contains('p_eligible_sales_cents > 100000000000'));
    });
  }, skip: sql.existsSync() ? false : skip);
}
