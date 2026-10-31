import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/accept_invitation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_invite_check.dart';

// Opening an invitation link: a temporary one asks for the code sent to the invited address; an expired one offers to ask for a new link; anything else is as it always was.

late FakeInviteCheck db;

Widget harness() {
  final router = GoRouter(initialLocation: '/accept-invite?token=tok-abc', routes: [
    GoRoute(path: '/accept-invite', builder: (_, s) => AcceptInvitationScreen(token: s.uri.queryParameters['token'])),
    GoRoute(path: '/workspaces', builder: (_, __) => const Scaffold(body: Text('workspace list'))),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      workspaceServiceProvider.overrideWithValue(db.workspaceService),
      invitationCheckServiceProvider.overrideWithValue(db.service),
      workspaceSnapshotProvider.overrideWith((ref) async => throw StateError('not asked here')),
    ],
    child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
  );
}

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  pendingInviteToken.value = 'tok-abc';
  await tester.pumpWidget(harness());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('code-field')), code);
  await tester.pump();
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    db = FakeInviteCheck();
    pendingInviteToken.value = null;
  });
  tearDown(() => pendingInviteToken.value = null);

  group('a link that needs no code', () {
    testWidgets('a permanent invitation is accepted at once, as it always was', (tester) async {
      db.temporary = false;
      await open(tester);
      expect(text(tester, 'invitation-message'), 'You are in. Your workspace is ready.');
      expect(db.calledWith('accept_invitation'), hasLength(1));
      expect(db.calledWith('send-invitation-code'), isEmpty);
      expect(find.byKey(const Key('code-title')), findsNothing);
      expect(pendingInviteToken.value, isNull);
    });

    testWidgets('a temporary link already confirmed goes straight in', (tester) async {
      db.verified = true;
      await open(tester);
      expect(text(tester, 'invitation-message'), 'You are in. Your workspace is ready.');
      expect(find.byKey(const Key('code-title')), findsNothing);
    });

    testWidgets('Open my workspace goes to the workspaces', (tester) async {
      db.temporary = false;
      await open(tester);
      await tester.tap(find.text('Open my workspace'));
      await tester.pumpAndSettle();
      expect(find.text('workspace list'), findsOneWidget);
    });
  });

  group('a temporary link', () {
    testWidgets('asks first: what the access is, where the code goes (the address mostly hidden), and a button to send it', (tester) async {
      await open(tester);
      expect(find.text('Confirm it is you'), findsOneWidget);
      expect(text(tester, 'code-summary'), startsWith('Door staff for Club Co · Club A · Friday late. Access: until '));
      expect(text(tester, 'code-explainer'), contains('t***@club.example'));
      expect(find.byKey(const Key('code-send')), findsOneWidget);
      expect(find.byKey(const Key('code-field')), findsNothing, reason: 'no code has been sent yet');
      expect(db.calledWith('accept_invitation'), isEmpty, reason: 'the link is not used until the address is confirmed');
      expect(db.emailCount, 0, reason: 'nothing is sent until the person asks');
    });

    testWidgets('sending the code e-mails it, says where, and shows the box for it', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      expect(db.emailCount, 1);
      expect(db.calledWith('send-invitation-code').single, {'token': 'tok-abc'});
      expect(text(tester, 'code-message'), 'We sent a 6-digit code to t***@club.example. It works for 10 minutes.');
      expect(find.byKey(const Key('code-field')), findsOneWidget);
      expect(find.byKey(const Key('code-confirm')), findsOneWidget);
      expect(find.byKey(const Key('code-send')), findsNothing);
    });

    testWidgets('the right code confirms the address and then the link is used', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, db.lastEmailedCode!);
      await tapKey(tester, 'code-confirm');
      expect(db.calledWith('verify_invitation_code').single, {'p_token': 'tok-abc', 'p_code': '482913'});
      expect(db.calledWith('accept_invitation'), hasLength(1));
      expect(text(tester, 'invitation-message'), 'You are in. Your workspace is ready.');
      expect(pendingInviteToken.value, isNull);
    });

    testWidgets('the box takes digits only, six at most', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, '48a2 91x3999');
      expect(tester.widget<TextField>(find.byKey(const Key('code-field'))).controller!.text, '482913');
    });

    testWidgets('a short code is told what to do, without asking the database', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, '123');
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'code-message'), 'Type the 6 digits from the e-mail.');
      expect(db.calledWith('verify_invitation_code'), isEmpty);
    });

    testWidgets('a wrong code is counted and said, with the tries left; the link is not used', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, '000000');
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'code-message'), 'That code is not right. 4 tries left.');
      await typeCode(tester, '000001');
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'code-message'), 'That code is not right. 3 tries left.');
      expect(db.calledWith('accept_invitation'), isEmpty);
      expect(find.byKey(const Key('code-field')), findsOneWidget, reason: 'they can try again');
    });

    testWidgets('typing again clears the old message', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, '000000');
      await tapKey(tester, 'code-confirm');
      expect(find.byKey(const Key('code-message')), findsOneWidget);
      await typeCode(tester, '00000');
      expect(find.byKey(const Key('code-message')), findsNothing);
    });

    testWidgets('five wrong codes lock it; even the right one is then refused; a new code starts again', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      for (var i = 0; i < 5; i++) {
        await typeCode(tester, '00000$i');
        await tapKey(tester, 'code-confirm');
      }
      expect(text(tester, 'code-message'), 'That code is not right. Ask for a new code.');
      await typeCode(tester, db.lastEmailedCode!);
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'code-message'), 'Too many wrong codes. Ask for a new code.');
      expect(db.calledWith('accept_invitation'), isEmpty);
      await tapKey(tester, 'code-resend');
      expect(db.emailCount, 2);
      await typeCode(tester, db.lastEmailedCode!);
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'invitation-message'), 'You are in. Your workspace is ready.');
    });

    testWidgets('a code that has expired is said, and a new one can be asked for', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      db.codeExpired = true;
      await typeCode(tester, '482913');
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'code-message'), 'That code has expired. Ask for a new one.');
      await tapKey(tester, 'code-resend');
      expect(db.codeExpired, isFalse);
    });

    testWidgets('while the code is being checked or sent the buttons wait', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      await typeCode(tester, '000000');
      await tester.tap(find.byKey(const Key('code-confirm')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(db.calledWith('verify_invitation_code'), hasLength(1));
    });
  });

  group('when the code cannot be sent', () {
    testWidgets('asking too soon says to wait, and a code sent a moment ago can still be typed', (tester) async {
      db.sendStatus = 429;
      db.sendError = 'Please wait a minute before asking for another code.';
      await open(tester);
      await tapKey(tester, 'code-send');
      expect(text(tester, 'code-message'), 'Please wait a minute before asking for another code.');
      expect(find.byKey(const Key('code-field')), findsOneWidget);
    });

    testWidgets('too many codes in an hour says so, and there is no box to type in', (tester) async {
      db.sendStatus = 429;
      db.sendError = 'Too many codes have been sent for this link. Try again in an hour, or ask the person who invited you for a new link.';
      await open(tester);
      await tapKey(tester, 'code-send');
      expect(text(tester, 'code-message'), startsWith('Too many codes have been sent for this link.'));
      expect(find.byKey(const Key('code-field')), findsNothing);
      expect(find.byKey(const Key('code-send')), findsOneWidget, reason: 'they can ask again later');
    });

    testWidgets('e-mail that is not set up, and a dropped connection, are said in plain words', (tester) async {
      db.sendNotConfigured = true;
      await open(tester);
      await tapKey(tester, 'code-send');
      expect(text(tester, 'code-message'), 'We cannot send e-mail right now. Ask the person who invited you for help.');
      expect(find.byKey(const Key('code-field')), findsNothing);
      db.sendNotConfigured = false;
      db.sendThrows = true;
      await tapKey(tester, 'code-send');
      expect(text(tester, 'code-message'), 'We could not send the code. Check your connection and try again.');
    });

    testWidgets('a link sent to another address says so and nothing is sent', (tester) async {
      db.sendStatus = 403;
      await open(tester);
      await tapKey(tester, 'code-send');
      expect(text(tester, 'code-message'), 'This link was not sent to the address you are signed in with.');
    });
  });

  group('when the address turns out to be someone else\'s, or the link ended', () {
    testWidgets('a link for another address says so at once, with no code asked for', (tester) async {
      db.emailMatches = false;
      await open(tester);
      expect(text(tester, 'invitation-message'), startsWith('This invitation was sent to a different email address.'));
      expect(find.byKey(const Key('code-title')), findsNothing);
      expect(db.emailCount, 0);
    });

    testWidgets('a cancelled invitation says so', (tester) async {
      db.status = 'revoked';
      await open(tester);
      expect(text(tester, 'invitation-message'), 'This invitation was cancelled. Contact the person who sent it.');
    });

    testWidgets('one already used says so, and offers the workspace', (tester) async {
      db.status = 'accepted';
      await open(tester);
      expect(text(tester, 'invitation-message'), 'You already accepted this invitation.');
      expect(find.text('Open my workspace'), findsOneWidget);
    });

    testWidgets('a link that was cancelled while the code step was open ends there', (tester) async {
      await open(tester);
      await tapKey(tester, 'code-send');
      db.status = 'revoked';
      await typeCode(tester, '482913');
      await tapKey(tester, 'code-confirm');
      expect(text(tester, 'invitation-message'), 'This invitation was cancelled. Contact the person who sent it.');
    });

    testWidgets('a link with no token is not valid', (tester) async {
      final router = GoRouter(initialLocation: '/accept-invite', routes: [GoRoute(path: '/accept-invite', builder: (_, s) => AcceptInvitationScreen(token: s.uri.queryParameters['token']))]);
      await tester.pumpWidget(ProviderScope(
        overrides: [workspaceServiceProvider.overrideWithValue(db.workspaceService), invitationCheckServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(text(tester, 'invitation-message'), 'This link is not valid. Check that you opened the whole link.');
      expect(db.calls, isEmpty);
    });
  });

  group('an expired link', () {
    setUp(() => db.expired = true);

    testWidgets('offers to ask for a new one instead of an empty error', (tester) async {
      await open(tester);
      expect(text(tester, 'invitation-message'), 'This link has expired.');
      expect(text(tester, 'expired-summary'), startsWith('Door staff for Club Co'));
      expect(find.byKey(const Key('renew-request')), findsOneWidget);
      expect(find.byKey(const Key('code-title')), findsNothing, reason: 'a code is no use on a link that has ended');
      expect(pendingInviteToken.value, isNull);
    });

    testWidgets('asking tells the person who invited them, and says so', (tester) async {
      await open(tester);
      await tapKey(tester, 'renew-request');
      expect(db.calledWith('request_invitation_renewal').single, {'p_token': 'tok-abc', 'p_note': null});
      expect(text(tester, 'renewal-message'), startsWith('Done. The person who invited you has been told'));
      expect(text(tester, 'invitation-message'), 'This link has expired, and you have asked for a new one.');
      expect(find.byKey(const Key('renew-request')), findsNothing, reason: 'once is enough');
    });

    testWidgets('someone who already asked is told that, with no button', (tester) async {
      db.renewalRequested = true;
      await open(tester);
      expect(find.byKey(const Key('renew-request')), findsNothing);
      expect(find.byKey(const Key('renewal-asked')), findsOneWidget);
      expect(text(tester, 'invitation-message'), 'This link has expired, and you have asked for a new one.');
    });

    testWidgets('a failed request can be tried again', (tester) async {
      await open(tester);
      db.offline = true;
      await tapKey(tester, 'renew-request');
      expect(text(tester, 'renewal-message'), 'That could not be sent. Check your connection and try again.');
      expect(find.byKey(const Key('renew-request')), findsOneWidget);
      db.offline = false;
      await tapKey(tester, 'renew-request');
      expect(text(tester, 'renewal-message'), startsWith('Done.'));
    });
  });

  group('a server that does not have this yet', () {
    testWidgets('uses the link as it always did: no code step, no preview', (tester) async {
      db.previewAvailable = false;
      db.temporary = false;
      await open(tester);
      expect(text(tester, 'invitation-message'), 'You are in. Your workspace is ready.');
      expect(db.calledWith('accept_invitation'), hasLength(1));
    });

    testWidgets('and an expired link then says what it always said', (tester) async {
      db.previewAvailable = false;
      db.temporary = false;
      db.expired = true;
      await open(tester);
      expect(text(tester, 'invitation-message'), 'This link has expired. Ask the person who invited you to send a new one.');
      expect(find.byKey(const Key('renew-request')), findsNothing);
    });

    testWidgets('a dropped connection says something went wrong and can be tried again', (tester) async {
      db.offline = true;
      await open(tester);
      expect(text(tester, 'invitation-message'), 'Something went wrong. Check your connection and try again.');
      expect(pendingInviteToken.value, 'tok-abc', reason: 'the link is kept so it can be tried again');
      db.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('code-title')), findsOneWidget, reason: 'trying again looks at the link again');
    });
  });
}
