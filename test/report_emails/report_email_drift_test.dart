import 'dart:io';

import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_report_email_backend.dart';

// The database and the e-mail function decide every name, limit and sentence here; the app must not drift from them. These read the website's files when they are checked out beside this app
// (the monorepo) and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261119100000_report_emails.sql');
  final logic = File('../bottles-up-website-main/supabase/functions/_shared/reportEmail.ts');
  final template = File('../bottles-up-website-main/supabase/functions/_shared/reportEmailTemplate.ts');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync() && logic.existsSync() && template.existsSync();

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
      return inside.isEmpty ? const [] : [for (final p in inside.split(',')) p.trim().split(RegExp(r'\s+')).first];
    }

    List<String> columns(String name) {
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(fn(name))!;
      return [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first];
    }

    test('every function the app calls exists, and the app sends exactly its parameters, by name', () async {
      final db = FakeReportEmailBackend(role: 'owner');
      const list = ReportListScope(kind: ReportKind.ownerCombined, orgId: 'o1');
      db.seed('owner_combined', 'o1', null, ['a@x.cc']);
      await db.service.recipients(list);
      await db.service.add(list, 'b@x.cc');
      final id = (await db.service.recipients(list)).last.id;
      await db.service.remove(id);
      await db.service.deliveries(const ReportTarget(kind: ReportKind.ownerCombined, orgId: 'o1', ref: '2026-10-30', fileName: 'n.pdf'));
      for (final function in ['report_recipients', 'add_report_recipient', 'remove_report_recipient', 'report_deliveries']) {
        final sent = db.calledWith(function).first.keys.toList()..sort();
        expect(sent, (params(function).toList()..sort()), reason: function);
      }
    }, skip: present ? false : why);

    test('the log is read from the columns the database returns', () {
      final cols = columns('report_deliveries');
      expect(cols, containsAll(['email', 'status', 'error', 'sent_at', 'created_at']));
      expect(columns('report_recipients'), containsAll(['id', 'email']));
    }, skip: present ? false : why);

    test('the request to the e-mail function carries exactly the fields it reads, and no address', () {
      final source = logic.readAsStringSync();
      final body = const ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-30', fileName: 'n.pdf').body(again: false);
      for (final key in [...body.keys, 'pdfBase64']) {
        expect(source, contains('b.$key'), reason: 'send-report-email reads "$key"');
      }
      expect(source, isNot(contains('b.to')));
      expect(source, isNot(contains('b.recipients')));
      expect(source, isNot(contains('b.email')));
    }, skip: present ? false : why);

    test('the three kinds of report are the database\'s and the function\'s', () {
      final values = [for (final k in ReportKind.values) k.value];
      for (final v in values) {
        expect(sql(), contains("'$v'"), reason: 'the migration knows $v');
        expect(template.readAsStringSync(), contains("'$v'"), reason: 'the e-mail function knows $v');
      }
      expect(values.length, 3);
    }, skip: present ? false : why);

    test('the limits are the same: ten addresses, 5 MB, a safe file name', () {
      expect(sql(), contains('>= $maxReportRecipients then'));
      expect(logic.readAsStringSync(), contains('MAX_PDF_BYTES = 5 * 1024 * 1024'));
      expect(sql(), contains('5242880'));
      expect(sql(), contains(r"'^[A-Za-z0-9 _.()-]{1,95}\.pdf$'"));
      // The sentence the app mirrors for a bad address and a full list.
      expect(sql(), contains('enter one e-mail address, like name@company.com'));
      expect(sql(), contains('a list can hold at most 10 addresses: remove one first'));
      expect(sql(), contains('that address is already on the list'));
    }, skip: present ? false : why);

    test('the sentences the app has for the function\'s refusals are the function\'s own', () {
      final source = logic.readAsStringSync();
      for (final sentence in [
        'You cannot e-mail this report.',
        'Too many reports were sent this hour. Try again later.',
        'No one is set to receive this report. Add an e-mail address first.',
        'There is nothing to send again: every address already got this report.',
        'That is not a PDF.',
      ]) {
        expect(source, contains(sentence));
      }
    }, skip: present ? false : why);
  });
}
