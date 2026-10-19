import 'package:bottles_up_vendor/features/seating/providers/seating_providers.dart';
import 'package:bottles_up_vendor/features/seating/screens/server_scan_screen.dart';
import 'package:bottles_up_vendor/features/seating/widgets/seating_panel.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_seating_backend.dart';

late FakeSeatingBackend db;

Workspace ws({String? venueId = 'v1'}) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: WorkspaceRole.server,
      venueId: venueId,
      venueName: 'Club A',
    );

DateTime fridayNight() => DateTime(2026, 10, 9, 21, 42);

/// Stands in for the camera: a button that "reads" whatever code the test puts in [scanned].
String scanned = 'ADA111';
Widget fakeCamera(BuildContext context, ValueChanged<String> onCode) =>
    Center(child: ElevatedButton(key: const Key('fake-scan'), onPressed: () => onCode(scanned), child: const Text('scan')));

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [seatingServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUp(() {
    db = FakeSeatingBackend();
    db.bookings
      ..add(FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace'))
      ..add(FakeSeatBooking('b2', 'ANN333', 'Ada Annan', table: 'Terrace', guests: 2, start: '23:00:00'))
      ..add(FakeSeatBooking('b3', 'GRC222', 'Grace Hopper', owner: 'other'));
    scanned = 'ADA111';
  });

  Widget scan() => ServerScanScreen(workspace: ws(), clock: fridayNight, cameraBuilder: fakeCamera);

  group('Scan (server)', () {
    testWidgets('scanning a booking finds it and seats the guest with one confirmation, with an estimate', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');

      expect(db.calledWith('desk_find_booking').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_query': 'ADA111'});
      expect(tester.widget<Text>(find.byKey(const Key('seat-heading'))).data, 'Ada Lovelace');
      expect(find.textContaining('VIP booth · 4 guests · 9:00 PM · ADA111'), findsOneWidget);
      expect(find.byKey(const Key('detail-field')), findsNothing, reason: 'a scan needs no second detail');

      await typeIn(tester, 'estimate-field', '25');
      await tapKey(tester, 'seat-confirm');

      expect(db.calledWith('desk_mark_seated').single, {'p_booking': 'b1', 'p_method': 'scan', 'p_confirmation': null, 'p_estimate_minutes': 25});
      expect(find.text('Ada Lovelace is seated. Estimate: 25 min. The guest\'s confirmation is queued.'), findsOneWidget);
      expect(db.bookings.first.seated, isTrue);
    });

    testWidgets('seating without an estimate is fine', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      await tapKey(tester, 'seat-confirm');
      expect(db.calledWith('desk_mark_seated').single['p_estimate_minutes'], isNull);
      expect(find.text('Ada Lovelace is seated. The guest\'s confirmation is queued.'), findsOneWidget);
    });

    testWidgets('a bad estimate is stopped in the dialog and nothing is sent', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      await typeIn(tester, 'estimate-field', '900');
      await tapKey(tester, 'seat-confirm');
      expect(find.byKey(const Key('seat-error')), findsOneWidget);
      expect(find.textContaining('between 1 and 480'), findsOneWidget);
      expect(db.calledWith('desk_mark_seated'), isEmpty);
      await typeIn(tester, 'estimate-field', '30');
      expect(find.byKey(const Key('seat-error')), findsNothing, reason: 'typing clears the message');
    });

    testWidgets('backing out of the dialog seats nobody', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      await tapKey(tester, 'seat-back');
      expect(db.calledWith('desk_mark_seated'), isEmpty);
      expect(db.bookings.first.seated, isFalse);
    });

    testWidgets('a code that is not this server\'s table finds nothing and says what to do', (tester) async {
      scanned = 'GRC222';
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      expect(find.byKey(const Key('scan-message')), findsOneWidget);
      expect(find.textContaining('No booking found for you tonight'), findsOneWidget);
      expect(find.byKey(const Key('seat-heading')), findsNothing);
    });

    testWidgets('the same code held up again is read once', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      await tapKey(tester, 'seat-back');
      await tester.tap(find.byKey(const Key('fake-scan')));
      await tester.pumpAndSettle();
      expect(db.calledWith('desk_find_booking'), hasLength(1), reason: 'the cooldown stops a camera that keeps seeing the same QR');
    });

    testWidgets('an already seated guest says so and offers no second seating', (tester) async {
      db.bookings.first.seated = true;
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      expect(find.byKey(const Key('seat-already')), findsOneWidget);
      expect(find.byKey(const Key('seat-confirm')), findsNothing);
      await tapKey(tester, 'seat-back');
      expect(db.calledWith('desk_mark_seated'), isEmpty);
    });

    testWidgets('a table the database says is not theirs cannot be seated', (tester) async {
      db.cannotSeat = true;
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      expect(find.byKey(const Key('seat-blocked')), findsOneWidget);
      expect(find.text('This table is not yours. Ask the manager.'), findsOneWidget);
      expect(find.byKey(const Key('seat-confirm')), findsNothing);
    });

    testWidgets('typing a name lists the matches; picking one needs another detail checked with the guest', (tester) async {
      await open(tester, scan());
      await typeIn(tester, 'scan-search', 'ada');
      await tapKey(tester, 'scan-search-go');
      expect(db.calledWith('desk_find_booking').single['p_query'], 'ada');
      expect(find.byKey(const Key('match-b1')), findsOneWidget);
      expect(find.byKey(const Key('match-b2')), findsOneWidget);
      expect(find.byKey(const Key('match-b3')), findsNothing, reason: 'another server\'s Grace is not offered');

      await tapKey(tester, 'match-b2');
      expect(find.byKey(const Key('detail-field')), findsOneWidget);
      await tapKey(tester, 'seat-confirm');
      expect(find.textContaining('Say what you checked with the guest'), findsOneWidget);
      expect(db.calledWith('desk_mark_seated'), isEmpty, reason: 'a name alone does not seat anyone');

      await typeIn(tester, 'detail-field', 'asked for her email');
      await tapKey(tester, 'seat-confirm');
      expect(db.calledWith('desk_mark_seated').single, {'p_booking': 'b2', 'p_method': 'manual', 'p_confirmation': 'asked for her email', 'p_estimate_minutes': null});
      expect(find.text('Ada Annan is seated. The guest\'s confirmation is queued.'), findsOneWidget);
      expect(find.byKey(const Key('match-b1')), findsNothing, reason: 'the list is cleared once someone is seated');
    });

    testWidgets('a name with fewer than 3 letters sends nothing', (tester) async {
      await open(tester, scan());
      await typeIn(tester, 'scan-search', 'ad');
      await tapKey(tester, 'scan-search-go');
      expect(find.byKey(const Key('scan-problem')), findsOneWidget);
      expect(find.textContaining('at least 3 letters'), findsOneWidget);
      expect(db.calls, isEmpty);
    });

    testWidgets('the keyboard\'s search key works like the button', (tester) async {
      await open(tester, scan());
      await typeIn(tester, 'scan-search', 'ada111');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(db.calledWith('desk_find_booking').single['p_query'], 'ada111');
      expect(find.byKey(const Key('match-b1')), findsOneWidget);
    });

    testWidgets('a booking seated by someone else meanwhile: the database\'s sentence is shown', (tester) async {
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      db.bookings.first.status == 'paid';
      db.role = 'server';
      db.bookings.removeAt(0); // the table disappears from this server (reassigned) before the tap
      db.bookings.insert(0, FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace', owner: 'other'));
      await tapKey(tester, 'seat-confirm');
      expect(find.byKey(const Key('scan-problem')), findsOneWidget);
      expect(find.text("You don't have access to do that."), findsOneWidget);
    });

    testWidgets('a dropped connection on a search says so, in words', (tester) async {
      db.offline = true;
      await open(tester, scan());
      await tapKey(tester, 'fake-scan');
      expect(find.text('The search could not be done. Check your connection and try again.'), findsOneWidget);
    });

    testWidgets('a workspace with no club shows nothing and asks for nothing', (tester) async {
      await open(tester, ServerScanScreen(workspace: ws(venueId: null), clock: fridayNight, cameraBuilder: fakeCamera));
      expect(find.byKey(const Key('scan-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
    });

    testWidgets('after midnight it is still the night before', (tester) async {
      await open(tester, ServerScanScreen(workspace: ws(), clock: () => DateTime(2026, 10, 10, 1, 15), cameraBuilder: fakeCamera));
      await tapKey(tester, 'fake-scan');
      expect(db.calledWith('desk_find_booking').single['p_night'], '2026-10-09');
    });
  });

  group('the table\'s seating panel', () {
    Widget panel({bool canUnseat = false}) => SeatingPanel(bookingId: 'b1', title: 'VIP booth · Ada Lovelace', canUnseat: canUnseat);

    testWidgets('a guest not seated yet can be seated by hand, with the detail checked and an estimate', (tester) async {
      await open(tester, panel());
      expect(find.text('Guest not seated yet'), findsOneWidget);
      expect(find.byKey(const Key('panel-unseat')), findsNothing);

      await tapKey(tester, 'panel-seat');
      await tapKey(tester, 'seat-confirm');
      expect(find.textContaining('Say what you checked'), findsOneWidget);
      await typeIn(tester, 'detail-field', 'saw their booking email');
      await typeIn(tester, 'estimate-field', '20');
      await tapKey(tester, 'seat-confirm');

      expect(db.calledWith('desk_mark_seated').single, {'p_booking': 'b1', 'p_method': 'manual', 'p_confirmation': 'saw their booking email', 'p_estimate_minutes': 20});
      expect(find.text('Seated. The guest\'s confirmation is queued.'), findsOneWidget);
      expect(find.textContaining('Seated at 9:42 PM'), findsOneWidget);
      expect(find.text('Service estimate: 20 min'), findsOneWidget);
      expect(find.text('Arrival confirmation: Queued, not sent yet'), findsOneWidget, reason: 'never worded as delivered');
      expect(find.textContaining('(checked by hand)'), findsOneWidget);
    });

    testWidgets('the estimate can be changed and cleared; a change queues an update for the guest', (tester) async {
      db.bookings.first
        ..seated = true
        ..seatedAt = fridayNight()
        ..method = 'scan'
        ..estimate = 20
        ..seatedBy = 'Me Myself';
      await open(tester, panel());
      expect(find.text('Service estimate: 20 min'), findsOneWidget);

      await tapKey(tester, 'estimate-change');
      expect(find.text('It is 20 min now.'), findsOneWidget);
      await typeIn(tester, 'text-field', 'soon');
      await tapKey(tester, 'dialog-confirm');
      expect(find.textContaining('between 1 and 480'), findsOneWidget);
      await typeIn(tester, 'text-field', '45');
      await tapKey(tester, 'dialog-confirm');
      expect(db.calledWith('desk_set_estimate').single, {'p_booking': 'b1', 'p_minutes': 45});
      expect(find.text('Service estimate: 45 min'), findsOneWidget);
      expect(find.text('Service estimate update: Queued, not sent yet'), findsOneWidget);

      await tapKey(tester, 'estimate-change');
      await tester.enterText(find.byKey(const Key('text-field')), '');
      await tapKey(tester, 'dialog-confirm');
      expect(db.calledWith('desk_set_estimate').last['p_minutes'], isNull);
      expect(find.text('No service estimate yet'), findsOneWidget);
    });

    testWidgets('a manager can un-seat with a reason', (tester) async {
      db.role = 'manager';
      db.bookings.first
        ..seated = true
        ..seatedAt = fridayNight()
        ..method = 'scan'
        ..seatedBy = 'Me Myself';
      await open(tester, panel(canUnseat: true));
      await tapKey(tester, 'panel-unseat');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why this guest is being un-seated.'), findsOneWidget);
      expect(db.calledWith('desk_unseat'), isEmpty);
      await typeIn(tester, 'text-field', 'tapped the wrong table');
      await tapKey(tester, 'dialog-confirm');
      expect(db.calledWith('desk_unseat').single, {'p_booking': 'b1', 'p_reason': 'tapped the wrong table'});
      expect(find.text('Guest not seated yet'), findsOneWidget);
    });

    testWidgets('a server is not offered Un-seat', (tester) async {
      db.bookings.first.seated = true;
      db.bookings.first.seatedAt = fridayNight();
      await open(tester, panel());
      expect(find.byKey(const Key('panel-unseat')), findsNothing);
    });

    testWidgets('a failed message says failed, with the reason', (tester) async {
      db.bookings.first
        ..seated = true
        ..seatedAt = fridayNight();
      db.outbox.add(FakeMessage('b1', 'seated_ack', status: 'failed', error: 'mailbox full'));
      await open(tester, panel());
      expect(find.text('Arrival confirmation: Failed: mailbox full'), findsOneWidget);
    });

    testWidgets('a server without the seating functions shows no panel; any other failure is said', (tester) async {
      db.missing = true;
      await open(tester, panel());
      expect(find.byKey(const Key('seating-panel')), findsNothing);
      expect(find.byKey(const Key('seating-error')), findsNothing);

      db.missing = false;
      db.offline = true;
      await open(tester, panel());
      expect(find.byKey(const Key('seating-error')), findsOneWidget);
    });

    testWidgets('seating a guest who was seated meanwhile says nothing changed', (tester) async {
      await open(tester, panel());
      db.bookings.first
        ..seated = true
        ..seatedAt = fridayNight();
      await tapKey(tester, 'panel-seat');
      await typeIn(tester, 'detail-field', 'saw their booking email');
      await tapKey(tester, 'seat-confirm');
      expect(find.text('This guest was already seated. Nothing changed.'), findsOneWidget);
    });
  });
}
