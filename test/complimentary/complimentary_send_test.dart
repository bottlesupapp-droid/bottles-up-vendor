import 'package:bottles_up_vendor/features/complimentary/logic/complimentary_rules.dart';
import 'package:bottles_up_vendor/features/complimentary/providers/complimentary_providers.dart';
import 'package:bottles_up_vendor/features/complimentary/screens/complimentary_screen.dart';
import 'package:bottles_up_vendor/features/inventory/providers/inventory_providers.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_offers_backend.dart';

// E-mailing a complimentary offer's claim link (website 20261124100000_complimentary_send.sql and the send-complimentary-offer function; brief section 20). What matters: the button is offered only where
// the database would allow it; the person is asked first, with the address; the request carries only the offer's id; nothing is said as done until the server answered; every outcome has its own
// plain sentence and none shows the provider's words; the log of attempts is read from the database.
late FakeOffersBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

OfferRow row(String status, {String email = 'gina@x.example'}) => parseOfferRow(offerRow(status: status, email: email))!;

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      complimentaryServiceProvider.overrideWithValue(db.service),
      inventoryServiceProvider.overrideWithValue(db.inventory),
      ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')]),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: ComplimentaryScreen(workspace: manager))),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openSheetFor(WidgetTester tester, {String status = 'approved'}) async {
  db.offers = [offerRow(status: status)];
  await open(tester);
  await tapKey(tester, 'offer-o1');
}

FunctionException refused(int status, [String? error]) => FunctionException(status: status, details: error == null ? null : {'error': error});

void main() {
  setUp(() => db = FakeOffersBackend());

  group('when the link can be sent', () {
    test('only for an offer that is approved, sent or awaiting a location', () {
      const yes = {'approved', 'sent', 'awaiting_location'};
      for (final status in ['approved', 'sent', 'awaiting_location', 'location_submitted', 'accepted', 'delivered', 'expired', 'cancelled', 'weird']) {
        expect(canSendLink(row(status)), yes.contains(status), reason: status);
      }
    });

    test('the button says "again" once it has gone out', () {
      expect(sendButtonLabel(row('approved')), 'E-mail the link');
      expect(sendButtonLabel(row('sent')), 'E-mail the link again');
      expect(sendButtonLabel(row('awaiting_location')), 'E-mail the link again');
    });

    test('the question names the address, the gift and what it does, and warns that an earlier link stops', () {
      final first = sendConfirmText(row('approved'));
      expect(first, contains('one e-mail to gina@x.example'));
      expect(first, contains('2 × Patron · 750ml'));
      expect(first, contains('The link works once.'));
      expect(first, contains('Nothing is charged.'));
      expect(first, isNot(contains('stops working')));
      expect(sendConfirmText(row('sent')), contains('The link they were sent before stops working.'));
    });
  });

  group('the log of attempts', () {
    test('reads the database\'s columns, and drops what it cannot use', () {
      final s = parseOfferSend(sendRow(status: 'failed', failure: 'send_failed', first: false, mine: false))!;
      expect((s.id, s.toEmail, s.status, s.failure, s.firstSend, s.mine), ('s1', 'gina@x.example', 'failed', 'send_failed', false, false));
      expect(parseOfferSend({...sendRow(), 'id': null}), isNull);
      expect(parseOfferSend({...sendRow(), 'status': 'weird'}), isNull);
      expect(parseOfferSend({...sendRow(), 'status': null}), isNull);
    });

    test('says what happened, in words, and never what the provider said', () {
      expect(sendLine(parseOfferSend(sendRow(status: 'sent'))!), startsWith('E-mailed to gina@x.example · '));
      expect(sendLine(parseOfferSend(sendRow(status: 'pending'))!), startsWith('Sending to gina@x.example: no answer yet · '));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: 'send_failed'))!), contains('Not delivered'));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: 'send_failed'))!), endsWith(': send it again'));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: 'not_configured'))!), contains('e-mail is not set up on the server'));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: null))!), contains('Not delivered'));
    });

    test('a missing time leaves it out', () {
      expect(sendLine(parseOfferSend({...sendRow(), 'created_at': null})!), 'E-mailed to gina@x.example');
    });
  });

  group('what the e-mail function answered', () {
    test('is read as sent or not, with a reason that is one of the two', () {
      expect(parseLinkSendResult({'sent': true})!.sent, isTrue);
      expect(parseLinkSendResult({'sent': true, 'reason': 'send_failed'})!.reason, isNull, reason: 'a send that went has no reason');
      expect(parseLinkSendResult({'sent': false, 'reason': 'not_configured'})!.reason, 'not_configured');
      expect(parseLinkSendResult({'sent': false, 'reason': 'send_failed'})!.reason, 'send_failed');
      expect(parseLinkSendResult({'sent': false, 'reason': 'Resend said no'})!.reason, 'send_failed', reason: 'the provider\'s words are never passed on');
      expect(parseLinkSendResult({'sent': false})!.reason, 'send_failed');
      for (final bad in [null, 'x', 5, <String, dynamic>{}, {'sent': 'yes'}, {'ok': true}]) {
        expect(parseLinkSendResult(bad), isNull, reason: '$bad');
      }
    });

    test('has a sentence for each outcome, and only the success says it was e-mailed', () {
      expect(sendResultMessage(const LinkSendResult(sent: true, reason: null), 'gina@x.example'), 'The link was e-mailed to gina@x.example.');
      expect(sendResultMessage(const LinkSendResult(sent: false, reason: 'not_configured'), 'gina@x.example'), contains('nothing was sent'));
      expect(sendResultMessage(const LinkSendResult(sent: false, reason: 'send_failed'), 'gina@x.example'), 'The e-mail could not be delivered. Nothing is lost: try again.');
      expect(sendResultMessage(const LinkSendResult(sent: false, reason: 'not_configured'), 'gina@x.example'), isNot(contains('was e-mailed')));
    });
  });

  group('the service', () {
    test('asks the function with the offer\'s id and nothing else', () async {
      final r = await db.service.sendLink('o1');
      expect(r.sent, isTrue);
      expect(db.invokes.single.$1, 'send-complimentary-offer');
      expect(db.invokes.single.$2, {'offerId': 'o1'});
    });

    test('a send that failed is an answer, not an error', () async {
      db.invokeHandler = (n, b) => {'sent': false, 'reason': 'not_configured'};
      final r = await db.service.sendLink('o1');
      expect((r.sent, r.reason), (false, 'not_configured'));
    });

    test('a refusal is the function\'s own sentence', () async {
      db.invokeHandler = (n, b) => throw refused(409, 'A link cannot be sent for an offer that is expired.');
      await expectLater(db.service.sendLink('o1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'A link cannot be sent for an offer that is expired.')));
    });

    test('and with no sentence it is one for the status', () async {
      for (final (status, text) in [
        (401, 'Sign in again to send this link.'),
        (403, 'You cannot send this link.'),
        (429, 'This link was sent too often. Wait before sending it again.'),
        (500, 'The link could not be sent. Check your connection and look at the offer before trying again.'),
      ]) {
        db.invokeHandler = (n, b) => throw refused(status);
        await expectLater(db.service.sendLink('o1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', text)), reason: '$status');
      }
    });

    test('an answer that cannot be read, and a lost connection, are plain sentences', () async {
      db.invokeHandler = (n, b) => 'gibberish';
      await expectLater(db.service.sendLink('o1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The link could not be sent. Look at the offer before trying again.')));
      db.invokeHandler = null;
      db.offline = true;
      await expectLater(db.service.sendLink('o1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', startsWith('The link could not be sent. Check your connection'))));
    });

    test('the log is read from the database for that offer', () async {
      db.sends = [sendRow(), sendRow(id: 's2', status: 'failed', failure: 'send_failed')];
      final list = await db.service.sends('o1');
      expect(list.map((s) => s.id), ['s1', 's2']);
      expect(db.paramsOf('comp_offer_sends').single, {'p_offer': 'o1'});
    });
  });

  group('the offer\'s sheet', () {
    testWidgets('has the button on an approved offer, and not on one that has moved on', (tester) async {
      await openSheetFor(tester);
      expect(find.byKey(const Key('offer-action-send_link')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('offer-action-send_link')), matching: find.text('E-mail the link')), findsOneWidget);
    });

    for (final status in ['location_submitted', 'accepted', 'delivered', 'cancelled', 'expired']) {
      testWidgets('no button on an offer that is $status', (tester) async {
        await openSheetFor(tester, status: status);
        expect(find.byKey(const Key('offer-action-send_link')), findsNothing);
      });
    }

    testWidgets('says "again" on an offer already sent', (tester) async {
      await openSheetFor(tester, status: 'sent');
      expect(find.descendant(of: find.byKey(const Key('offer-action-send_link')), matching: find.text('E-mail the link again')), findsOneWidget);
    });

    testWidgets('asks first, with the address, and Back sends nothing', (tester) async {
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      expect(find.textContaining('gina@x.example'), findsWidgets);
      expect(tester.widget<Text>(find.byKey(const Key('offer-send-confirm'))).data, contains('one e-mail to gina@x.example'));
      await tapKey(tester, 'send-back');
      expect(db.invokes, isEmpty);
    });

    testWidgets('sends once on yes, with only the offer id, and says it was e-mailed after the answer', (tester) async {
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      await tapKey(tester, 'send-yes');
      expect(db.invokes.length, 1);
      expect(db.invokes.single.$1, 'send-complimentary-offer');
      expect(db.invokes.single.$2, {'offerId': 'o1'});
      expect(find.text('The link was e-mailed to gina@x.example.'), findsOneWidget);
    });

    testWidgets('success is not said before the server answers', (tester) async {
      var answered = false;
      final gate = Completer();
      db.invokeHandler = (n, b) async {
        await gate.future;
        answered = true;
        return {'sent': true};
      };
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      await tester.tap(find.byKey(const Key('send-yes')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('The link was e-mailed to gina@x.example.'), findsNothing, reason: 'nothing is said while it is still going');
      expect(answered, isFalse);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('The link was e-mailed to gina@x.example.'), findsOneWidget);
    });

    testWidgets('a send that failed is said as failed, never as sent', (tester) async {
      db.invokeHandler = (n, b) => {'sent': false, 'reason': 'send_failed'};
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      await tapKey(tester, 'send-yes');
      expect(find.text('The e-mail could not be delivered. Nothing is lost: try again.'), findsOneWidget);
      expect(find.textContaining('was e-mailed'), findsNothing);
    });

    testWidgets('e-mail not being set up is said in its own words', (tester) async {
      db.invokeHandler = (n, b) => {'sent': false, 'reason': 'not_configured'};
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      await tapKey(tester, 'send-yes');
      expect(find.textContaining('E-mail is not set up on the server, so nothing was sent.'), findsOneWidget);
    });

    testWidgets('a refusal is the function\'s own sentence', (tester) async {
      db.invokeHandler = (n, b) => throw refused(429, 'This link was sent 5 times in the last day: wait before sending it again.');
      await openSheetFor(tester);
      await tapKey(tester, 'offer-action-send_link');
      await tapKey(tester, 'send-yes');
      expect(find.text('This link was sent 5 times in the last day: wait before sending it again.'), findsOneWidget);
    });

    testWidgets('after a send the list is read again, and the log is read again the next time the sheet opens', (tester) async {
      await openSheetFor(tester);
      final listBefore = db.count('comp_offers_list');
      final logBefore = db.count('comp_offer_sends');
      await tapKey(tester, 'offer-action-send_link');
      await tapKey(tester, 'send-yes');
      expect(db.count('comp_offers_list'), greaterThan(listBefore), reason: 'the list shows what is true now');
      db.sends = [sendRow(id: 's9', status: 'sent')];
      await tester.pump(const Duration(milliseconds: 400)); // a person opens the offer again a moment later, not in the same instant (a card lets one tap through per double-tap time)
      await tapKey(tester, 'offer-o1');
      expect(db.count('comp_offer_sends'), greaterThan(logBefore), reason: 'the log is read when the sheet opens');
      expect(find.byKey(const Key('offer-send-s9')), findsOneWidget);
    });

    testWidgets('shows the latest attempts, three at most, in words', (tester) async {
      db.sends = [
        sendRow(id: 's4', status: 'failed', failure: 'send_failed', at: '2026-11-17T21:30:00Z'),
        sendRow(id: 's3', status: 'sent', at: '2026-11-17T21:20:00Z'),
        sendRow(id: 's2', status: 'pending', at: '2026-11-17T21:10:00Z'),
        sendRow(id: 's1', status: 'sent', at: '2026-11-17T21:00:00Z'),
      ];
      await openSheetFor(tester, status: 'sent');
      expect(find.byKey(const Key('offer-sends')), findsOneWidget);
      expect(find.byKey(const Key('offer-send-s4')), findsOneWidget);
      expect(find.byKey(const Key('offer-send-s3')), findsOneWidget);
      expect(find.byKey(const Key('offer-send-s2')), findsOneWidget);
      expect(find.byKey(const Key('offer-send-s1')), findsNothing, reason: 'three at most');
      expect(tester.widget<Text>(find.byKey(const Key('offer-send-s4'))).data, contains('Not delivered'));
      expect(tester.widget<Text>(find.byKey(const Key('offer-send-s3'))).data, startsWith('E-mailed to gina@x.example'));
      expect(tester.widget<Text>(find.byKey(const Key('offer-send-s2'))).data, startsWith('Sending to gina@x.example: no answer yet'));
    });

    testWidgets('with no attempts the log is not shown at all', (tester) async {
      await openSheetFor(tester);
      expect(find.byKey(const Key('offer-sends')), findsNothing);
    });

    testWidgets('an old server that has no send log leaves the sheet as it was', (tester) async {
      db.handlers['comp_offer_sends'] = (p) => throw PostgrestException(message: 'function public.comp_offer_sends does not exist', code: '42883');
      await openSheetFor(tester);
      expect(find.byKey(const Key('offer-sends')), findsNothing);
      expect(find.byKey(const Key('offer-action-send_link')), findsOneWidget);
    });
  });
}
