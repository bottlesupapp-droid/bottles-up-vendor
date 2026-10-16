import 'dart:convert';

import 'package:bottles_up_vendor/features/night/logic/night_rules.dart';
import 'package:bottles_up_vendor/features/night/logic/report_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_night_backend.dart';

NightReport report({String view = 'full', bool isFinal = false, Map<String, dynamic>? data, List<Map<String, dynamic>> exceptions = const [], String? note}) {
  final d = data ?? sampleFullReport();
  final json = <String, dynamic>{
    'view': view,
    'final': isFinal,
    'venue_name': d['venue_name'],
    'business_night': d['business_night'],
    'generated_at': d['generated_at'],
    if (isFinal) 'closed_at': '2026-10-10T02:15:00Z',
    if (isFinal) 'closed_by_name': 'Mia Manager',
    if (isFinal && view != 'security') 'exceptions': exceptions,
    if (isFinal && view != 'security') 'exceptions_note': note,
    if (view != 'security') ...{for (final k in ['bookings', 'payments', 'cash', 'flags']) k: d[k]},
    if (view == 'full') ...{'bottles': d['bottles'], 'service': d['service']},
    if (view != 'finance') 'security': d['security'],
  };
  return parseNightReport(json)!;
}

String text(ReportDocument d) => [for (final s in d.sections) '${s.title}\n${[for (final r in s.rows) '${r.label}: ${r.value}'].join('\n')}'].join('\n\n');

void main() {
  group('reading what the database sends', () {
    test('the state of a night and what is open', () {
      final s = parseCloseStatus({
        'status': 'open',
        'closed': false,
        'blockers': [
          {'key': 'payments_to_check', 'label': 'payments waiting to be checked', 'count': 3},
        ],
        'close_items_open': ['Closing stock counted'],
      })!;
      expect(s.closed, isFalse);
      expect(s.blockers.single.sentence, '3 payments waiting to be checked');
      expect(s.wouldBeExceptions.map((e) => e.sentence), ['3 payments waiting to be checked', 'Not ticked: Closing stock counted']);
    });

    test('a closed night keeps its exceptions and the reason', () {
      final s = parseCloseStatus({
        'status': 'closed',
        'closed': true,
        'closed_by_name': 'Mia',
        'exceptions': [
          {'key': 'tasks_open', 'label': 'security tasks not done', 'count': 1},
          {'key': 'Closing stock counted', 'label': 'Closing stock counted', 'count': 1, 'kind': 'checklist'},
        ],
        'exceptions_note': 'Owner agreed',
        'blockers': [],
        'close_items_open': [],
      })!;
      expect(s.closed, isTrue);
      expect(s.exceptions.last.isChecklist, isTrue);
      expect(s.exceptionsNote, 'Owner agreed');
    });

    test('odd rows are dropped, not shown', () {
      expect(parseChecklistItem({'label': 'x'}), isNull);
      expect(parseNightReport({'view': 'full'}), isNull);
      final s = parseCloseStatus({'blockers': 'nonsense', 'exceptions': [1, null, {'label': 'no key'}]})!;
      expect(s.blockers, isEmpty);
      expect(s.exceptions, isEmpty);
    });
  });

  test('what a person typed', () {
    expect(checkCloseNote('too short'), 'Say why you are closing with these still open (at least 10 characters).');
    expect(checkCloseNote('Owner agreed to chase it'), isNull);
    expect(checkCloseNote('x' * 501), 'Keep the note to 500 characters or fewer.');
    expect(checkReopenReason('oops'), 'Say why this night is being reopened (at least 10 characters).');
    expect(checkReopenReason('We forgot to count the float'), isNull);
  });

  group('the report, in words', () {
    test('the manager\'s preliminary report has every section and says it is not final', () {
      final doc = buildReportDocument(report());
      expect(doc.title, 'Nightly report');
      expect(doc.subtitle, 'Club A · Friday Oct 9');
      expect(doc.statusLine, startsWith('PRELIMINARY · figures as of '));
      expect(doc.statusLine, endsWith('not final until the night is closed'));
      expect(doc.sections.map((s) => s.title), ['Tables and guests', 'Sales', 'Payments recorded at the club', 'Cash', 'Flagged payments', 'Bottle orders', 'Requests from tables', 'Security']);
      expect(doc.fileName, 'club-a-2026-10-09-full-preliminary.pdf');
    });

    test('money is in dollars and counts are plain', () {
      final t = text(buildReportDocument(report()));
      expect(t, contains('Booked total: \$160.00'));
      expect(t, contains('Balance still due: \$22.00'));
      expect(t, contains('Collected: \$138.00'));
      expect(t, contains('Cash: \$95.00'));
      expect(t, contains('Shortages: \$1.00'));
      expect(t, contains('Still held by staff: \$15.00'));
      expect(t, contains('Tables booked: 2'));
      expect(t, contains('Corrections (each counted once): 1'));
      expect(t, contains('Resolved as confirmed ok: 1'));
      expect(t, contains('Terrace'));
      expect(t, contains('Fight: 1'));
    });

    test('the verifier\'s report has the money and nothing about security, bottles or requests', () {
      final doc = buildReportDocument(report(view: 'finance'));
      expect(doc.title, 'Finance report');
      expect(doc.sections.map((s) => s.title), ['Tables and guests', 'Sales', 'Payments recorded at the club', 'Cash', 'Flagged payments']);
      expect(text(doc), isNot(contains('Security')));
      expect(doc.fileName, contains('-finance-'));
    });

    test('security\'s report has the security section and no money at all', () {
      final doc = buildReportDocument(report(view: 'security'));
      expect(doc.title, 'Security report');
      expect(doc.sections.map((s) => s.title), ['Security']);
      expect(text(doc), isNot(contains('\$')));
    });

    test('a final report says who closed it and lists what was excused, with the reason', () {
      final doc = buildReportDocument(report(
        isFinal: true,
        exceptions: [
          {'key': 'tasks_open', 'label': 'security tasks not done', 'count': 1},
          {'key': 'x', 'label': 'Closing stock counted', 'count': 1, 'kind': 'checklist'},
        ],
        note: 'Owner agreed to chase the rest',
      ));
      expect(doc.statusLine, contains('FINAL · closed'));
      expect(doc.statusLine, endsWith('by Mia Manager'));
      expect(doc.sections.last.title, 'Closed with exceptions');
      final t = text(doc);
      expect(t, contains('security tasks not done: 1'));
      expect(t, contains('Not ticked: Closing stock counted'));
      expect(t, contains('Reason given: Owner agreed to chase the rest'));
      expect(doc.fileName, endsWith('-final.pdf'));
    });

    test('a final report with nothing excused has no exceptions section', () {
      expect(buildReportDocument(report(isFinal: true)).sections.map((s) => s.title), isNot(contains('Closed with exceptions')));
    });
  });

  group('the PDF', () {
    test('is a real PDF holding the same words as the screen', () async {
      final doc = buildReportDocument(report(isFinal: true, exceptions: [
        {'key': 'tasks_open', 'label': 'security tasks not done', 'count': 1},
      ], note: 'Owner agreed to chase it'));
      final bytes = await buildReportPdf(doc, compress: false);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final body = latin1.decode(bytes, allowInvalid: true);
      // The PDF writer sets text a word at a time, so each word is looked for on its own.
      for (final needle in ['Nightly', 'report', 'Club', 'FINAL', 'Booked', r'$160.00', 'exceptions', 'security', 'tasks', 'Owner', 'agreed', 'chase']) {
        expect(body, contains(needle), reason: needle);
      }
    });

    test('a long report runs over to more pages without losing rows', () async {
      final data = sampleFullReport();
      (data['security'] as Map)['incidents'] = [for (var i = 0; i < 120; i++) {'kind': 'other', 'location': 'Bar$i', 'status': 'reviewed'}];
      final doc = buildReportDocument(report(data: data));
      final body = latin1.decode(await buildReportPdf(doc, compress: false), allowInvalid: true);
      expect(body, contains('(Bar0)'));
      expect(body, contains('(Bar119)'));
      expect(RegExp(r'/Type/Page\b').allMatches(body).length, greaterThan(1));
    });

    test('characters a PDF font cannot hold are swapped, never crash', () async {
      expect(pdfSafe('Café · Zürich – “quoted” …'), 'Café - Zürich - "quoted" ...');
      expect(pdfSafe('مرحبا'), '?????');
      final data = sampleFullReport();
      data['venue_name'] = 'Club مرحبا';
      final bytes = await buildReportPdf(buildReportDocument(report(data: data)));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
