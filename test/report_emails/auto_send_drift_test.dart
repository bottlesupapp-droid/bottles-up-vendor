import 'dart:io';

import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_report_email_backend.dart';

// The app and the database must agree on names. This reads the website repo's migration when it is checked out next to this app (the monorepo); on its own it is skipped.
void main() {
  final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
  final sql = File('$website/supabase/migrations/20261126100000_auto_report_jobs.sql');
  const skip = 'website repo is not checked out next to this app (or does not have the automatic report migration)';

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

    test('the two functions the app calls are defined, and every argument it sends is one they take', () async {
      final mail = FakeReportEmailBackend();
      const scope = ReportListScope(kind: ReportKind.venueNight, orgId: 'o', venueId: 'v');
      await mail.service.autoStatus(scope);
      await mail.service.setAuto(scope, true);
      final sent = {
        'report_auto_status': ['p_kind', 'p_org', 'p_venue'],
        'report_auto_set': ['p_kind', 'p_org', 'p_venue', 'p_enabled'],
      };
      for (final entry in sent.entries) {
        final params = mail.calledWith(entry.key).single;
        expect(params.keys.toSet(), entry.value.toSet(), reason: 'the app sends exactly these to ${entry.key}');
        final signature = signatureOf(entry.key);
        for (final arg in entry.value) {
          expect(signature, contains(arg), reason: '${entry.key} takes $arg');
        }
      }
    });

    test('every column of the status the app reads is one the function returns, and the fake gives exactly those', () async {
      final returns = RegExp(r'create function public\.report_auto_status\([^)]*\)\s*returns table \(([^)]*)\)', dotAll: true).firstMatch(text)!.group(1)!;
      final mail = FakeReportEmailBackend();
      final row = (await mail.call('report_auto_status', params: {'p_kind': 'owner_combined', 'p_org': 'o', 'p_venue': null}) as List).single as Map;
      for (final k in row.keys) {
        expect(returns, contains(k as String), reason: 'column $k');
      }
      expect(row.keys.length, 9);
    });

    test('the kinds are the ones the database allows, and the job states the app words are the ones it writes', () {
      for (final k in ReportKind.values) {
        expect(text, contains("'${k.value}'"), reason: k.value);
      }
      for (final s in ['pending', 'running', 'sent', 'failed', 'skipped']) {
        expect(text, contains("'$s'"), reason: s);
        final line = autoLastLine(parseReportAutoStatus({'enabled': true, 'last_status': s, 'last_ref': '2026-11-14'})!, ReportKind.venueNight)!;
        // "sent" and "skipped" are words in themselves; the others have words of their own, not just the state's name
        if (s != 'sent' && s != 'skipped') expect(line, isNot(endsWith(': $s')), reason: 'the app has words for $s');
      }
    });

    test('the sentences the app shows under the switch are the ones the server job writes', () {
      final job = File('$website/supabase/functions/_shared/reportJob.ts');
      if (!job.existsSync()) return;
      final ts = job.readAsStringSync();
      for (final s in ['The person who switched it on no longer has access. Switch it on again.', 'No one is set to receive it. Add an e-mail address first.']) {
        expect(ts, contains(s), reason: s);
      }
    });

    test('who may switch it on is who may e-mail the report: the same function decides', () {
      expect(text, contains('report_scope_allowed(p_kind, p_org, p_venue, null)'));
      expect(text, contains("'owner_combined'"));
    });
  }, skip: sql.existsSync() ? false : skip);
}
