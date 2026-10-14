import 'dart:async';

import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_floor_backend.dart';

late FakeFloorBackend db;

/// A Friday evening: the business night is Friday 9 October 2026.
DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({
  String? venueId = 'v1',
  DateTime Function()? clock,
  NightPicker? pick,
  Future<void> Function(Uri)? contact,
}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [floorServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FloorScreen(
            venueId: venueId,
            venueName: 'Club A',
            clock: clock ?? friday9pm,
            pickNight: pick ?? (c, i) async => null,
            contact: contact ?? (u) async {},
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

/// Scrolls a link into view, lets the scroll finish, and taps it.
Future<void> tapLink(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  setUp(() {
    db = FakeFloorBackend();
    db.onList = (_) => [
          bookingRow('b1', phone: '+1 555 0100', total: 120000, deposit: 30000, code: 'AB12CD', checkedInAt: '2026-10-09T22:00:00Z', label: 'Evening'),
          bookingRow('b2', name: 'Grace Hopper', table: 'Dance floor table', guests: 4, email: 'grace@example.com', code: 'EF34GH'),
          bookingRow('b3', name: 'Linus Torvalds', guests: 8, status: 'pending', email: 'linus@example.com'),
        ];
  });

  testWidgets('opens on tonight, for the manager\'s own club, and shows who is coming', (tester) async {
    await open(tester, host());

    expect(db.params, [
      {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-09'},
    ]);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Club A'), findsOneWidget);
    expect(find.byKey(const Key('night-2026-10-09')), findsOneWidget);
    expect(find.text('Friday Oct 9'), findsOneWidget);
    expect(find.text('8 guests expected'), findsOneWidget, reason: 'the pending party is not counted');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('VIP booth · 4 guests'), findsNWidgets(1));
    expect(find.text('9:00 PM'), findsWidgets);
    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.text('Booked \$1200.00 CAD · deposit \$300.00 CAD'), findsOneWidget);
    expect(find.text('Booked \$400.00 CAD'), findsOneWidget, reason: 'no deposit, so none is mentioned (not "deposit \$0.00")');
  });

  testWidgets('counts: confirmed bookings, guests, arrived, awaiting payment', (tester) async {
    await open(tester, host());
    String value(String key) => ((tester.widget(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)) as Text).data!;
    expect(value('tile-confirmed'), '2');
    expect(value('tile-guests'), '8');
    expect(value('tile-arrived'), '1');
    expect(value('tile-awaiting'), '1');
    expect(find.text('1 night'), findsOneWidget);
  });

  testWidgets('"Confirmed only" hides the unpaid; "Everything" shows them with their own status', (tester) async {
    await open(tester, host());
    expect(find.byKey(const Key('booking-b3')), findsNothing);

    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-b3')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('status-b3')), matching: find.text('Awaiting payment')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('status-b1')), matching: find.text('Confirmed')), findsOneWidget);
    expect(db.calls, hasLength(1), reason: 'the filter is applied on the phone, not asked of the database again');
  });

  testWidgets('only a confirmed guest who has arrived is marked "Arrived"', (tester) async {
    db.onList = (_) => [
          bookingRow('b1', checkedInAt: '2026-10-09T22:00:00Z'),
          bookingRow('b2', status: 'cancelled', checkedInAt: '2026-10-09T22:00:00Z'),
        ];
    await open(tester, host());
    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arrived')), findsOneWidget);
  });

  testWidgets('when everything is unpaid it says so, and says how many are hidden', (tester) async {
    db.onList = (_) => [bookingRow('b1', status: 'cancelled'), bookingRow('b2', status: 'pending')];
    await open(tester, host());
    expect(find.textContaining('No confirmed bookings for these nights. 2 unpaid or cancelled are hidden'), findsOneWidget);

    db.onList = (_) => [bookingRow('b1', status: 'cancelled')];
    await open(tester, host());
    expect(find.textContaining('1 unpaid or cancelled is hidden'), findsOneWidget);
  });

  testWidgets('no bookings at all says so plainly', (tester) async {
    db.onList = (_) => <dynamic>[];
    await open(tester, host());
    expect(find.text('No bookings for these nights.'), findsOneWidget);
    expect(find.byKey(const Key('tile-confirmed')), findsOneWidget);
  });

  testWidgets('at 1:30 AM on Saturday "Tonight" is still Friday night', (tester) async {
    await open(tester, host(clock: () => DateTime(2026, 10, 10, 1, 30)));
    expect(db.params.single, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-09'});
  });

  testWidgets('the ready-made ranges ask for the right nights', (tester) async {
    await open(tester, host());
    for (final (key, from, to) in [
      ('preset-next7', '2026-10-09', '2026-10-15'),
      ('preset-next30', '2026-10-09', '2026-11-07'),
      ('preset-last7', '2026-10-02', '2026-10-08'),
      ('preset-tonight', '2026-10-09', '2026-10-09'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(db.params.last, {'p_venue': 'v1', 'p_from': from, 'p_to': to}, reason: key);
    }
  });

  testWidgets('a night picked by hand replaces the ready-made range', (tester) async {
    await open(
      tester,
      host(pick: (context, initial) async => DateTime(2026, 10, 16)),
    );
    await tester.tap(find.byKey(const Key('pick-to')));
    await tester.pumpAndSettle();

    expect(db.params.last, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-16'});
    expect(find.descendant(of: find.byKey(const Key('pick-to')), matching: find.text('Fri Oct 16')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pick-from')), matching: find.text('Fri Oct 9')), findsOneWidget);
    final tonight = tester.widget<ChoiceChip>(find.byKey(const Key('preset-tonight')));
    expect(tonight.selected, isFalse);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await open(tester, host());
    await tester.tap(find.byKey(const Key('pick-from')));
    await tester.pumpAndSettle();
    expect(db.calls, hasLength(1));
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('preset-tonight'))).selected, isTrue);
  });

  testWidgets('an end before the start is explained, asks nothing, and shows no stale numbers; fixing it brings them back', (tester) async {
    var next = DateTime(2026, 10, 1);
    await open(tester, host(pick: (c, i) async => next));
    await tester.tap(find.byKey(const Key('pick-to')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('range-problem')), findsOneWidget);
    expect(find.text('The end date is before the start date.'), findsOneWidget);
    expect(db.calls, hasLength(1), reason: 'no request for a range the database would refuse');
    expect(find.byKey(const Key('tile-confirmed')), findsNothing, reason: 'the numbers of the old range must not stay under a warning about the new one');
    expect(find.byKey(const Key('floor-error')), findsNothing, reason: 'a range problem is not a load failure');
    expect(find.byType(CircularProgressIndicator), findsNothing);

    next = DateTime(2026, 10, 12);
    await tester.tap(find.byKey(const Key('pick-to')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('range-problem')), findsNothing);
    expect(db.params.last, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-12'});
    expect(find.byKey(const Key('tile-confirmed')), findsOneWidget);
  });

  testWidgets('more than 93 nights is refused with the reason', (tester) async {
    await open(tester, host(pick: (c, i) async => DateTime(2027, 3, 1)));
    await tester.tap(find.byKey(const Key('pick-to')));
    await tester.pumpAndSettle();
    expect(find.text('Choose at most 93 nights at a time.'), findsOneWidget);
    expect(db.calls, hasLength(1));
  });

  testWidgets('a full page of 1000 bookings warns there may be more', (tester) async {
    db.onList = (_) => [for (var i = 0; i < 1000; i++) bookingRow('b$i', name: 'Guest $i')];
    await open(tester, host());
    expect(find.byKey(const Key('row-limit')), findsOneWidget);
    expect(find.textContaining('Only the first 1000 bookings are shown'), findsOneWidget);

    db.onList = (_) => [for (var i = 0; i < 999; i++) bookingRow('b$i')];
    await open(tester, host());
    expect(find.byKey(const Key('row-limit')), findsNothing);
  });

  testWidgets('several nights are grouped under their own heading with their own guest count', (tester) async {
    db.onList = (_) => [
          bookingRow('b1', night: '2026-10-09', guests: 4),
          bookingRow('b2', night: '2026-10-10', guests: 6),
          bookingRow('b3', night: '2026-10-10', guests: 1),
        ];
    await open(tester, host());
    await tester.tap(find.byKey(const Key('preset-next7')));
    await tester.pumpAndSettle();
    expect(find.text('Friday Oct 9'), findsOneWidget);
    expect(find.text('4 guests expected'), findsOneWidget);
    expect(find.text('Saturday Oct 10'), findsOneWidget);
    expect(find.text('7 guests expected'), findsOneWidget);
  });

  testWidgets('the footnote says amounts are what was booked, not collected', (tester) async {
    await open(tester, host());
    await tester.scrollUntilVisible(find.byKey(const Key('floor-footnote')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('what was booked, not what has been collected'), findsOneWidget);
  });

  group('contacting a guest', () {
    testWidgets('the phone and the email open as a call and a message', (tester) async {
      final opened = <Uri>[];
      await open(tester, host(contact: (u) async => opened.add(u)));
      await tapLink(tester, 'phone-b1');
      await tapLink(tester, 'email-b2');
      expect(opened.map((u) => u.scheme), ['tel', 'mailto']);
      expect(opened.first.toString(), 'tel:+15550100');
      expect(opened.last.path, 'grace@example.com');
    });

    testWidgets('a phone that cannot open it says so', (tester) async {
      await open(tester, host(contact: (u) async => throw Exception('no handler')));
      await tapLink(tester, 'phone-b1');
      expect(find.text('This could not be opened on this phone.'), findsOneWidget);
    });

    testWidgets('a guest with no phone has no phone link', (tester) async {
      await open(tester, host());
      expect(find.byKey(const Key('phone-b2')), findsNothing);
      expect(find.byKey(const Key('email-b2')), findsOneWidget);
    });
  });

  group('when it cannot load', () {
    testWidgets('a failure offers a retry that works', (tester) async {
      var fail = true;
      db.onList = (_) => fail ? throw Exception('offline') : [bookingRow('b1')];
      await open(tester, host());
      expect(find.byKey(const Key('floor-error')), findsOneWidget);
      expect(find.textContaining('try again'), findsOneWidget);

      fail = false;
      await tester.tap(find.byKey(const Key('floor-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('a server without the migration says so, with no pointless retry', (tester) async {
      db.onList = (_) => throw const PostgrestException(message: 'no function', code: '42883');
      await open(tester, host());
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('floor-retry')), findsNothing);
    });

    testWidgets('a manager whose access ended is told so', (tester) async {
      db.onList = (_) => throw const PostgrestException(message: 'not allowed', code: 'P0001');
      await open(tester, host());
      expect(find.textContaining('access has ended'), findsOneWidget);
    });

    testWidgets('a workspace not tied to a club shows nothing to fetch', (tester) async {
      await open(tester, host(venueId: null));
      expect(find.byKey(const Key('floor-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
      await open(tester, host(venueId: ''));
      expect(find.byKey(const Key('floor-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
    });
  });

  testWidgets('pulling down reads the bookings again', (tester) async {
    await open(tester, host());
    expect(db.calls, hasLength(1));
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(db.calls.length, greaterThanOrEqualTo(2));
  });

  testWidgets('a slow answer for an older range never replaces a newer one', (tester) async {
    final slow = Completer<dynamic>();
    var call = 0;
    db.onList = (p) {
      call++;
      return call == 1 ? slow.future : [bookingRow('new', name: 'Newer Night', night: '2026-10-09')];
    };
    await tester.pumpWidget(host());
    await tester.pump(); // first read starts and hangs
    await tester.tap(find.byKey(const Key('preset-next7')));
    await tester.pumpAndSettle();
    expect(find.text('Newer Night'), findsOneWidget);

    slow.complete([bookingRow('old', name: 'Older Night')]);
    await tester.pumpAndSettle();
    expect(find.text('Older Night'), findsNothing);
    expect(find.text('Newer Night'), findsOneWidget);
  });
}
