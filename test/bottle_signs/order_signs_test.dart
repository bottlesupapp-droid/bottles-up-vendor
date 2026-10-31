import 'dart:async';

import 'package:bottles_up_vendor/features/booking_detail/providers/booking_detail_providers.dart';
import 'package:bottles_up_vendor/features/bottle_signs/providers/bottle_sign_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_sign_backend.dart';

// The sign on an order card, in a night's orders: seeing it, adding one, approving or declining it, and the order not being offered on while a sign waits.

late FakeTableBackend orders;
late FakeSignBackend signs;
String? guestsAsk;

const serverWs = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.server, venueId: 'v1', venueName: 'Club A');
const managerWs = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Future<void> open(WidgetTester tester, Workspace ws) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      tableServiceServiceProvider.overrideWithValue(orders.service),
      bottleSignServiceProvider.overrideWithValue(signs.service),
      bookingSignProvider.overrideWith((ref, bookingId) async => guestsAsk),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: OrdersScreen(workspace: ws, clock: friday9pm))),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void waiting(String id, {String text = 'Cheers', String by = 'u-sam'}) {
  signs.lines[id]!
    ..text = text
    ..status = 'pending_review'
    ..setBy = by;
}

bool enabled(WidgetTester tester, String key) => tester.widget<FilledButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  setUp(() {
    guestsAsk = null;
    orders = FakeTableBackend();
    orders.now = DateTime(2026, 10, 9, 21);
    orders.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', total: 10000, paid: 6000);
    orders.addBooking('b2', name: 'Grace Hopper', code: 'EF34GH', table: 'Dance floor table', guests: 2, total: 5000, paid: 5000);
    orders.assignments['b1'] = 'm-me';
    orders.assignments['b2'] = 'm-me';
    orders.addLine('b1', 'Patron', lineId: 'l1', minutesAgo: 40);
    orders.addLine('b1', 'Grey Goose', lineId: 'l2', state: 'preparing', minutesAgo: 25, qty: 2);
    orders.addLine('b2', 'Don Julio', lineId: 'l4', state: 'served', minutesAgo: 90);

    signs = FakeSignBackend(role: 'server');
    signs.myTables.addAll(['b1', 'b2']);
    signs.mode = 'all';
    signs.bottles['p'] = FakeSignBottle('p', 'Patron');
    signs.bottles['g'] = FakeSignBottle('g', 'Grey Goose');
    signs.lines['l1'] = FakeSignLine('l1', 'b1', 'p', name: 'Patron');
    signs.lines['l2'] = FakeSignLine('l2', 'b1', 'g', name: 'Grey Goose', state: 'preparing', quantity: 2);
    signs.lines['l4'] = FakeSignLine('l4', 'b2', 'p', name: 'Don Julio', state: 'served');
  });

  group('seeing the sign', () {
    testWidgets('an order with a sign shows it; one that can take a sign offers to add it; a delivered one with none shows nothing', (tester) async {
      signs.lines['l1']!
        ..text = 'Happy Birthday'
        ..status = 'approved';
      await open(tester, serverWs);
      expect(find.text('Sign: “Happy Birthday”'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('sign-edit-l1')), matching: find.text('Change the sign')), findsOneWidget, reason: 'it has a sign');
      expect(find.descendant(of: find.byKey(const Key('sign-edit-l2')), matching: find.text('Add a sign')), findsOneWidget, reason: 'it has none');
      expect(find.byKey(const Key('sign-text-l4')), findsNothing);
      expect(find.byKey(const Key('sign-edit-l4')), findsNothing, reason: 'nothing can be added to what has been delivered');
      expect(signs.calledWith('desk_line_signs').single['p_lines'], containsAll(['l1', 'l2', 'l4']));
    });

    testWidgets('the state shows when approval is on, and not on a plain approved sign when it is off', (tester) async {
      signs.lines['l1']!
        ..text = 'Happy Birthday'
        ..status = 'approved';
      await open(tester, serverWs);
      expect(find.byKey(const Key('sign-status-l1')), findsNothing);
      signs.review = true;
      await open(tester, serverWs);
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('a delivered order still shows the sign it went out with, but cannot change it', (tester) async {
      signs.lines['l4']!
        ..text = 'Congrats'
        ..status = 'approved';
      await open(tester, serverWs);
      expect(find.text('Sign: “Congrats”'), findsOneWidget);
      expect(find.byKey(const Key('sign-edit-l4')), findsNothing);
    });

    testWidgets('a club that does not use signs shows nothing at all', (tester) async {
      signs.mode = 'off';
      await open(tester, serverWs);
      expect(find.byKey(const Key('sign-edit-l1')), findsNothing);
      expect(find.textContaining('Sign'), findsNothing);
    });

    testWidgets('in chosen-bottles mode only the chosen bottle offers a sign', (tester) async {
      signs.mode = 'selected';
      signs.bottles['p']!.eligible = true;
      await open(tester, serverWs);
      expect(find.byKey(const Key('sign-edit-l1')), findsOneWidget);
      expect(find.byKey(const Key('sign-edit-l2')), findsNothing);
    });

    testWidgets('a server that does not have bottle signs yet shows the orders as before, with no notice', (tester) async {
      signs.missing = true;
      await open(tester, serverWs);
      expect(find.byKey(const Key('order-l1')), findsOneWidget);
      expect(find.byKey(const Key('signs-notice')), findsNothing);
    });

    testWidgets('if the signs cannot be read the person is told, because a bottle must not go out without its sign unnoticed; Try again reads them', (tester) async {
      signs.offline = true;
      await open(tester, serverWs);
      expect(find.byKey(const Key('signs-notice')), findsOneWidget);
      expect(find.byKey(const Key('order-l1')), findsOneWidget, reason: 'the orders themselves are still there');
      signs.offline = false;
      signs.lines['l1']!
        ..text = 'Cheers'
        ..status = 'approved';
      await tapKey(tester, 'signs-notice-retry');
      expect(find.byKey(const Key('signs-notice')), findsNothing);
      expect(find.text('Sign: “Cheers”'), findsOneWidget);
    });
  });

  group('adding a sign', () {
    testWidgets('the sheet saves the words; the card shows them; a plain club says "saved"', (tester) async {
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      expect(find.text('Add a sign'), findsWidgets);
      expect(find.byKey(const Key('sign-sheet-for')), findsOneWidget);
      expect(find.byKey(const Key('sign-remove')), findsNothing, reason: 'there is no sign to remove yet');
      expect(tester.widget<FilledButton>(find.byKey(const Key('sign-save'))).onPressed, isNull, reason: 'nothing typed yet');
      await tester.enterText(find.byKey(const Key('sign-field')), '  Happy Birthday  ');
      await tester.pump();
      await tapKey(tester, 'sign-save');
      expect(signs.calledWith('desk_set_bottle_sign').single, {'p_line': 'l1', 'p_text': 'Happy Birthday'});
      expect(find.text('Sign saved.'), findsOneWidget);
      expect(find.text('Sign: “Happy Birthday”'), findsOneWidget);
      expect(find.byKey(const Key('sign-field')), findsNothing);
    });

    testWidgets('with approval on, a server is told a manager has to approve it, and the card says it is waiting', (tester) async {
      signs.review = true;
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      await tester.enterText(find.byKey(const Key('sign-field')), 'Cheers');
      await tester.pump();
      await tapKey(tester, 'sign-save');
      expect(find.text('Sign saved. A manager has to approve it before this is prepared.'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.byKey(const Key('sign-blocked-l1')), findsOneWidget);
    });

    testWidgets('what the guest asked for at checkout is offered, and one tap puts it in the box', (tester) async {
      guestsAsk = 'Happy 30th Sarah';
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      expect(find.byKey(const Key('sign-suggestion')), findsOneWidget);
      expect(find.text('The guest asked for this at checkout.'), findsOneWidget);
      await tapKey(tester, 'sign-use-suggestion');
      expect(tester.widget<TextField>(find.byKey(const Key('sign-field'))).controller!.text, 'Happy 30th Sarah');
      expect(find.byKey(const Key('sign-suggestion')), findsNothing, reason: 'it is in the box now');
    });

    testWidgets('the box takes 40 characters and no more', (tester) async {
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      await tester.enterText(find.byKey(const Key('sign-field')), 'x' * 55);
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('sign-field'))).controller!.text.length, 40);
    });

    testWidgets('no suggestion when the guest asked for nothing', (tester) async {
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      expect(find.byKey(const Key('sign-suggestion')), findsNothing);
    });

    testWidgets('changing a sign starts from the words that are there, and the same words again change nothing', (tester) async {
      signs.lines['l1']!
        ..text = 'Cheers'
        ..status = 'approved'
        ..setBy = signs.me;
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      expect(tester.widget<TextField>(find.byKey(const Key('sign-field'))).controller!.text, 'Cheers');
      expect(find.text('Change the sign'), findsWidgets);
      await tapKey(tester, 'sign-save');
      expect(find.text('Nothing changed.'), findsOneWidget);
    });

    testWidgets('removing the sign sends empty words and the card loses it', (tester) async {
      signs.lines['l1']!
        ..text = 'Cheers'
        ..status = 'approved';
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      await tapKey(tester, 'sign-remove');
      expect(signs.calledWith('desk_set_bottle_sign').single, {'p_line': 'l1', 'p_text': ''});
      expect(find.text('Sign removed.'), findsOneWidget);
      expect(find.byKey(const Key('sign-text-l1')), findsNothing);
    });

    testWidgets('a refusal from the database stays in the sheet in its own words, and the words typed are kept', (tester) async {
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      signs.mode = 'off';
      await tester.enterText(find.byKey(const Key('sign-field')), 'Cheers');
      await tester.pump();
      await tapKey(tester, 'sign-save');
      expect(find.text('Signs are not switched on for this club.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('sign-field'))).controller!.text, 'Cheers');
      expect(tester.widget<FilledButton>(find.byKey(const Key('sign-save'))).onPressed, isNotNull, reason: 'it can be tried again');
    });

    testWidgets('a second tap while it is saving sends nothing more', (tester) async {
      await open(tester, serverWs);
      await tapKey(tester, 'sign-edit-l1');
      await tester.enterText(find.byKey(const Key('sign-field')), 'Cheers');
      await tester.pump();
      signs.gates['desk_set_bottle_sign'] = Completer<void>();
      await tester.tap(find.byKey(const Key('sign-save')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('sign-save'))).onPressed, isNull);
      signs.gates['desk_set_bottle_sign']!.complete();
      await tester.pumpAndSettle();
      expect(signs.calledWith('desk_set_bottle_sign'), hasLength(1));
    });
  });

  group('the manager and a waiting sign', () {
    setUp(() {
      signs.role = 'manager';
      signs.review = true;
      waiting('l1');
    });

    testWidgets('a manager sees Approve and Decline on a waiting sign; a server does not', (tester) async {
      await open(tester, managerWs);
      expect(find.byKey(const Key('sign-approve-l1')), findsOneWidget);
      expect(find.byKey(const Key('sign-decline-l1')), findsOneWidget);
      signs.role = 'server';
      await open(tester, serverWs);
      expect(find.byKey(const Key('sign-approve-l1')), findsNothing);
      expect(find.byKey(const Key('sign-decline-l1')), findsNothing);
    });

    testWidgets('approving sends the approval and the card shows it approved', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'sign-approve-l1');
      expect(signs.calledWith('desk_review_bottle_sign').single, {'p_line': 'l1', 'p_decision': 'approve', 'p_note': null});
      expect(find.text('Sign approved.'), findsOneWidget);
      expect(find.byKey(const Key('sign-approve-l1')), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('declining with a reason shows the reason on the card, and the server is told to change the words', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'sign-decline-l1');
      await tester.enterText(find.byKey(const Key('decline-reason')), 'Check the spelling');
      await tapKey(tester, 'decline-confirm');
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Declined: Check the spelling'), findsOneWidget);
      expect(find.text('The sign was declined. Change the words so a manager can look again.'), findsOneWidget);
    });

    testWidgets('one\'s own waiting sign cannot be approved: the database\'s sentence is shown', (tester) async {
      waiting('l1', by: signs.me);
      await open(tester, managerWs);
      await tapKey(tester, 'sign-approve-l1');
      expect(find.text('Someone else has to review your sign.'), findsOneWidget);
      expect(find.byKey(const Key('sign-approve-l1')), findsOneWidget, reason: 'still waiting');
    });
  });

  group('an order is not offered on while its sign waits', () {
    setUp(() {
      signs.review = true;
    });

    testWidgets('the move into preparing is not offered; accepting still is; the reason is said', (tester) async {
      waiting('l2');
      await open(tester, serverWs);
      expect(enabled(tester, 'move-l2'), isFalse, reason: 'l2 is being prepared: the next step is Ready');
      expect(find.text('Waiting for a manager to approve the sign before this is prepared.'), findsOneWidget);
      // l1 is new: accepting it is fine even though nothing is waiting there; put a sign on it too.
      waiting('l1');
      await open(tester, serverWs);
      expect(enabled(tester, 'move-l1'), isTrue, reason: 'accepting is still fine');
      expect(find.byKey(const Key('sign-blocked-l1')), findsOneWidget);
    });

    testWidgets('the other steps in the menu are not offered either', (tester) async {
      waiting('l1');
      await open(tester, serverWs);
      await tapKey(tester, 'more-l1');
      expect(tester.widget<PopupMenuItem<dynamic>>(find.byKey(const Key('move-l1-preparing'))).enabled, isFalse);
      expect(tester.widget<PopupMenuItem<dynamic>>(find.byKey(const Key('move-l1-served'))).enabled, isFalse);
    });

    testWidgets('a declined sign stops it too, and once approved the order goes on', (tester) async {
      signs.role = 'manager';
      waiting('l2');
      signs.lines['l2']!.status = 'rejected';
      signs.lines['l2']!.note = 'Typo';
      await open(tester, managerWs);
      expect(enabled(tester, 'move-l2'), isFalse);
      expect(find.text('The sign was declined. Change the words so a manager can look again.'), findsOneWidget);
      signs.lines['l2']!.status = 'approved';
      await open(tester, managerWs);
      expect(enabled(tester, 'move-l2'), isTrue);
      expect(find.byKey(const Key('sign-blocked-l2')), findsNothing);
    });

    testWidgets('with approval off a waiting sign blocks nothing', (tester) async {
      signs.review = false;
      waiting('l2');
      await open(tester, serverWs);
      expect(enabled(tester, 'move-l2'), isTrue);
      expect(find.byKey(const Key('sign-blocked-l2')), findsNothing);
    });

    testWidgets('an order whose sign is approved, or with no sign, goes on', (tester) async {
      signs.lines['l2']!
        ..text = 'Cheers'
        ..status = 'approved';
      await open(tester, serverWs);
      expect(enabled(tester, 'move-l2'), isTrue);
      expect(enabled(tester, 'move-l1'), isTrue);
    });
  });
}
