import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

// The words, shapes and checks behind e-mailing a report. The database decides every permission and limit; these tests keep the app's sentences and its trip-saving checks honest.

void main() {
  group('an address that can be added', () {
    test('is one address with a dot in the domain', () {
      expect(recipientProblem('boss@club.example', const []), isNull);
      expect(recipientProblem('  Boss@Club.Example  ', const []), isNull);
      expect(recipientProblem('first.last+reports@sub.club.co.uk', const []), isNull);
    });

    test('says what is wrong, in plain words', () {
      expect(recipientProblem('', const []), 'Type an e-mail address.');
      expect(recipientProblem('   ', const []), 'Type an e-mail address.');
      for (final bad in ['nope', 'a@b', 'a b@c.dd', 'a@b.cc,d@e.ff', 'a@b.cc;d@e.ff', '<a@b.cc>', '@b.cc', 'a@.cc']) {
        expect(recipientProblem(bad, const []), 'Enter one e-mail address, like name@company.com.', reason: bad);
      }
      expect(recipientProblem('${'x' * 250}@b.cc', const []), 'Enter one e-mail address, like name@company.com.');
    });

    test('is not already on the list, whatever the case', () {
      expect(recipientProblem('BOSS@club.example', const ['boss@club.example']), 'That address is already on the list.');
    });

    test('is compared without regard to case on both sides', () {
      expect(recipientProblem('boss@club.example', const ['Boss@Club.Example']), 'That address is already on the list.');
    });

    test('fits: a list holds ten', () {
      final nine = [for (var i = 1; i <= 9; i++) 'p$i@club.example'];
      expect(recipientProblem('tenth@club.example', nine), isNull);
      final ten = [...nine, 'p10@club.example'];
      expect(maxReportRecipients, 10);
      expect(recipientProblem('eleventh@club.example', ten), 'A list can hold at most 10 addresses. Remove one first.');
    });
  });

  group('the file name', () {
    test('is kept when it is already safe', () {
      expect(safeReportFileName('night-2026-10-30.pdf'), 'night-2026-10-30.pdf');
      expect(safeReportFileName('Club A (Friday).pdf'), 'Club A (Friday).pdf');
    });

    test('loses anything the database would refuse', () {
      expect(safeReportFileName('Zoë\'s Bar & Grill — night.pdf'), 'Zo-s Bar - Grill - night.pdf');
      expect(safeReportFileName('../../etc/passwd.pdf'), 'etc-passwd.pdf');
      expect(safeReportFileName('a/b\\c.pdf'), 'a-b-c.pdf');
    });

    test('always ends in .pdf, once', () {
      expect(safeReportFileName('report'), 'report.pdf');
      expect(safeReportFileName('report.PDF'), 'report.pdf');
      expect(safeReportFileName('report.pdf.pdf'), 'report.pdf.pdf');
    });

    test('is cut to what the database accepts: 95 characters and .pdf', () {
      for (final n in [94, 95, 96, 97]) {
        final name = safeReportFileName('${'a' * n}.pdf');
        expect(name.length, lessThanOrEqualTo(99), reason: '$n');
        expect(RegExp(r'^[A-Za-z0-9 _.()-]{1,95}\.pdf$').hasMatch(name), isTrue, reason: '$n');
      }
      expect(safeReportFileName('${'a' * 95}.pdf').length, 99);
    });

    test('is never empty, and never too long', () {
      expect(safeReportFileName(''), 'report.pdf');
      expect(safeReportFileName('???'), 'report.pdf');
      final long = safeReportFileName('${'a' * 300}.pdf');
      expect(long.length, lessThanOrEqualTo(99));
      expect(long.endsWith('.pdf'), isTrue);
    });

    test('passes the database\'s own pattern', () {
      final db = RegExp(r'^[A-Za-z0-9 _.()-]{1,95}\.pdf$');
      for (final name in ['Zoë\'s Bar & Grill — night.pdf', '../x.pdf', '${'é' * 200}.pdf', 'a.b.c.d.pdf', '  spaced  .pdf', '日本語.pdf', 'x(1).pdf']) {
        expect(db.hasMatch(safeReportFileName(name)), isTrue, reason: name);
      }
    });
  });

  group('the log', () {
    ReportDelivery d(String email, DeliveryStatus s) => ReportDelivery(email: email, status: s);

    test('the addresses to send again to are the ones whose LATEST attempt failed', () {
      // Newest first: boss failed after having been sent once; ann was sent after having failed; cy failed once.
      final log = [d('boss@x.cc', DeliveryStatus.failed), d('ann@x.cc', DeliveryStatus.sent), d('cy@x.cc', DeliveryStatus.failed), d('boss@x.cc', DeliveryStatus.sent), d('ann@x.cc', DeliveryStatus.failed)];
      expect(failedAddresses(log), ['boss@x.cc', 'cy@x.cc']);
      expect(failedAddresses(const []), isEmpty);
      expect(failedAddresses([d('a@x.cc', DeliveryStatus.pending)]), isEmpty);
    });

    test('reads a row of the database, and drops one it cannot use', () {
      final row = parseReportDelivery({'email': 'a@x.cc', 'status': 'failed', 'error': 'the e-mail provider did not accept the message', 'sent_at': '2026-10-31T18:05:00Z', 'created_at': '2026-10-31T18:04:00Z'})!;
      expect(row.status, DeliveryStatus.failed);
      expect(row.error, 'the e-mail provider did not accept the message');
      expect(row.at, DateTime.utc(2026, 10, 31, 18, 5).toLocal());
      expect(parseReportDelivery({'email': 'a@x.cc', 'status': 'sent', 'error': '', 'created_at': '2026-10-31T18:04:00Z'})!.error, isNull);
      expect(parseReportDelivery({'email': 'a@x.cc', 'status': 'weird'}), isNull);
      expect(parseReportDelivery({'status': 'sent'}), isNull);
      expect(parseReportDelivery({'email': '', 'status': 'sent'}), isNull);
    });

    test('says each line in words', () {
      final at = DateTime(2026, 10, 31, 18, 5);
      expect(deliveryLine(ReportDelivery(email: 'a@x.cc', status: DeliveryStatus.sent, at: at)), 'a@x.cc: sent, 31 Oct, 18:05');
      expect(deliveryLine(ReportDelivery(email: 'a@x.cc', status: DeliveryStatus.failed, at: at)), 'a@x.cc: could not be sent, 31 Oct, 18:05');
      expect(deliveryLine(ReportDelivery(email: 'a@x.cc', status: DeliveryStatus.pending, at: at)), 'a@x.cc: sending, 31 Oct, 18:05');
      expect(deliveryLine(const ReportDelivery(email: 'a@x.cc', status: DeliveryStatus.sent)), 'a@x.cc: sent');
      expect(logMoment(DateTime(2026, 1, 3, 4, 7)), '3 Jan, 04:07');
    });
  });

  group('what the e-mail function answered', () {
    test('is read, or refused when it is not an answer', () {
      final r = parseSendResult({'sent': 1, 'failed': 1, 'results': [{'email': 'a@x.cc', 'ok': true}, {'email': 'b@x.cc', 'ok': false}]})!;
      expect((r.sent, r.failed, r.total), (1, 1, 2));
      expect(r.results.map((x) => '${x.email}:${x.ok}'), ['a@x.cc:true', 'b@x.cc:false']);
      expect(parseSendResult(null), isNull);
      expect(parseSendResult('ok'), isNull);
      expect(parseSendResult({'sent': '2', 'failed': 0}), isNull);
      expect(parseSendResult({'sent': 2}), isNull);
    });

    test('is told in words', () {
      expect(sendResultMessage(const ReportSendResult(sent: 1, failed: 0, results: [])), 'Sent to 1 person.');
      expect(sendResultMessage(const ReportSendResult(sent: 3, failed: 0, results: [])), 'Sent to 3 people.');
      expect(sendResultMessage(const ReportSendResult(sent: 1, failed: 2, results: [])), 'Sent to 1 of 3. 2 could not be reached: you can send again to them.');
      expect(sendResultMessage(const ReportSendResult(sent: 0, failed: 2, results: [])), 'Nothing was sent: the e-mail was not accepted. Try again in a moment.');
      expect(sendResultMessage(const ReportSendResult(sent: 0, failed: 0, results: [])), 'Nothing was sent: the e-mail was not accepted. Try again in a moment.');
    });
  });

  group('a report and its list', () {
    const target = ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-30', fileName: 'Club A — night.pdf');

    test('knows its list', () {
      expect(target.list, const ReportListScope(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1'));
      expect(target.list.params, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1'});
    });

    test('asks the log for this report only', () {
      expect(target.deliveryParams, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_event': null, 'p_ref': '2026-10-30', 'p_limit': 8});
    });

    test('makes the body of the request with a safe file name and NO address', () {
      final body = target.body(again: false);
      expect(body, {'kind': 'venue_night', 'orgId': 'o1', 'venueId': 'v1', 'eventId': null, 'ref': '2026-10-30', 'filename': 'Club A - night.pdf', 'again': false});
      expect(target.body(again: true)['again'], isTrue);
      expect(body.keys.where((k) => k.toLowerCase().contains('mail') || k == 'to' || k == 'recipients'), isEmpty);
    });

    test('is equal to the same report, so a screen does not ask twice', () {
      const same = ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-30', fileName: 'Club A — night.pdf');
      expect(same, target);
      expect(same.hashCode, target.hashCode);
      expect(const ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-31', fileName: 'Club A — night.pdf'), isNot(target));
      expect(const ReportListScope(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v2'), isNot(target.list));
    });
  });

  group('the words', () {
    test('each list says who keeps it', () {
      expect(listExplainer(ReportKind.ownerCombined), contains('Only owners'));
      expect(listExplainer(ReportKind.venueNight), contains('owner and the manager'));
      expect(listExplainer(ReportKind.organizerSales), contains('never holds more than your Sales page shows'));
      expect(listTitle(ReportKind.venueNight, venueName: 'Club A'), 'Night report: Club A');
      expect(listTitle(ReportKind.venueNight), 'Night report');
      expect(listTitle(ReportKind.ownerCombined), 'Combined report');
      expect(reportEmailNote, contains('Nothing is sent on its own'));
    });

    test('only the owner and the manager e-mail a club report from the report', () {
      for (final role in WorkspaceRole.values) {
        expect(canEmailClubReports(role), role == WorkspaceRole.owner || role == WorkspaceRole.manager, reason: role.name);
      }
    });

    test('only the owner and the manager are given a business to e-mail a club report under', () {
      for (final role in WorkspaceRole.values) {
        final w = Workspace(membershipId: 'w', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: role);
        expect(emailOrgIdFor(w), role == WorkspaceRole.owner || role == WorkspaceRole.manager ? 'o1' : isNull, reason: role.name);
      }
    });

    test('a recipient row is read, or dropped', () {
      expect(parseReportRecipient({'id': 'r1', 'email': 'a@x.cc'})!.email, 'a@x.cc');
      expect(parseReportRecipient({'id': '', 'email': 'a@x.cc'}), isNull);
      expect(parseReportRecipient({'id': 'r1'}), isNull);
    });
  });
}
