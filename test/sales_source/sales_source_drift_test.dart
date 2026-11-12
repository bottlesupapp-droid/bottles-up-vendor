import 'dart:io';

import 'package:bottles_up_vendor/features/sales_source/logic/sales_source_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sales_backend.dart';

// The database decides every name, label and sentence here; the app must not drift from it. These read the website's migration when it is checked out beside this app (the monorepo) and are skipped
// otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261121100000_sales_source.sql');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync();

  group('agrees with the website', () {
    String sql() => migration.readAsStringSync();

    String fn(String name) {
      final s = sql();
      final start = s.indexOf('create function public.$name(');
      expect(start, isNot(-1), reason: 'function $name is in the website\'s migration');
      return s.substring(start, s.indexOf('\n\$\$;', start));
    }

    List<String> params(String name) {
      final text = fn(name);
      final open = text.indexOf('(');
      var depth = 0;
      var close = open;
      for (var i = open; i < text.length; i++) {
        if (text[i] == '(') depth++;
        if (text[i] == ')') {
          depth--;
          if (depth == 0) {
            close = i;
            break;
          }
        }
      }
      final inside = text.substring(open + 1, close).trim();
      return inside.isEmpty ? const [] : [for (final p in inside.split(RegExp(r',\s*(?=p_)'))) p.trim().split(RegExp(r'\s+')).first];
    }

    test('every call the app makes uses the database\'s own parameter names, in its own words', () async {
      final db = FakeSalesBackend(role: 'owner')..source = 'upload';
      final s = db.service;
      await s.source('v1');
      await s.saveSource('v1', SalesSource.upload);
      await s.send('v1', ClosingReportForm(night: '2026-10-31', grossText: '10', includesBottlesUp: false));
      final id = db.reports.last['id'] as String;
      db.me = 'someone else';
      await s.review(id, accept: true);
      await s.reports('v1');
      await s.nightSales('v1', '2026-10-31');
      for (final f in ['venue_sales_source', 'save_venue_sales_source', 'submit_closing_report', 'review_closing_report', 'closing_reports', 'night_sales_sources']) {
        final sent = db.calledWith(f).first.keys.toList()..sort();
        final asked = params(f)..sort();
        expect(sent, asked, reason: '$f: the app sends what the function takes');
      }
    }, skip: present ? false : why);

    test('the list says what the app reads, column by column', () {
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(fn('closing_reports'))!;
      final columns = [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first]..sort();
      final db = FakeSalesBackend(role: 'owner')..source = 'upload';
      db.seed(by: 'x');
      expect(db.call('closing_reports', params: {'p_venue': 'v1', 'p_limit': 5}), completion(isA<List>()));
      expect(columns, containsAll(['id', 'business_night', 'version', 'status', 'period_start', 'period_end', 'gross_cents', 'discount_cents', 'refund_cents', 'net_cents', 'includes_bottlesup', 'note', 'submitted_at', 'reviewed_at', 'review_note', 'mine', 'can_review']));
      expect(columns.length, 17, reason: 'the app reads every column and the function returns nothing else');
    }, skip: present ? false : why);

    test('the night\'s sales have the keys the app reads, and the labels and sentences it shows', () {
      final text = fn('night_sales_sources');
      for (final k in ['business_night', 'source', 'source_label', 'recorded', 'venue_reported', 'label', 'basis', 'bookings', 'gross_cents', 'discount_cents', 'refund_cents', 'net_cents', 'collected_cents', 'unpaid_cents', 'as_of', 'version', 'status', 'period_start', 'period_end', 'includes_bottlesup', 'bar_and_other_cents', 'smaller_than_recorded', 'submitted_at', 'reviewed_at', 'verification']) {
        expect(text, contains("'$k'"), reason: 'the function returns $k');
      }
      final db = FakeSalesBackend();
      expect(text, contains("'${db.recorded['label']}'"));
      expect(text, contains("'${db.recorded['basis']}'"));
      expect(text, contains("'Venue-reported sales'"));
      expect(text, contains("The club''s own end-of-night report. It is not live bar sales."));
      for (final v in ['Checked', 'Not accepted', 'Waiting to be checked']) {
        expect(text, contains("'$v'"));
      }
      expect(text, contains("'Closing report upload'"));
      expect(text, contains("'BottlesUp entries'"));
    }, skip: present ? false : why);

    test('the database\'s refusals are the sentences the fake (and so the tests) rely on', () {
      final all = sql();
      for (final sentence in [
        'not allowed',
        'choose a sales source',
        'Connected POS is not available yet: no point-of-sale provider is connected',
        'the sales source is BottlesUp entries or a closing report upload',
        'this club does not use closing report uploads: change Sales Tracking first',
        'enter the gross sales for the period',
        'discounts and refunds cannot be negative',
        'discounts and refunds cannot be more than the gross sales',
        'say whether the figures include what BottlesUp recorded',
        'someone else must review a report you sent',
        'a newer report replaced this one',
        'accept the report or say why not',
        'say why the report is not accepted (at least 5 characters)',
      ]) {
        expect(all, contains(sentence), reason: sentence);
      }
    }, skip: present ? false : why);

    test('the sources, the report states and the limits are the app\'s', () {
      final all = sql();
      expect(all, contains("check (source in ('entries', 'upload'))"));
      for (final s in SalesSource.values) {
        expect(all, contains("'${s.wire}'"));
      }
      expect(all, contains("check (status in ('submitted', 'reviewed', 'rejected', 'superseded'))"));
      for (final s in ClosingReportStatus.values) {
        expect(all, contains("'${s.wire}'"));
      }
      expect(all, contains('char_length(note) <= 300'), reason: 'the app stops a note at 300');
      expect(all, contains('char_length(v_note) < 5'), reason: 'the app asks for at least 5 characters');
      expect(all, contains("interval '36 hours'"), reason: 'the form never makes a period over 24 hours, well within the 36');
      expect(all, contains("array['owner', 'verifier']"), reason: 'the owner and a verifier check; the app offers Accept to those');
      expect(all, contains('require_venue_editor'), reason: 'the owner and a manager choose and send: the same two the app offers');
      expect(all, contains("current_date + 1"), reason: 'the form allows tomorrow, like the database');
      expect(all, contains("current_date - 90"), reason: 'the form offers the last 90 days, like the database');
    }, skip: present ? false : why);
  });
}
