import 'package:bottles_up_vendor/features/night/logic/night_rules.dart';
import 'package:bottles_up_vendor/features/sales_source/logic/sales_source_rules.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sales_backend.dart';

ClosingReportForm good({String night = '2026-10-31'}) => ClosingReportForm(night: night, grossText: '800.00', discountText: '50', includesBottlesUp: false);

NightSales sales({bool upload = true, bool includes = true, int gross = 90000, int discount = 5000, int refund = 1000, String status = 'reviewed', bool noReport = false}) {
  final db = FakeSalesBackend(role: 'owner')..source = upload ? 'upload' : 'entries';
  if (!noReport) db.seed(night: '2026-10-31', status: status, gross: gross, discount: discount, refund: refund, includes: includes);
  final r = db.reports.isEmpty ? null : db.reports.last;
  final net = db.recorded['net_cents'] as int;
  return parseNightSales({
    'business_night': '2026-10-31',
    'source': upload ? 'upload' : 'entries',
    'source_label': upload ? 'Closing report upload' : 'BottlesUp entries',
    'recorded': db.recorded,
    'venue_reported': r == null
        ? null
        : {
            'label': 'Venue-reported sales',
            'basis': 'The club\'s own end-of-night report. It is not live bar sales.',
            'version': 1,
            'status': r['status'],
            'period_start': r['period_start'],
            'period_end': r['period_end'],
            'gross_cents': gross,
            'discount_cents': discount,
            'refund_cents': refund,
            'net_cents': gross - discount - refund,
            'includes_bottlesup': includes,
            'bar_and_other_cents': includes ? (gross - discount - refund - net < 0 ? 0 : gross - discount - refund - net) : gross - discount - refund,
            'smaller_than_recorded': includes && gross - discount - refund < net,
            'submitted_at': r['submitted_at'],
            'reviewed_at': r['reviewed_at'],
            'verification': status == 'reviewed' ? 'Checked' : (status == 'rejected' ? 'Not accepted' : 'Waiting to be checked'),
          },
  })!;
}

void main() {
  group('the source', () {
    test('two choices, worded for the screen', () {
      expect(SalesSource.values.map((s) => s.wire), ['entries', 'upload']);
      expect(SalesSource.entries.label, 'BottlesUp entries');
      expect(SalesSource.upload.label, 'Closing report upload');
      expect(parseSalesSource('upload'), SalesSource.upload);
      expect(parseSalesSource('pos'), isNull, reason: 'Connected POS is not a value');
      expect(parseSalesSource(null), isNull);
    });

    test('Connected POS is said to be unavailable, never offered', () {
      expect(posLabel, 'Connected POS');
      expect(posUnavailableText, startsWith('Not available yet'));
    });

    test('who chooses, sends and checks', () {
      for (final role in WorkspaceRole.values) {
        expect(canChooseSource(role), role == WorkspaceRole.owner || role == WorkspaceRole.manager, reason: role.name);
        expect(canSendClosingReport(role), role == WorkspaceRole.owner || role == WorkspaceRole.manager, reason: role.name);
        expect(canCheckClosingReport(role), role == WorkspaceRole.owner || role == WorkspaceRole.verifier, reason: role.name);
      }
    });
  });

  group('a closing report row', () {
    Map<String, dynamic> row() => {
          'id': 'r1',
          'business_night': '2026-10-31',
          'version': 2,
          'status': 'submitted',
          'period_start': '2026-10-31T20:00:00Z',
          'period_end': '2026-11-01T04:00:00Z',
          'gross_cents': 80000,
          'discount_cents': 5000,
          'refund_cents': 0,
          'net_cents': 75000,
          'includes_bottlesup': true,
          'note': 'Bar till',
          'submitted_at': '2026-11-01T01:00:00Z',
          'reviewed_at': null,
          'review_note': null,
          'mine': true,
          'can_review': false,
        };

    test('is read in full', () {
      final r = parseClosingReport(row())!;
      expect((r.id, r.night, r.version, r.status), ('r1', '2026-10-31', 2, ClosingReportStatus.submitted));
      expect((r.grossCents, r.discountCents, r.refundCents, r.netCents), (80000, 5000, 0, 75000));
      expect((r.includesBottlesUp, r.note, r.mine, r.canReview), (true, 'Bar till', true, false));
    });

    test('a row that cannot be used is dropped, not guessed', () {
      expect(parseClosingReport({...row(), 'id': null}), isNull);
      expect(parseClosingReport({...row(), 'status': 'weird'}), isNull);
      expect(parseClosingReport({...row(), 'gross_cents': null}), isNull);
      expect(parseClosingReport({...row(), 'period_start': 'x'}), isNull);
    });

    test('the four states have their words', () {
      expect(ClosingReportStatus.values.map((s) => s.label), ['Waiting to be checked', 'Checked', 'Not accepted', 'Replaced by a newer report']);
    });

    test('the summary line says the night, the version, the net and the state', () {
      expect(reportSummaryLine(parseClosingReport(row())!), 'Sat Oct 31 · version 2 · \$750.00 net · Waiting to be checked');
    });
  });

  group('sending: what is checked before the database checks it again', () {
    final now = DateTime(2026, 11, 1, 12);
    test('a good one has no problem', () => expect(good().problem(now: now), isNull));

    test('each part has its own sentence', () {
      expect(good(night: 'x').problem(now: now), 'Which night is the report for?');
      expect(good(night: '2026-11-04').problem(now: now), 'That night has not happened yet.');
      expect(good().copy(endMinutes: 20 * 60).problem(now: now), 'The period must end after it starts.');
      expect(good().copy(grossText: '').problem(now: now), 'Enter the gross sales for the period.');
      expect(good().copy(grossText: 'abc').problem(now: now), 'Enter the gross sales as an amount like 1250.00.');
      expect(good().copy(grossText: '-5').problem(now: now), 'Enter the gross sales as an amount like 1250.00.');
      expect(good().copy(discountText: 'x').problem(now: now), 'Enter the discounts as an amount like 50.00, or leave them empty.');
      expect(good().copy(refundText: '1.234').problem(now: now), 'Enter the refunds as an amount like 50.00, or leave them empty.');
      expect(good().copy(discountText: '500', refundText: '300.01').problem(now: now), 'Discounts and refunds cannot be more than the gross sales.');
      expect(good().copy(includesBottlesUp: null).problem(now: now), 'Say whether these figures include what BottlesUp recorded.');
      expect(good().copy(note: 'x' * 301).problem(now: now), 'The note is at most 300 characters.');
    });

    test('equal discounts and refunds are fine, and so is a note of exactly 300', () {
      expect(good().copy(discountText: '500', refundText: '300').problem(now: now), isNull);
      expect(good().copy(note: 'x' * 300).problem(now: now), isNull);
    });

    test('tomorrow is allowed (a night that has just started), the day after is not', () {
      expect(good(night: '2026-11-02').problem(now: now), isNull);
      expect(good(night: '2026-11-03').problem(now: now), 'That night has not happened yet.');
    });

    test('an empty discount or refund is nothing', () {
      final f = good().copy(discountText: '', refundText: '');
      expect((f.discountCents, f.refundCents), (0, 0));
      expect(f.copy(includesBottlesUp: true).includesBottlesUp, isTrue);
      expect(f.copy(grossText: '1').includesBottlesUp, isFalse, reason: 'copy keeps what was said when only another part changes');
    });

    test('the period runs into the next morning when it ends earlier than it starts', () {
      final p = good().period()!;
      expect(p.$1, DateTime(2026, 10, 31, 20));
      expect(p.$2, DateTime(2026, 11, 1, 4));
      final same = good().copy(startMinutes: 18 * 60, endMinutes: 23 * 60).period()!;
      expect(same.$2, DateTime(2026, 10, 31, 23));
    });

    test('the call carries exactly what the database asks for, and nothing else', () {
      final p = good().copy(note: '  Bar till  ').params('v1');
      expect(p.keys.toSet(), {'p_venue', 'p_night', 'p_period_start', 'p_period_end', 'p_gross_cents', 'p_discount_cents', 'p_refund_cents', 'p_includes_bottlesup', 'p_note'});
      expect(p['p_venue'], 'v1');
      expect(p['p_night'], '2026-10-31');
      expect((p['p_gross_cents'], p['p_discount_cents'], p['p_refund_cents'], p['p_includes_bottlesup'], p['p_note']), (80000, 5000, 0, false, 'Bar till'));
      expect(DateTime.parse(p['p_period_start'] as String).isUtc, isTrue);
      expect(good().params('v1')['p_note'], isNull);
    });
  });

  group('a night\'s sales: two labelled blocks', () {
    test('the recorded block says what it is and when it was worked out', () {
      final lines = recordedLines(sales().recorded);
      expect(lines.map((l) => l.label), ['Booked, before discounts', 'Discounts', 'Refunds paid out', 'Net of refunds', 'Collected', 'Not yet collected', 'Worked out']);
      expect(lines.map((l) => l.value).take(6), ['\$630.00', '\$30.00', '\$50.00', '\$550.00', '\$420.00', '\$200.00']);
      expect(lines[3].strong, isTrue);
    });

    test('the reported block says the period, the figures, whether it includes BottlesUp\'s and the bar part, and who checked', () {
      final lines = reportedLines(sales().reported!);
      expect(lines.map((l) => l.label), ['Period', 'Gross', 'Discounts', 'Refunds', 'Net', 'Includes what BottlesUp recorded', 'Bar and other, without BottlesUp\'s', 'Sent', 'Checked']);
      final byLabel = {for (final l in lines) l.label: l.value};
      expect(byLabel['Gross'], '\$900.00');
      expect(byLabel['Net'], '\$840.00');
      expect(byLabel['Includes what BottlesUp recorded'], 'Yes');
      expect(byLabel['Bar and other, without BottlesUp\'s'], '\$290.00', reason: '840 less BottlesUp\'s 550');
      expect(byLabel['Checked'], startsWith('Checked, '));
    });

    test('a report that does not include BottlesUp\'s has no bar line to explain', () {
      final lines = reportedLines(sales(includes: false).reported!);
      expect(lines.map((l) => l.label), isNot(contains('Bar and other, without BottlesUp\'s')));
      expect({for (final l in lines) l.label: l.value}['Includes what BottlesUp recorded'], 'No');
    });

    test('a report that waits says so, and a refused one says it was not accepted', () {
      expect({for (final l in reportedLines(sales(status: 'submitted').reported!)) l.label: l.value}['Checked'], 'Waiting to be checked');
      expect({for (final l in reportedLines(sales(status: 'rejected').reported!)) l.label: l.value}['Checked'], startsWith('Not accepted'));
    });

    test('the sections are the recorded block and, when there is one, the club\'s report; never a total', () {
      expect(salesSections(sales()).map((s) => s.$1), ['Recorded sales', 'Venue-reported sales']);
      expect(salesSections(sales(noReport: true)).map((s) => s.$1), ['Recorded sales']);
      expect(salesSections(sales()).expand((s) => s.$3).map((l) => l.label), isNot(contains('Total')));
    });

    test('a night that cannot be read is dropped, not guessed', () {
      expect(parseNightSales({'business_night': '2026-10-31', 'source': 'pos', 'recorded': <String, dynamic>{}}), isNull);
      expect(parseNightSales({'business_night': '2026-10-31', 'source': 'entries'}), isNull);
    });
  });

  group('the report with the sales added', () {
    ReportDocument base() => const ReportDocument(title: 'Club A', subtitle: 'Fri Oct 30', statusLine: 'PRELIMINARY', sections: [ReportSection('Sales', [ReportRow('Booked total', '\$1.00')])], fileName: 'a.pdf');

    test('without the sales the report is exactly what it was', () => expect(documentWithSales(base(), null).sections.length, 1));

    test('the sales come after everything else, labelled, with a note on how to read them', () {
      final d = documentWithSales(base(), sales());
      expect(d.sections.map((s) => s.title), ['Sales', 'Recorded sales', 'Venue-reported sales', 'Reading the sales']);
      expect((d.title, d.subtitle, d.statusLine, d.fileName), ('Club A', 'Fri Oct 30', 'PRELIMINARY', 'a.pdf'));
      expect(d.sections[1].rows.first.label, 'What this is');
      expect(d.sections.last.rows.map((r) => r.value), contains(sourcesFooter));
    });

    test('a report smaller than what BottlesUp recorded says to check it', () {
      final d = documentWithSales(base(), sales(gross: 30000, discount: 0, refund: 0));
      expect(d.sections[2].rows.map((r) => r.label), contains('Check this report'));
      expect(documentWithSales(base(), sales()).sections[2].rows.map((r) => r.label), isNot(contains('Check this report')));
    });

    test('a club on upload that has sent nothing for the night says so, as the club\'s own block', () {
      final d = documentWithSales(base(), sales(noReport: true));
      expect(d.sections.map((s) => s.title), ['Sales', 'Recorded sales', 'Venue-reported sales', 'Reading the sales']);
      expect(d.sections[2].rows.single.value, noReportYetText);
    });

    test('a club on entries has no venue-reported block at all', () {
      final d = documentWithSales(base(), sales(upload: false, noReport: true));
      expect(d.sections.map((s) => s.title), ['Sales', 'Recorded sales', 'Reading the sales']);
      expect(d.sections.last.rows.first.value, 'BottlesUp entries');
    });
  });
}
