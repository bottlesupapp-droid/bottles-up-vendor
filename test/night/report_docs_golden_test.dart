import 'dart:convert';
import 'dart:io';

import 'package:bottles_up_vendor/features/night/logic/consolidated_report.dart';
import 'package:bottles_up_vendor/features/night/logic/night_rules.dart';
import 'package:bottles_up_vendor/features/sales_source/logic/sales_source_rules.dart';
import 'package:bottles_up_vendor/features/venue_access/logic/access_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// The server makes the same reports as the app, for the automatic e-mails (website supabase/functions/_shared/reportDocs.ts). The two must say the same thing, so the website keeps INPUTS (what the
// database returns) beside the DOCUMENT the app builds from each (tests/fixtures/report_docs/*.json), and both repositories' tests must produce exactly that document. This is the app's half.
//
// To change what a report says: change it in the app, run this with WRITE_REPORT_GOLDENS=1 (and TZ=UTC) to rewrite the expected documents, then change reportDocs.ts until the website's test passes.
// Fixtures whose name ends in _with_times are in UTC; where this machine's own time zone is not UTC (the phone's zone decides what the app shows) those are skipped here and run in CI.

Map<String, dynamic> documentJson(ReportDocument d) => {
  'title': d.title,
  'subtitle': d.subtitle,
  'statusLine': d.statusLine,
  'fileName': d.fileName,
  'sections': [
    for (final s in d.sections)
      {
        'title': s.title,
        'rows': [
          for (final r in s.rows) {'label': r.label, 'value': r.value, 'strong': r.strong},
        ],
      },
  ],
};

/// What the app builds for one fixture's input, or null when the app cannot read it (nothing would be shown).
Map<String, dynamic>? appDocument(String kind, Map<String, dynamic> input) {
  switch (kind) {
    case 'venue_night':
      final r = parseNightReport(Map<String, dynamic>.from(input['report'] as Map));
      if (r == null) return null;
      final sales = input['sales'] is Map ? parseNightSales(Map<String, dynamic>.from(input['sales'] as Map)) : null;
      return documentJson(documentWithSales(buildReportDocument(r), sales));
    case 'owner_combined':
      final r = parseConsolidatedReport(Map<String, dynamic>.from(input['report'] as Map));
      return r == null ? null : documentJson(buildConsolidatedDocument(r));
    case 'organizer_sales':
      final r = parseEventSales(Map<String, dynamic>.from(input['report'] as Map));
      return r == null ? null : documentJson(buildSalesDocument(r));
  }
  throw StateError('unknown kind $kind');
}

void main() {
  final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
  final dir = Directory('$website/tests/fixtures/report_docs');
  final write = Platform.environment['WRITE_REPORT_GOLDENS'] == '1';
  const skipNoRepo = 'website repo is not checked out next to this app';
  final utc = DateTime.parse('2026-11-15T03:12:00Z').toLocal().hour == 3 && DateTime.parse('2026-06-15T03:12:00Z').toLocal().hour == 3;

  if (!dir.existsSync()) {
    test('the documents the server makes are the documents the app makes', () {}, skip: skipNoRepo);
    return;
  }
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path));

  test('there are fixtures to compare', () => expect(files.length, greaterThanOrEqualTo(20)));

  for (final f in files) {
    final name = f.uri.pathSegments.last.replaceAll('.json', '');
    final timed = name.endsWith('_with_times');
    test('$name: the app builds exactly the expected document', () {
      final fixture = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final built = appDocument(fixture['kind'] as String, Map<String, dynamic>.from(fixture['input'] as Map));
      if (write) {
        fixture['expected'] = built;
        f.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(fixture)}\n');
        return;
      }
      expect(built, fixture['expected'], reason: 'the app says something different from the expected document in $name.json');
    }, skip: timed && !utc ? 'this machine\'s time zone is not UTC: run with TZ=UTC (CI does)' : false);
  }
}
