import 'dart:io';

import 'package:bottles_up_vendor/features/night/logic/consolidated_report.dart';
import 'package:bottles_up_vendor/features/night/logic/night_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_night_backend.dart';

// The owner's combined report (website repo, 20261115100000_owner_night_report.sql): reading what the database sends, the words it is shown in, and the call.

ConsolidatedReport parsed([Map<String, dynamic>? raw]) => parseConsolidatedReport(raw ?? sampleConsolidated())!;

Map<String, String> rows(ReportDocument d, String section) => {
      for (final r in d.sections.firstWhere((s) => s.title == section, orElse: () => throw StateError('no section "$section" in ${d.sections.map((s) => s.title).toList()}')).rows) r.label: r.value,
    };

Map<String, dynamic> mixed() {
  final m = sampleConsolidated();
  m['currency'] = null;
  m['currency_mixed'] = true;
  m['currencies'] = ['cad', 'usd'];
  m['totals'] = null;
  (m['venues'] as List)[1]['currencies'] = ['cad', 'usd'];
  return m;
}

void main() {
  group('reading the answer', () {
    test('the clubs, how many are final, and the totals come through', () {
      final r = parsed();
      expect(r.orgName, 'Club Co');
      expect(r.night, '2026-10-09');
      expect(r.venues.map((c) => c.venueName), ['Club A', 'Club B']);
      expect(r.venues.map((c) => c.report.isFinal), [true, false]);
      expect(r.venuesTotal, 2);
      expect(r.venuesFinal, 1);
      expect(r.allFinal, isFalse);
      expect(r.currency, 'CAD');
      expect(r.totals!['booked_cents'], 21000);
      expect(r.totals!['card_cents'], 9300);
    });

    test('a club\'s own report is read as the nightly report is, with what was excused', () {
      final a = parsed().venues.first;
      expect(a.report.view, 'full');
      expect(a.report.closedByName, 'Mia Manager');
      expect(a.report.exceptions.single.sentence, '3 payments waiting to be checked');
      expect(a.report.sections['payments']!['collected_cents'], 13800);
    });

    test('every club final means the whole night is final', () {
      final m = sampleConsolidated();
      m['venues_final'] = 2;
      expect(parsed(m).allFinal, isTrue);
    });

    test('a business with no club has no totals to speak of and is not "final"', () {
      final m = sampleConsolidated();
      m['venues'] = [];
      m['venues_total'] = 0;
      m['venues_final'] = 0;
      expect(parsed(m).allFinal, isFalse);
    });

    test('an answer that cannot be trusted is refused, not shown with a club missing', () {
      expect(parseConsolidatedReport({...sampleConsolidated(), 'business_night': null}), isNull);
      expect(parseConsolidatedReport({...sampleConsolidated(), 'venues': 'none'}), isNull);
      final unreadable = sampleConsolidated();
      ((unreadable['venues'] as List)[1] as Map)['report'] = {'view': 'full'};
      expect(parseConsolidatedReport(unreadable), isNull, reason: 'a club whose report cannot be read would silently make the totals look wrong');
      final miscounted = sampleConsolidated();
      miscounted['venues_total'] = 3;
      expect(parseConsolidatedReport(miscounted), isNull);
      expect(parseConsolidatedReport({...sampleConsolidated(), 'totals': null}), isNull, reason: 'one currency but no totals');
    });

    test('with more than one currency there is no total, whatever else the answer holds', () {
      final m = mixed();
      m['totals'] = {'booked_cents': 999999};
      m['currency'] = 'CAD';
      final r = parsed(m);
      expect(r.currencyMixed, isTrue);
      expect(r.totals, isNull);
      expect(r.currency, isNull);
      expect(r.currencies, ['cad', 'usd']);
    });

    test('a club says which currencies it sold in', () {
      expect(parsed().venues.first.currencyLabel, 'CAD');
      expect(parsed(mixed()).venues.last.currencyLabel, 'mixed currencies');
      final none = sampleConsolidated();
      ((none['venues'] as List)[1] as Map)['currencies'] = [];
      expect(parsed(none).venues.last.currencyLabel, isNull);
    });
  });

  group('the words', () {
    test('title, subtitle and a status that says one club of two has closed', () {
      final d = buildConsolidatedDocument(parsed());
      expect(d.title, 'All venues');
      expect(d.subtitle, 'Club Co · Friday Oct 9');
      expect(d.statusLine, startsWith('PRELIMINARY · 1 of 2 clubs have closed the night'));
      expect(d.statusLine, endsWith('the totals are not final until every club has'));
    });

    test('when every club has closed it is FINAL', () {
      final m = sampleConsolidated();
      m['venues_final'] = 2;
      expect(buildConsolidatedDocument(parsed(m)).statusLine, 'FINAL · every club has closed the night');
    });

    test('no clubs says so', () {
      final m = sampleConsolidated();
      m['venues'] = [];
      m['venues_total'] = 0;
      m['venues_final'] = 0;
      expect(buildConsolidatedDocument(parsed(m)).statusLine, 'No venues in this business yet');
    });

    test('the totals carry the currency and are the figures the database added', () {
      final d = buildConsolidatedDocument(parsed());
      expect(rows(d, 'Tables and guests (CAD)'), {'Tables booked': '3', 'Guests': '6', 'Guests seated (tables)': '1'});
      expect(rows(d, 'Sales (CAD)'), {'Booked total': r'$210.00', 'Paid so far': r'$188.00', 'Balance still due': r'$22.00', 'Discounts': r'$0.00'});
      final collected = rows(d, 'Collected at the club (CAD)');
      expect(collected['Collected'], r'$188.00');
      expect(collected['Cash'], r'$95.00');
      expect(collected['Card (debit, credit and the card part of splits)'], r'$93.00');
      expect(collected['Cash shortages'], r'$1.00');
      expect(collected['Cash still held by staff'], r'$15.00');
      expect(rows(d, 'Bottle orders (CAD)'), {'Bottles ordered': '3', 'Value': r'$100.00', 'Served': '1'});
      expect(rows(d, 'Needing attention'), {
        'Payments not yet verified': '5',
        'Disputed by the guest': '1',
        'Without a receipt photo': '6',
        'Flagged payments still open': '1',
        'Requests from tables still open': '1',
        'Security alerts not resolved': '1',
        'Nights closed with exceptions': '1',
      });
    });

    test('side by side: one line per club with its state, then each club on its own', () {
      final d = buildConsolidatedDocument(parsed());
      expect(rows(d, 'By club'), {'Club A · FINAL': r'2 tables · $160.00', 'Club B · PRELIMINARY': r'1 table · $50.00'});
      final a = rows(d, 'Club A · FINAL · CAD');
      expect(a['Booked total'], r'$160.00');
      expect(a['Collected at the club'], r'$138.00');
      expect(a['Closed with exceptions'], '1');
      final b = rows(d, 'Club B · PRELIMINARY · CAD');
      expect(b['Tables booked'], '1');
      expect(b.containsKey('Closed with exceptions'), isFalse, reason: 'a club that has not closed has nothing excused');
    });

    test('more than one currency: no money total at all, and the clubs are marked', () {
      final d = buildConsolidatedDocument(parsed(mixed()));
      expect(rows(d, 'Totals not added'), {'Currencies sold in': 'CAD, USD', 'Combined total': 'Not shown', 'Why': 'Different currencies are never added together'});
      expect(d.sections.map((s) => s.title), isNot(contains('Sales (CAD)')));
      expect(d.sections.any((s) => s.title.startsWith('Sales')), isFalse);
      expect(d.sections.map((s) => s.title), contains('Club B · PRELIMINARY · mixed currencies'));
    });

    test('the file is named for the business, the night and whether it is final', () {
      expect(buildConsolidatedDocument(parsed()).fileName, 'club-co-all-venues-2026-10-09-preliminary.pdf');
      final m = sampleConsolidated();
      m['venues_final'] = 2;
      expect(buildConsolidatedDocument(parsed(m)).fileName, 'club-co-all-venues-2026-10-09-final.pdf');
      final odd = sampleConsolidated();
      odd['org_name'] = '***';
      expect(buildConsolidatedDocument(parsed(odd)).fileName, 'business-all-venues-2026-10-09-preliminary.pdf');
    });
  });

  group('the call', () {
    late FakeNightBackend db;
    setUp(() => db = FakeNightBackend(role: 'owner'));

    test('asks for the business and the night, by name', () async {
      final r = await db.service.consolidated('o1', '2026-10-09');
      expect(db.calledWith('owner_night_report').single, {'p_org': 'o1', 'p_night': '2026-10-09'});
      expect(r.venues, hasLength(2));
    });

    test('only the owner may; anyone else is told their access ended, with nothing to retry', () async {
      for (final role in ['manager', 'verifier', 'security', 'server']) {
        db.role = role;
        await expectLater(
          db.service.consolidated('o1', '2026-10-09'),
          throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue).having((e) => e.what, 'what', 'the combined report')),
          reason: role,
        );
      }
    });

    test('a backend without the function says it is not available yet; a dropped connection says to try again', () async {
      db.missing = true;
      await expectLater(db.service.consolidated('o1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
      db.missing = false;
      db.offline = true;
      await expectLater(db.service.consolidated('o1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    });

    test('an answer it cannot trust is a load failure, not a half report', () async {
      db.consolidated['venues_total'] = 5;
      await expectLater(db.service.consolidated('o1', '2026-10-09'), throwsA(isA<OpsLoadException>()));
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261115100000_owner_night_report.sql');
    const why = 'the owner night report migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('the function, its two parameters and who may call it', () async {
      final sql = migration.readAsStringSync();
      expect(sql, contains('create function public.owner_night_report(p_org uuid, p_night date)'));
      final db = FakeNightBackend(role: 'owner');
      await db.service.consolidated('o1', '2026-10-09');
      expect(db.calls.single.params!.keys.toList(), ['p_org', 'p_night']);
      expect(sql, contains("is_org_member(p_org, array['owner'])"));
      expect(sql, contains('grant execute on function public.owner_night_report(uuid, date) to authenticated'));
    }, skip: migration.existsSync() ? false : why);

    test('every total the app reads is one the database makes', () {
      final sql = migration.readAsStringSync();
      final keys = parsed().totals!.keys;
      for (final k in keys) {
        expect(sql, contains("'$k'"), reason: 'the database does not make the total "$k"');
      }
      // ...and the other way round: nothing the database makes is left unread.
      final made = RegExp(r"^\s+'(\w+)', coalesce\(sum", multiLine: true).allMatches(sql).map((m) => m.group(1)!).toSet();
      expect(made, keys.toSet());
    }, skip: migration.existsSync() ? false : why);

    test('the sentences and the wording of the mixed-currency rule are the database\'s', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains("raise exception 'not allowed'"));
      expect(sql, contains("raise exception 'choose a night'"));
      expect(sql, contains('coalesce(cardinality(v_currencies), 0) > 1'));
    }, skip: migration.existsSync() ? false : why);
  });
}
