import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_report_email_backend.dart';

// Sending a report automatically when the night is closed (website 20261126100000_auto_report_jobs.sql). The words, how the switch's status is read (never guessed), and the calls.

ReportAutoStatus status({
  bool enabled = true,
  bool mine = true,
  int recipients = 2,
  String? by = 'Mia Manager',
  String? lastStatus,
  String? lastRef,
  String? lastError,
}) => parseReportAutoStatus({
  'enabled': enabled,
  'mine': mine,
  'recipients': recipients,
  'changed_by_name': by,
  'changed_at': '2026-11-18T10:00:00Z',
  'last_status': lastStatus,
  'last_ref': lastRef,
  'last_at': lastStatus == null ? null : '2026-11-18T11:00:00Z',
  'last_error': lastError,
})!;

void main() {
  group('Reading the switch', () {
    test('a row is read field by field, with the times in the person\'s own zone', () {
      final s = status(lastStatus: 'failed', lastRef: '2026-11-14', lastError: 'The person who switched it on no longer has access.');
      expect([s.enabled, s.mine, s.recipients, s.changedByName, s.lastStatus, s.lastRef, s.lastError], [true, true, 2, 'Mia Manager', 'failed', '2026-11-14', 'The person who switched it on no longer has access.']);
      expect(s.changedAt!.toUtc(), DateTime.utc(2026, 11, 18, 10));
      expect(s.lastAt!.toUtc(), DateTime.utc(2026, 11, 18, 11));
    });

    test('a row that does not say on or off is not read, and odd values become defaults, never a crash', () {
      expect(parseReportAutoStatus({'mine': true}), isNull);
      expect(parseReportAutoStatus({'enabled': 'yes'}), isNull);
      final s = parseReportAutoStatus({'enabled': false, 'recipients': 'many', 'changed_at': 'soon', 'last_status': '', 'mine': 'true'})!;
      expect([s.enabled, s.mine, s.recipients, s.changedAt, s.lastStatus, s.changedByName], [false, false, 0, null, null, null]);
      expect(parseReportAutoStatus({'enabled': true, 'recipients': 3.0})!.recipients, 3);
    });

    test('never switched on is off, with nothing sent yet', () {
      final s = parseReportAutoStatus({'enabled': false, 'mine': false, 'recipients': 0, 'changed_by_name': null, 'changed_at': null, 'last_status': null, 'last_ref': null, 'last_at': null, 'last_error': null})!;
      expect([s.enabled, s.changedByName, s.changedAt, s.lastStatus], [false, null, null, null]);
    });
  });

  group('The words', () {
    test('each kind of report says when it goes out on its own', () {
      expect(autoWhen(ReportKind.venueNight), 'when the night is closed');
      expect(autoWhen(ReportKind.ownerCombined), 'when every club has closed the night');
      expect(autoWhen(ReportKind.organizerSales), 'when every club hosting an event of yours has closed its night');
      expect(autoSwitchTitle(ReportKind.venueNight), 'Send automatically when the night is closed');
      expect(autoSwitchTitle(ReportKind.ownerCombined), 'Send automatically when every club has closed the night');
    });

    test('off says it is e-mailed only when someone presses the button', () {
      expect(autoStateLine(status(enabled: false)), 'Off. This report is e-mailed only when someone presses E-mail this report.');
    });

    test('on says who it is sent as, and that it stops if they lose access', () {
      expect(autoStateLine(status()), 'On. It is sent as you: if you lose access to this report, it stops and says so here.');
      expect(autoStateLine(status(mine: false)), 'On. It is sent as Mia Manager: if they lose access to this report, it stops and says so here.');
      expect(autoStateLine(status(mine: false, by: null)), 'On. It is sent as someone else: if they lose access to this report, it stops and says so here.');
    });

    test('the latest automatic send, in words, with the night, and the reason when there is one', () {
      String? line(String? s, {String? err, String? ref = '2026-11-14', ReportKind kind = ReportKind.venueNight}) => autoLastLine(status(lastStatus: s, lastRef: ref, lastError: err), kind);
      expect(line(null), isNull);
      expect(line('sent'), 'Last automatic send, Saturday Nov 14: sent');
      expect(line('running'), 'Last automatic send, Saturday Nov 14: being sent now');
      expect(line('pending'), 'Last automatic send, Saturday Nov 14: waiting to be sent');
      expect(line('pending', err: 'Too many reports were sent this hour.'), 'Last automatic send, Saturday Nov 14: waiting to be sent: Too many reports were sent this hour.');
      expect(line('failed', err: 'The person who switched it on no longer has access. Switch it on again.'), 'Last automatic send, Saturday Nov 14: not sent: The person who switched it on no longer has access. Switch it on again.');
      expect(line('failed'), 'Last automatic send, Saturday Nov 14: not sent');
      expect(line('skipped', err: 'No one is set to receive it. Add an e-mail address first.'), 'Last automatic send, Saturday Nov 14: skipped: No one is set to receive it. Add an e-mail address first.');
      expect(line('mystery'), 'Last automatic send, Saturday Nov 14: mystery');
      expect(line('sent', err: 'a stale reason'), 'Last automatic send, Saturday Nov 14: sent', reason: 'a send that went is never shown with a reason');
    });

    test('an organizer\'s event report has no night to name (its reference is the event), and a missing reference names none', () {
      expect(autoLastLine(status(lastStatus: 'sent', lastRef: 'e-123'), ReportKind.organizerSales), 'Last automatic send: sent');
      expect(autoLastLine(status(lastStatus: 'sent', lastRef: null), ReportKind.venueNight), 'Last automatic send: sent');
      expect(autoLastLine(status(lastStatus: 'sent', lastRef: 'not a date'), ReportKind.venueNight), 'Last automatic send, not a date: sent');
    });

    test('what the person is told before switching it on: what goes to whom and when, that it uses their access, and that closed nights are not sent', () {
      final one = autoConfirmMessage(ReportKind.venueNight, 1);
      expect(one, contains('This club\'s night report will be e-mailed to the 1 address on this list when the night is closed'));
      expect(one, contains('as if you pressed E-mail this report'));
      expect(one, contains('It uses your access: if you leave this business or lose access, it stops.'));
      expect(one, contains('Nights that are already closed are not sent.'));
      expect(autoConfirmMessage(ReportKind.ownerCombined, 3), startsWith('The combined report will be e-mailed to the 3 addresses on this list when every club has closed the night'));
      expect(autoConfirmMessage(ReportKind.organizerSales, 2), startsWith('Each event report will be e-mailed to the 2 addresses on this list when every club hosting an event of yours has closed its night'));
      expect(autoConfirmMessage(ReportKind.venueNight, 0), contains('the list (it is empty, so nothing will be sent until you add an address)'));
    });

    test('the page note says a report goes out when someone presses the button, and also on its own where the switch is on', () {
      expect(reportEmailNote, contains('presses E-mail this report'));
      expect(reportEmailNote, contains('automatic sending is switched on'));
      expect(reportEmailNote, isNot(contains('Nothing is sent on its own')));
      expect(autoNoRecipientsText, 'No one is on the list, so nothing will be sent. Add an e-mail address above.');
    });
  });

  group('The calls', () {
    late FakeReportEmailBackend mail;
    setUp(() => mail = FakeReportEmailBackend(role: 'owner'));
    const scope = ReportListScope(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1');

    test('the status asks with the kind, the business and the club, and reads the row', () async {
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example', 'b@club.example']);
      final s = await mail.service.autoStatus(scope);
      expect(mail.calledWith('report_auto_status').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1'});
      expect([s.enabled, s.recipients, s.mine], [false, 2, false]);
    });

    test('an owner\'s combined list is asked about with no club', () async {
      await mail.service.autoStatus(const ReportListScope(kind: ReportKind.ownerCombined, orgId: 'o1'));
      expect(mail.calledWith('report_auto_status').single, {'p_kind': 'owner_combined', 'p_org': 'o1', 'p_venue': null});
    });

    test('switching on and off sends the scope and the choice, and says what it is now', () async {
      expect(await mail.service.setAuto(scope, true), isTrue);
      expect(mail.calledWith('report_auto_set').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_enabled': true});
      expect((await mail.service.autoStatus(scope)).enabled, isTrue);
      expect(await mail.service.setAuto(scope, false), isFalse);
      expect(mail.calledWith('report_auto_set').last['p_enabled'], false);
      expect((await mail.service.autoStatus(scope)).enabled, isFalse);
    });

    test('a person who may not is refused in the database\'s own sentence', () async {
      mail.role = 'manager';
      await expectLater(
        mail.service.setAuto(const ReportListScope(kind: ReportKind.ownerCombined, orgId: 'o1'), true),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', "You don't have access to do that.")),
      );
    });

    test('a lost connection is a plain sentence', () async {
      mail.offline = true;
      await expectLater(mail.service.setAuto(scope, true), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('Check your connection'))));
    });

    test('a server without the migration makes the status "not set up", and a lost connection does not', () async {
      mail.missing = true;
      await expectLater(mail.service.autoStatus(scope), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true)));
      mail.missing = false;
      mail.offline = true;
      await expectLater(mail.service.autoStatus(scope), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false)));
    });
  });
}
