import 'dart:convert';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:bottles_up_vendor/features/report_emails/services/report_email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'fake_report_email_backend.dart';

// The calls behind e-mailing a report (website repo, 20261119100000_report_emails.sql and send-report-email).

Uint8List pdf([String head = '%PDF-1.4\n']) => Uint8List.fromList(utf8.encode('$head body'));

const listScope = ReportListScope(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1');
const target = ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-30', fileName: 'night-2026-10-30.pdf');

void main() {
  late FakeReportEmailBackend db;
  setUp(() => db = FakeReportEmailBackend(role: 'manager'));

  Future<void> expectRefusal(Future<Object?> f, String message) => expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  group('the lists', () {
    test('reads one list by kind, business and club', () async {
      db.seed('venue_night', 'o1', 'v1', ['boss@club.example', 'accountant@club.example']);
      db.seed('venue_night', 'o1', 'v2', ['other@club.example']);
      final people = await db.service.recipients(listScope);
      expect(people.map((p) => p.email), ['boss@club.example', 'accountant@club.example']);
      expect(db.calledWith('report_recipients').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1'});
    });

    test('adds an address, trimmed, with exactly the parameters the database has', () async {
      await db.service.add(listScope, '  Boss@Club.Example ');
      expect(db.calledWith('add_report_recipient').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_email': 'Boss@Club.Example'});
      expect((await db.service.recipients(listScope)).single.email, 'boss@club.example');
    });

    test('says why an address was refused, in the database\'s words', () async {
      await db.service.add(listScope, 'boss@club.example');
      await expectRefusal(db.service.add(listScope, 'boss@club.example'), 'That address is already on the list.');
      await expectRefusal(db.service.add(listScope, 'nope'), 'Enter one e-mail address, like name@company.com.');
      for (var i = 1; i < 10; i++) {
        await db.service.add(listScope, 'p$i@club.example');
      }
      await expectRefusal(db.service.add(listScope, 'eleventh@club.example'), 'A list can hold at most 10 addresses: remove one first.');
    });

    test('a person who may not keep the list is told so', () async {
      db.role = 'organizer';
      await expectRefusal(db.service.add(listScope, 'a@b.cc'), 'You don\'t have access to do that.');
      await expectLater(db.service.recipients(listScope), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'access ended', isTrue)));
    });

    test('removes an address by its id', () async {
      db.seed('venue_night', 'o1', 'v1', ['a@club.example', 'b@club.example']);
      final first = (await db.service.recipients(listScope)).first;
      await db.service.remove(first.id);
      expect(db.calledWith('remove_report_recipient').single, {'p_id': first.id});
      expect((await db.service.recipients(listScope)).map((p) => p.email), ['b@club.example']);
      await expectRefusal(db.service.remove('missing'), 'You don\'t have access to do that.');
    });

    test('a dropped connection is a plain sentence', () async {
      db.offline = true;
      await expectRefusal(db.service.add(listScope, 'a@b.cc'), 'That could not be saved. Check your connection and try again.');
      await expectRefusal(db.service.remove('r1'), 'That could not be saved. Check your connection and try again.');
      await expectLater(db.service.recipients(listScope), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    });

    test('where the server does not have it yet, the list says so rather than failing silently', () async {
      db.missing = true;
      await expectLater(db.service.recipients(listScope), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });
  });

  group('sending', () {
    setUp(() => db.seed('venue_night', 'o1', 'v1', ['boss@club.example', 'accountant@club.example']));

    test('sends the report with its PDF, and no address', () async {
      final result = await db.service.send(target, pdf());
      expect((result.sent, result.failed), (2, 0));
      final body = db.sends.single.body;
      expect(db.sends.single.name, 'send-report-email');
      expect(body.keys.toSet(), {'kind', 'orgId', 'venueId', 'eventId', 'ref', 'filename', 'again', 'pdfBase64'});
      expect(body['kind'], 'venue_night');
      expect(body['again'], isFalse);
      expect(base64Decode(body['pdfBase64'] as String), pdf());
      expect(jsonEncode(body), isNot(contains('@')));
    });

    test('a file name the database would refuse is made safe before it is sent', () async {
      await db.service.send(ReportTarget(kind: target.kind, orgId: 'o1', venueId: 'v1', ref: '2026-10-30', fileName: 'Zoë\'s night — 30 Oct.pdf'), pdf());
      expect(db.sends.single.body['filename'], 'Zo-s night - 30 Oct.pdf');
    });

    test('says which address was not reached, and sends again to only those', () async {
      db.failFor.add('accountant@club.example');
      final first = await db.service.send(target, pdf());
      expect((first.sent, first.failed), (1, 1));
      expect(first.results.map((r) => '${r.email}:${r.ok}'), ['boss@club.example:true', 'accountant@club.example:false']);
      db.failFor.clear();
      final again = await db.service.send(target, pdf(), again: true);
      expect(db.sends.last.body['again'], isTrue);
      expect(again.results.map((r) => r.email), ['accountant@club.example']);
      expect((again.sent, again.failed), (1, 0));
      await expectRefusal(db.service.send(target, pdf(), again: true), 'There is nothing to send again: every address already got this report.');
    });

    test('reads the log of one report, newest first', () async {
      db.failFor.add('accountant@club.example');
      await db.service.send(target, pdf());
      await db.service.send(const ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-29', fileName: 'n.pdf'), pdf());
      final log = await db.service.deliveries(target);
      expect(log.map((d) => '${d.email}:${d.status.name}'), ['accountant@club.example:failed', 'boss@club.example:sent']);
      expect(failedAddresses(log), ['accountant@club.example']);
      expect(db.calledWith('report_deliveries').first, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_event': null, 'p_ref': '2026-10-30', 'p_limit': 8});
    });

    test('turns the function\'s refusals into sentences', () async {
      db.role = 'organizer';
      await expectRefusal(db.service.send(target, pdf()), 'You cannot e-mail this report.');
      db.role = 'manager';
      db.lists.clear();
      await expectRefusal(db.service.send(target, pdf()), 'No one is set to receive this report. Add an e-mail address first.');
    });

    test('a PDF that is not one is refused by the function, in its words', () async {
      await expectRefusal(db.service.send(target, pdf('MZ not a pdf')), 'That is not a PDF.');
    });

    test('has a sentence for each status when the function gives none', () async {
      Future<void> statusSays(int status, String message) => expectRefusal(serviceAnswering(status).send(target, pdf()), message);

      await statusSays(401, 'Sign in again to e-mail a report.');
      await statusSays(403, 'You cannot e-mail this report.');
      await statusSays(429, 'Too many reports were sent this hour. Try again later.');
      await statusSays(500, 'The report could not be e-mailed. Check your connection and try again.');
    });

    test('a dropped connection, or an answer that is not an answer, is a plain sentence', () async {
      db.offline = true;
      await expectRefusal(db.service.send(target, pdf()), 'The report could not be e-mailed. Check your connection and try again.');
      final odd = serviceAnswering(null, answer: 'ok');
      await expectRefusal(odd.send(target, pdf()), 'The report could not be e-mailed. Try again.');
    });
  });
}

/// A service whose e-mail function answers with [status] and no sentence, or with [answer].
ReportEmailService serviceAnswering(int? status, {dynamic answer}) => ReportEmailService(
      invoker: (name, body) async {
        if (status != null) throw FunctionException(status: status);
        return answer;
      },
    );
