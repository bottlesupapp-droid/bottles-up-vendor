import 'dart:io';

import 'package:bottles_up_vendor/features/workspace/logic/invitation_check.dart';
import 'package:bottles_up_vendor/features/workspace/services/invitation_check_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_invite_check.dart';

// Opening an invitation link: what the link is, the code for a temporary one, and asking for a new link (website repo, 20261118100000_temporary_staff_links.sql).

Map<String, dynamic> raw({String outcome = 'ok', bool needsCode = true}) => {
      'outcome': outcome, 'kind': 'temporary', 'needs_code': needsCode, 'email_hint': 't***@club.example', 'role': 'door', 'org_name': 'Club Co', 'venue_name': 'Club A', 'shift_name': 'Friday late',
      'access_end_at': '2031-10-25T03:00:00Z', 'expires_at': '2031-10-25T12:00:00Z', 'renewal_requested': false,
    };

void main() {
  late FakeInviteCheck db;
  setUp(() => db = FakeInviteCheck());

  group('what the link is', () {
    test('is read: the kind, whether a code is needed, the hidden address and what the access is', () {
      final p = parseInvitationPreview(raw())!;
      expect(p.outcome, PreviewOutcome.ok);
      expect(p.isTemporary, isTrue);
      expect(p.needsCode, isTrue);
      expect(p.emailHint, 't***@club.example');
      expect(p.role, 'door');
      expect(p.accessEndAt, DateTime.utc(2031, 10, 25, 3));
      expect(p.renewalRequested, isFalse);
    });

    test('an answer the app does not know is no preview, not a guess', () {
      expect(parseInvitationPreview({'outcome': 'something_new'}), isNull);
      expect(parseInvitationPreview({}), isNull);
      expect(parseInvitationPreview({'outcome': null}), isNull);
    });

    test('every outcome the database gives is known', () {
      for (final o in ['ok', 'invalid', 'revoked', 'expired', 'already_accepted', 'email_mismatch']) {
        expect(parseInvitationPreview({'outcome': o})!.outcome.value, o);
      }
    });

    test('a link with no kind is permanent and needs no code', () {
      final p = parseInvitationPreview({'outcome': 'ok'})!;
      expect(p.isTemporary, isFalse);
      expect(p.needsCode, isFalse);
    });

    test('the summary says the role, the business, where and until when', () {
      final text = previewSummary(parseInvitationPreview(raw())!);
      expect(text, matches(RegExp(r'^Door staff for Club Co · Club A · Friday late\. Access: until [A-Z][a-z]{2} \d{1,2}, .*\.$')));
    });

    test('and copes with a link that says little', () {
      expect(previewSummary(const InvitationPreview(outcome: PreviewOutcome.ok)), 'Staff · Whole business. Access: ongoing.');
    });

    test('knowing it was asked for again changes nothing else', () {
      final p = parseInvitationPreview(raw())!.copyWith(renewalRequested: true);
      expect(p.renewalRequested, isTrue);
      expect([p.role, p.venueName, p.shiftName, p.emailHint, p.needsCode], ['door', 'Club A', 'Friday late', 't***@club.example', true]);
    });
  });

  group('the code', () {
    test('six digits are accepted, spaces ignored; anything else is told what to do', () {
      expect(checkCodeInput('482913'), isNull);
      expect(checkCodeInput(' 482 913 '), isNull);
      for (final bad in ['', '12345', '1234567', 'abcdef', '48291a']) {
        expect(checkCodeInput(bad), 'Type the 6 digits from the e-mail.', reason: bad);
      }
      expect(cleanCode(' 482 913 '), '482913');
    });

    test('each outcome has its words', () {
      String m(CodeOutcome o, [int? left]) => codeCheckMessage(CodeCheck(o, attemptsLeft: left));
      expect(m(CodeOutcome.ok), 'Your e-mail is confirmed.');
      expect(m(CodeOutcome.wrong, 4), 'That code is not right. 4 tries left.');
      expect(m(CodeOutcome.wrong, 1), 'That code is not right. 1 try left.');
      expect(m(CodeOutcome.wrong, 0), 'That code is not right. Ask for a new code.');
      expect(m(CodeOutcome.malformed), 'Type the 6 digits from the e-mail.');
      expect(m(CodeOutcome.locked), 'Too many wrong codes. Ask for a new code.');
      expect(m(CodeOutcome.codeExpired), 'That code has expired. Ask for a new one.');
      expect(m(CodeOutcome.noCode), 'Ask for a code first.');
      expect(m(CodeOutcome.failed), 'The code could not be checked. Check your connection and try again.');
      for (final o in CodeOutcome.values) {
        expect(m(o, 3).isNotEmpty, isTrue, reason: o.name);
      }
    });

    test('an unknown outcome is a failure, never a success', () {
      expect(CodeOutcome.fromDb('something_new'), CodeOutcome.failed);
      expect(CodeOutcome.fromDb(null), CodeOutcome.failed);
      expect(CodeOutcome.fromDb('ok'), CodeOutcome.ok);
      expect(parseCodeCheck({'outcome': 'wrong', 'attempts_left': 3})!.attemptsLeft, 3);
      expect(parseCodeCheck({}), isNull);
    });
  });

  group('asking for a new link', () {
    test('every outcome has its words, and only two mean the person who invited them has been told', () {
      for (final o in RenewalOutcome.values) {
        expect(renewalMessage(o).isNotEmpty, isTrue, reason: o.name);
      }
      expect(RenewalOutcome.values.where((o) => o.told), [RenewalOutcome.requested, RenewalOutcome.alreadyRequested]);
      expect(RenewalOutcome.fromDb('requested'), RenewalOutcome.requested);
      expect(RenewalOutcome.fromDb('nonsense'), RenewalOutcome.failed);
      expect(RenewalOutcome.fromDb(null), RenewalOutcome.failed);
      expect(renewalMessage(RenewalOutcome.requested), startsWith('Done.'));
    });
  });

  group('the calls', () {
    test('the preview is asked for by link', () async {
      final p = await db.service.preview('tok-abc');
      expect(db.calledWith('invitation_preview').single, {'p_token': 'tok-abc'});
      expect(p.outcome, PreviewOutcome.ok);
      expect(p.needsCode, isTrue);
    });

    test('a server without the function is a load failure the screen can step around', () async {
      db.previewAvailable = false;
      await expectLater(db.service.preview('t'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });

    test('the code is asked for from the e-mail function, with the link and nothing else; what comes back never holds the code', () async {
      final r = await db.service.sendCode('tok-abc');
      expect(db.calledWith('send-invitation-code').single, {'token': 'tok-abc'});
      expect(r.sent, isTrue);
      expect(r.toHint, 't***@club.example');
      expect(r.message, 'We sent a 6-digit code to t***@club.example. It works for 10 minutes.');
      expect(r.message, isNot(contains('482913')));
      expect(db.lastEmailedCode, '482913');
    });

    test('each way the e-mail function can fail has a sentence, and tells whether a code may already exist', () async {
      db.sendStatus = 429;
      db.sendError = 'Please wait a minute before asking for another code.';
      var r = await db.service.sendCode('t');
      expect([r.sent, r.codeMayExist, r.message], [false, true, 'Please wait a minute before asking for another code.']);
      db.sendError = 'Too many codes have been sent for this link. Try again in an hour, or ask the person who invited you for a new link.';
      r = await db.service.sendCode('t');
      expect([r.sent, r.codeMayExist], [false, false]);
      db.sendStatus = 401;
      expect((await db.service.sendCode('t')).message, 'Sign in with the address your invitation was sent to.');
      db.sendStatus = 403;
      db.sendError = null;
      expect((await db.service.sendCode('t')).message, 'This link was not sent to the address you are signed in with.');
      db.sendStatus = 409;
      expect((await db.service.sendCode('t')).message, 'This link was already used, cancelled or has expired.');
      db.sendStatus = 500;
      expect((await db.service.sendCode('t')).message, 'We could not send the code. Check your connection and try again.');
    });

    test('no e-mail configured, and a dropped connection, are said in words', () async {
      db.sendNotConfigured = true;
      expect((await db.service.sendCode('t')).message, 'We cannot send e-mail right now. Ask the person who invited you for help.');
      db.sendNotConfigured = false;
      db.sendThrows = true;
      expect((await db.service.sendCode('t')).message, 'We could not send the code. Check your connection and try again.');
    });

    test('checking a code sends the digits only, and the database counts the guesses', () async {
      await db.service.sendCode('t');
      expect((await db.service.verify('t', ' 000 000 ')).outcome, CodeOutcome.wrong);
      expect(db.calledWith('verify_invitation_code').single, {'p_token': 't', 'p_code': '000000'});
      expect((await db.service.verify('t', '000000')).attemptsLeft, 3);
      final ok = await db.service.verify('t', '482913');
      expect(ok.outcome, CodeOutcome.ok);
    });

    test('five wrong codes lock it, and a new code unlocks it', () async {
      await db.service.sendCode('t');
      for (var i = 0; i < 5; i++) {
        await db.service.verify('t', '000000');
      }
      expect((await db.service.verify('t', '482913')).outcome, CodeOutcome.locked);
      await db.service.sendCode('t');
      expect((await db.service.verify('t', '482913')).outcome, CodeOutcome.ok);
    });

    test('a failure to check is a failure, not a pass', () async {
      db.offline = true;
      expect((await db.service.verify('t', '482913')).outcome, CodeOutcome.failed);
      db.offline = false;
      db.previewAvailable = false;
      expect((await db.service.verify('t', '482913')).outcome, CodeOutcome.failed);
    });

    test('asking for a new link: with a note trimmed, or none', () async {
      db.expired = true;
      expect(await db.service.requestRenewal('t', note: '  late again  '), RenewalOutcome.requested);
      expect(db.calledWith('request_invitation_renewal').single, {'p_token': 't', 'p_note': 'late again'});
      expect(await db.service.requestRenewal('t', note: '   '), RenewalOutcome.alreadyRequested);
      expect(db.calledWith('request_invitation_renewal').last['p_note'], isNull);
    });

    test('and a failure to ask is a failure', () async {
      db.offline = true;
      expect(await db.service.requestRenewal('t'), RenewalOutcome.failed);
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261118100000_temporary_staff_links.sql');
    final fn = File('../bottles-up-website-main/supabase/functions/send-invitation-code/index.ts');
    const why = 'the temporary staff links migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('the functions, their parameters and who may call them', () async {
      final sql = migration.readAsStringSync();
      for (final f in [
        'invitation_preview(p_token text)',
        'verify_invitation_code(p_token text, p_code text)',
        'request_invitation_renewal(p_token text, p_note text default null)',
        'list_invitation_extras(p_org uuid)',
      ]) {
        expect(sql, contains('create function public.$f'));
      }
      expect(sql, contains('revoke all on function public.issue_invitation_code(text, text) from public, anon, authenticated;'));
      expect(sql, contains('grant execute on function public.issue_invitation_code(text, text) to service_role;'));
      await db.service.preview('t');
      await db.service.verify('t', '000000');
      db.expired = true;
      await db.service.requestRenewal('t', note: 'x');
      final keys = {for (final c in db.calls) c.function: c.params!.keys.toList()};
      expect(keys['invitation_preview'], ['p_token']);
      expect(keys['verify_invitation_code'], ['p_token', 'p_code']);
      expect(keys['request_invitation_renewal'], ['p_token', 'p_note']);
    }, skip: migration.existsSync() ? false : why);

    test('every outcome the app knows is one the database gives, and the other way round', () {
      final sql = migration.readAsStringSync();
      for (final o in CodeOutcome.values.where((o) => o != CodeOutcome.failed)) {
        expect(sql, contains("'${o.value}'::text"), reason: o.value);
      }
      for (final o in RenewalOutcome.values.where((o) => o != RenewalOutcome.failed)) {
        expect(sql, contains("'${o.value}'"), reason: o.value);
      }
      for (final o in PreviewOutcome.values) {
        expect(sql, contains("'${o.value}'"), reason: o.value);
      }
      final made = RegExp(r"return query select '(\w+)'::text").allMatches(sql).map((m) => m.group(1)!).toSet();
      expect(made.difference(CodeOutcome.values.map((o) => o.value).toSet()), isEmpty, reason: 'the database gives an outcome the app does not know');
    }, skip: migration.existsSync() ? false : why);

    test('the limits the app words are the database\'s', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains(r"v_code !~ '^[0-9]{6}$'"));
      expect(sql, contains('c.attempts >= 5'));
      expect(sql, contains("now() + interval '10 minutes'"));
      expect(sql, contains("interval '30 minutes'"));
      expect(sql, contains("raise exception 'confirm your e-mail with the code we sent before using this link'"));
      expect(sql, contains("'email_hint', left(split_part(i.email, '@', 1), 1) || '***@' || split_part(i.email, '@', 2)"));
    }, skip: migration.existsSync() ? false : why);

    test('the e-mail function answers with the keys and statuses the app reads', () {
      final ts = File('../bottles-up-website-main/supabase/functions/_shared/invitationCode.ts').readAsStringSync();
      expect(fn.readAsStringSync(), contains('sendInvitationCode'));
      for (final s in ['to_hint', 'sent: true', "reason: result.reason ?? 'send_failed'", '429', '401', '403', '409', 'wait a minute']) {
        expect(ts, contains(s), reason: s);
      }
    }, skip: migration.existsSync() && fn.existsSync() ? false : why);
  });
}
