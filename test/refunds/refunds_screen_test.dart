import 'dart:async';

import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/refunds/providers/refund_providers.dart';
import 'package:bottles_up_vendor/features/refunds/screens/refunds_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_refund_backend.dart';

late FakeRefundBackend db;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget host({Workspace ws = manager}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        refundServiceProvider.overrideWithValue(db.service),
        ownerVenuesProvider.overrideWith((ref, orgId) async => [const OrgVenue(id: 'v1', name: 'Club A', status: 'published')]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: RefundsScreen(workspace: ws))),
    );

Future<void> open(WidgetTester tester, {Workspace ws = manager, double height = 3600}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ws: ws));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String lineOf(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('refund-line-$id'))).data!;
void main() {
  setUp(() {
    db = FakeRefundBackend();
    db.addBooking('b1', hours: 30);
  });

  testWidgets('lists the waiting requests first, each with the guest, the booking, the reason and what the policy suggests', (tester) async {
    final rq = db.addRequest('b1', reason: 'I am ill', percent: 50, suggested: 5000);
    await open(tester);
    expect(find.byKey(Key('refund-${rq.id}')), findsOneWidget);
    expect(find.text('Ada Lovelace · VIP booth'), findsOneWidget);
    expect(find.text('AB12CD · 2026-10-24'), findsOneWidget);
    expect(find.text('The guest: I am ill'), findsOneWidget);
    expect(find.text('Paid \$100.00 · The policy suggests 50% of the deposit: \$50.00.'), findsOneWidget);
    expect(lineOf(tester, rq.id), 'Waiting for your decision');
    expect(find.text('Waiting for a decision'), findsOneWidget);
    expect(db.paramsOf('desk_refund_requests').single, {'p_venue': 'v1', 'p_status': null});
  });

  testWidgets('a request made by staff says so', (tester) async {
    db.addRequest('b1', kind: 'staff', reason: 'Event cancelled');
    await open(tester);
    expect(find.text('Staff: Event cancelled'), findsOneWidget);
  });

  testWidgets('Open shows what needs someone; All shows everything, and each says why when there is nothing', (tester) async {
    final waiting = db.addRequest('b1');
    db.addBooking('b2');
    final done = db.addRequest('b2')
      ..status = 'completed'
      ..approved = 5000
      ..method = 'club';
    await open(tester);
    expect(find.byKey(Key('refund-${waiting.id}')), findsOneWidget);
    expect(find.byKey(Key('refund-${done.id}')), findsNothing);
    await tapKey(tester, 'refund-filter-all');
    expect(find.byKey(Key('refund-${done.id}')), findsOneWidget);
    expect(lineOf(tester, done.id), '\$50.00 paid back at the club');
  });

  testWidgets('nothing waiting says so, and no requests at all says that', (tester) async {
    await open(tester);
    expect(find.text('No refund is waiting for you.'), findsOneWidget);
    await tapKey(tester, 'refund-filter-all');
    expect(find.text('There are no refund requests yet.'), findsOneWidget);
  });

  testWidgets('the refund policy is one tap away', (tester) async {
    await open(tester);
    await tapKey(tester, 'open-policy');
    expect(find.text('Refund policy'), findsWidgets);
    expect(find.byKey(const Key('refund-policy')), findsOneWidget);
  });

  group('deciding', () {
    testWidgets('approving the suggestion for the card: the amount is filled in, BottlesUp returns it, and the list says so', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      expect(find.byKey(const Key('decide-sheet')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('decide-amount'))).controller!.text, '50.00');
      expect(find.text('Paid \$100.00 · can still be refunded \$100.00'), findsOneWidget);
      expect(find.text('The guests arrive in 30 hours.'), findsOneWidget);
      await tapKey(tester, 'method-online');
      await tapKey(tester, 'decide-confirm');
      expect(db.paramsOf('desk_decide_refund').single, {'p_request': rq.id, 'p_approve': true, 'p_amount_cents': 5000, 'p_method': 'online', 'p_note': null});
      expect(find.text('Approved: \$50.00. BottlesUp will return it to the guest\'s card.'), findsOneWidget);
      expect(lineOf(tester, rq.id), '\$50.00 approved: BottlesUp returns it to the guest\'s card');
      expect(find.byKey(Key('decide-${rq.id}')), findsNothing);
      expect(find.byKey(Key('record-club-${rq.id}')), findsNothing, reason: 'a card refund is not recorded by the club');
    });

    testWidgets('approving a refund paid back at the club offers to record it afterwards', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      await tapKey(tester, 'decide-confirm');
      expect(find.text('Approved: \$50.00. Pay it back at the club, then record it here.'), findsOneWidget);
      expect(find.byKey(Key('record-club-${rq.id}')), findsOneWidget);
    });

    testWidgets('more than the policy suggests needs a reason, said before anything is sent', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      await enter(tester, 'decide-amount', '80');
      await tapKey(tester, 'decide-confirm');
      expect(find.text('This is more than the refund policy suggests (\$50.00): say why.'), findsOneWidget);
      expect(db.paramsOf('desk_decide_refund'), isEmpty);
      await enter(tester, 'decide-note', 'Our mistake');
      await tapKey(tester, 'decide-confirm');
      expect(db.paramsOf('desk_decide_refund').single['p_amount_cents'], 8000);
      expect(db.paramsOf('desk_decide_refund').single['p_note'], 'Our mistake');
    });

    testWidgets('more than is left is refused before anything is sent', (tester) async {
      final rq = db.addRequest('b1', percent: 100, suggested: 10000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      await enter(tester, 'decide-amount', '150');
      await enter(tester, 'decide-note', 'Our mistake');
      await tapKey(tester, 'decide-confirm');
      expect(find.text('Only \$100.00 can still be refunded on this booking.'), findsOneWidget);
      expect(db.paramsOf('desk_decide_refund'), isEmpty);
    });

    testWidgets('a way of paying back must be chosen', (tester) async {
      final rq = db.addRequest('b1');
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'decide-confirm');
      expect(find.text('Choose how it is paid back: to the card through BottlesUp, or at the club.'), findsOneWidget);
    });

    testWidgets('a booking that was not paid online offers only the club', (tester) async {
      db.addBooking('b3', paidOnline: false, hours: 30);
      final rq = db.addRequest('b3', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      expect(find.byKey(const Key('decide-no-online')), findsOneWidget);
      expect(tester.widget<RadioListTile<dynamic>>(find.byKey(const Key('method-online'))).enabled, isFalse);
      await tester.tap(find.byKey(const Key('method-online')), warnIfMissed: false);
      await tester.pump();
      await tapKey(tester, 'decide-confirm');
      expect(find.text('Choose how it is paid back: to the card through BottlesUp, or at the club.'), findsOneWidget);
    });

    testWidgets('declining needs a reason and tells the guest', (tester) async {
      final rq = db.addRequest('b1');
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'decide-kind');
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('decide-amount')), findsNothing);
      await tapKey(tester, 'decide-confirm');
      expect(find.text('Say why the refund is declined, so the guest can be told.'), findsOneWidget);
      await enter(tester, 'decide-note', 'Too late to cancel');
      await tapKey(tester, 'decide-confirm');
      expect(db.paramsOf('desk_decide_refund').single, {'p_request': rq.id, 'p_approve': false, 'p_amount_cents': null, 'p_method': null, 'p_note': 'Too late to cancel'});
      expect(find.text('Declined. The guest will be told.'), findsOneWidget);
      expect(find.byKey(Key('refund-${rq.id}')), findsNothing, reason: 'a declined request is no longer waiting for anyone');
      await tapKey(tester, 'refund-filter-all');
      expect(lineOf(tester, rq.id), 'Declined: Too late to cancel');
    });

    testWidgets('someone else decided first: the refusal is shown and the list is read again', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      rq
        ..status = 'declined'
        ..note = 'Declined by a colleague';
      await tapKey(tester, 'decide-confirm');
      expect(find.text('This request has already been decided.'), findsOneWidget);
      expect(find.byKey(const Key('decide-sheet')), findsOneWidget);
    });

    testWidgets('a connection failure keeps the sheet and what was typed', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      await enter(tester, 'decide-note', 'Because');
      db.beforeCall = (f) {
        if (f == 'desk_decide_refund') throw Exception('socket closed');
      };
      await tapKey(tester, 'decide-confirm');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('decide-note'))).controller!.text, 'Because');
      expect(tester.widget<TextField>(find.byKey(const Key('decide-amount'))).controller!.text, '50.00');
    });

    testWidgets('a second tap on Approve while the first is going decides once', (tester) async {
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      await open(tester);
      await tapKey(tester, 'decide-${rq.id}');
      await tapKey(tester, 'method-club');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('decide-confirm')));
      await tester.tap(find.byKey(const Key('decide-confirm')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('decide-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_decide_refund'), hasLength(1));
    });
  });

  group('recording a refund paid back at the club', () {
    FakeRefundRequest approvedAtClub() => db.addRequest('b1')
      ..status = 'approved'
      ..approved = 5000
      ..method = 'club';

    testWidgets('the reference is the evidence: it is recorded, the request is paid back and the amount comes off the booking', (tester) async {
      final rq = approvedAtClub();
      await open(tester);
      expect(lineOf(tester, rq.id), '\$50.00 approved: pay it back at the club, then record it');
      await tapKey(tester, 'record-club-${rq.id}');
      expect(find.text('Paid back \$50.00 at the club'), findsOneWidget);
      await enter(tester, 'club-reference', ' TERM-123 ');
      await tapKey(tester, 'club-save');
      expect(db.paramsOf('desk_complete_club_refund').single, {'p_request': rq.id, 'p_pos_reference': 'TERM-123', 'p_receipt_path': null});
      expect(find.text('Recorded: \$50.00 paid back at the club.'), findsOneWidget);
      expect(db.bookings['b1']!.paid, 5000);
      expect(find.byKey(Key('record-club-${rq.id}')), findsNothing);
    });

    testWidgets('without a reference nothing is sent', (tester) async {
      final rq = approvedAtClub();
      await open(tester);
      await tapKey(tester, 'record-club-${rq.id}');
      await tapKey(tester, 'club-save');
      expect(find.text('Add the terminal or receipt reference as evidence.'), findsOneWidget);
      expect(db.paramsOf('desk_complete_club_refund'), isEmpty);
    });

    testWidgets('Not yet closes it and records nothing', (tester) async {
      final rq = approvedAtClub();
      await open(tester);
      await tapKey(tester, 'record-club-${rq.id}');
      await tapKey(tester, 'club-cancel');
      expect(find.byKey(const Key('club-reference')), findsNothing);
      expect(db.paramsOf('desk_complete_club_refund'), isEmpty);
    });

    testWidgets('a refusal is shown in the dialog and the reference stays', (tester) async {
      final rq = approvedAtClub();
      await open(tester);
      await tapKey(tester, 'record-club-${rq.id}');
      await enter(tester, 'club-reference', 'TERM-123');
      db.role = 'server';
      await tapKey(tester, 'club-save');
      expect(find.text('You don\'t have access to do that.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('club-reference'))).controller!.text, 'TERM-123');
    });

    testWidgets('a second tap while the first is going records once', (tester) async {
      final rq = approvedAtClub();
      await open(tester);
      await tapKey(tester, 'record-club-${rq.id}');
      await enter(tester, 'club-reference', 'TERM-123');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('club-save')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_complete_club_refund'), hasLength(1));
      expect(db.bookings['b1']!.paid, 5000);
    });
  });

  group('other states', () {
    testWidgets('an approved card refund waits for BottlesUp and has no button; one being returned says so; a failed one is shown with its reason', (tester) async {
      db.addBooking('b2');
      db.addBooking('b3');
      final waits = db.addRequest('b1')
        ..status = 'approved'
        ..approved = 5000
        ..method = 'online';
      final going = db.addRequest('b2')
        ..status = 'processing'
        ..approved = 5000
        ..method = 'online';
      final failed = db.addRequest('b3')
        ..status = 'failed'
        ..approved = 5000
        ..method = 'online'
        ..failure = 'Card closed';
      await open(tester);
      expect(lineOf(tester, waits.id), '\$50.00 approved: BottlesUp returns it to the guest\'s card');
      expect(lineOf(tester, going.id), '\$50.00 is being returned to the guest\'s card');
      expect(lineOf(tester, failed.id), 'The card refund did not go through: Card closed. BottlesUp has been told.');
      for (final r in [waits, going, failed]) {
        expect(find.byKey(Key('decide-${r.id}')), findsNothing);
        expect(find.byKey(Key('record-club-${r.id}')), findsNothing);
      }
    });

    testWidgets('a failed read says so with Try again', (tester) async {
      db.failAll = Exception('boom');
      await open(tester);
      expect(find.byKey(const Key('refunds-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.failAll = null;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('refunds-error')), findsNothing);
    });

    testWidgets('someone without the right is told so, with no retry', (tester) async {
      db.role = 'server';
      await open(tester);
      expect(find.byKey(const Key('refunds-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsOneWidget, reason: 'access ended is shown with the same message');
    });

    testWidgets('pulling down reads the list again', (tester) async {
      await open(tester, height: 700);
      final before = db.paramsOf('desk_refund_requests').length;
      await tester.drag(find.byKey(const Key('refunds')), const Offset(0, 500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_refund_requests').length, greaterThan(before));
    });
  });

  group('for an owner', () {
    testWidgets('the owner picks the club first, then sees that club\'s refunds', (tester) async {
      db.addRequest('b1');
      await open(tester, ws: owner);
      expect(find.byKey(const Key('refunds-pick-club')), findsOneWidget);
      expect(db.paramsOf('desk_refund_requests'), isEmpty);
      await tapKey(tester, 'refunds-club-v1');
      expect(find.byKey(const Key('refunds')), findsOneWidget);
      expect(db.paramsOf('desk_refund_requests').single['p_venue'], 'v1');
    });
  });
}
