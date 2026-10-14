import 'dart:async';

import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_backend.dart';

late FakeDoorBackend db;
ValueChanged<String>? emit; // the code the fake camera "reads"

Widget fakeCamera(BuildContext context, ValueChanged<String> onCode) {
  emit = onCode;
  return const SizedBox(key: Key('fake-camera'));
}

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: [doorServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
    );

Widget scanScreen() => host(const DoorScanScreen(membershipId: 'm1', cameraBuilder: fakeCamera));
Widget guestsScreen() => host(const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)));

String label(WidgetTester t) => (t.widget(find.byKey(const Key('scan-result-label'))) as Text).data!;

/// Reads a code with the fake camera and lets the check finish.
Future<void> read(WidgetTester tester, String code) async {
  emit!(code);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    db = FakeDoorBackend();
    emit = null;
    db.handlers['door_events'] = (_) => [eventRow()];
  });

  group('Scan', () {
    testWidgets('shows the event, and how many guests are in', (tester) async {
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      expect(find.text('Friday Night'), findsOneWidget);
      expect(find.text('3 of 10 guests in'), findsOneWidget);
      expect(find.textContaining('whole club'), findsOneWidget);
      expect(find.byKey(const Key('fake-camera')), findsOneWidget);
      expect(db.paramsOf('door_events'), [
        {'p_membership': 'm1'},
      ]);
    });

    testWidgets('a good ticket is admitted: the guest is shown, and the count is read again', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada Lovelace', tier: 'General', quantity: 2)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      db.handlers['door_events'] = (_) => [eventRow(admitted: 5)]; // the two guests are now in

      await read(tester, 'T-100');

      expect(label(tester), 'Admit');
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('General × 2'), findsOneWidget);
      expect(db.paramsOf('door_scan_ticket'), [
        {'p_ticket_code': 'T-100', 'p_event': 'e1'},
      ]);
      expect(db.count('door_events'), 2);
      expect(find.text('5 of 10 guests in'), findsOneWidget);
      expect(find.byKey(const Key('fake-camera')), findsOneWidget, reason: 'the camera stays on while the answer shows');
    });

    testWidgets('while an answer is showing, more reads are ignored; "Scan next" clears it', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();

      await read(tester, 'T-1');
      await read(tester, 'T-2');
      await read(tester, 'T-3');
      expect(db.count('door_scan_ticket'), 1, reason: 'the card is up: nothing else is acted on');

      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-result')), findsNothing);

      await read(tester, 'T-2');
      expect(db.count('door_scan_ticket'), 2);
    });

    testWidgets('a held-up ticket is not scanned twice within five seconds', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('already_checked_in', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();

      await read(tester, 'T-1');
      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pumpAndSettle();
      await read(tester, 'T-1'); // still in front of the camera
      expect(db.count('door_scan_ticket'), 1);
      expect(find.byKey(const Key('scan-result')), findsNothing);
    });

    testWidgets('a code typed in is checked, even straight after the same code was scanned', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-9');
      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('manual-code-field')), '  T-9 ');
      await tester.tap(find.byKey(const Key('manual-check')));
      await tester.pumpAndSettle();

      expect(db.count('door_scan_ticket'), 2, reason: 'typing is deliberate, so the cooldown does not apply');
      expect(db.paramsOf('door_scan_ticket').last!['p_ticket_code'], 'T-9');
    });

    testWidgets('an empty box checks nothing', (tester) async {
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-check')));
      await tester.pumpAndSettle();
      expect(db.count('door_scan_ticket'), 0);
      expect(find.byKey(const Key('scan-result')), findsNothing);
    });

    testWidgets('unpaid is a stop, not an admission', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('not_paid', name: 'Pat Pending')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-2');

      expect(label(tester), 'Not paid');
      expect(find.textContaining('Do not admit'), findsOneWidget);
      expect(find.text('Admit'), findsNothing);
      expect(db.count('door_events'), 1, reason: 'nobody was admitted, so the count is not re-read');
    });

    testWidgets('a ticket for another event shows no guest details', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('wrong_event')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-3');

      expect(label(tester), 'Not for this event');
      expect(find.byKey(const Key('scan-result-name')), findsNothing);
      expect(find.byKey(const Key('scan-result-ticket')), findsNothing);
    });

    testWidgets('a non-transferable ticket asks for the entry code, and admits on the right one', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada', tier: 'Table guest', quantity: 1)];
      db.handlers['door_verify_ticket_code'] = (_) => [scanRow('ok', name: 'Ada', tier: 'Table guest', quantity: 1)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-4');

      expect(label(tester), 'Entry code required');
      expect(find.byKey(const Key('entry-code-field')), findsOneWidget);
      expect(find.text('Admit'), findsNothing, reason: 'not admitted until the code is right');

      await tester.enterText(find.byKey(const Key('entry-code-field')), ' 123456 ');
      await tester.tap(find.byKey(const Key('verify-code')));
      await tester.pumpAndSettle();

      expect(db.paramsOf('door_verify_ticket_code'), [
        {'p_ticket_code': 'T-4', 'p_code': '123456', 'p_event': 'e1'},
      ]);
      expect(label(tester), 'Admit');
      expect(find.byKey(const Key('entry-code-field')), findsNothing);
      expect(db.count('door_events'), 2, reason: 'admitted at last, so the count is read again');
    });

    testWidgets('a wrong code shows the tries left and a cleared box; three failures end the retry', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada')];
      final answers = [
        scanRow('code_incorrect', name: 'Ada', attemptsRemaining: 2),
        scanRow('code_incorrect', name: 'Ada', attemptsRemaining: 1),
        scanRow('code_expired', name: 'Ada'),
      ];
      db.handlers['door_verify_ticket_code'] = (_) => [answers.removeAt(0)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-5');

      for (final tries in ['2 tries left', '1 try left']) {
        await tester.enterText(find.byKey(const Key('entry-code-field')), '000000');
        await tester.tap(find.byKey(const Key('verify-code')));
        await tester.pumpAndSettle();
        expect(label(tester), 'Code is incorrect');
        expect(find.text(tries), findsOneWidget);
        expect((tester.widget(find.byKey(const Key('entry-code-field'))) as TextField).controller!.text, isEmpty,
            reason: 'a wrong code is not left in the box to be sent again');
      }

      await tester.enterText(find.byKey(const Key('entry-code-field')), '000000');
      await tester.tap(find.byKey(const Key('verify-code')));
      await tester.pumpAndSettle();
      expect(label(tester), 'Code expired or locked');
      expect(find.byKey(const Key('entry-code-field')), findsNothing, reason: 'final: the guest must ask for a new code');
      expect(find.byKey(const Key('scan-next')), findsOneWidget);
    });

    testWidgets('an empty code is not sent', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-6');
      await tester.tap(find.byKey(const Key('verify-code')));
      await tester.pumpAndSettle();
      expect(db.count('door_verify_ticket_code'), 0);
    });

    testWidgets('a code check cannot be sent twice while it is running', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada')];
      final gate = Completer<dynamic>();
      db.handlers['door_verify_ticket_code'] = (_) => gate.future;
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-7');

      await tester.enterText(find.byKey(const Key('entry-code-field')), '123456');
      await tester.tap(find.byKey(const Key('verify-code')));
      await tester.pump();
      expect(find.text('Checking…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('verify-code')), warnIfMissed: false);
      await tester.pump();
      expect(db.count('door_verify_ticket_code'), 1);

      gate.complete([scanRow('ok', name: 'Ada')]);
      await tester.pumpAndSettle();
      expect(label(tester), 'Admit');
    });

    testWidgets('a person whose access ended is told so, not left on a stuck screen', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => throw const PostgrestException(message: 'not authorized');
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-8');
      expect(label(tester), 'Your access has ended');
      expect(find.byKey(const Key('scan-next')), findsOneWidget);
    });

    testWidgets('a dropped connection is "scan failed", and the next scan works', (tester) async {
      var fail = true;
      db.handlers['door_scan_ticket'] = (_) => fail ? throw Exception('offline') : [scanRow('ok', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-10');
      expect(label(tester), 'Scan failed');

      fail = false;
      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pumpAndSettle();
      await read(tester, 'T-11');
      expect(label(tester), 'Admit');
    });

    testWidgets('with several events the person chooses, and scans are aimed at the choice', (tester) async {
      db.handlers['door_events'] = (_) => [eventRow(id: 'e1', title: 'Friday Night'), eventRow(id: 'e2', title: 'Saturday Night')];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-picker')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saturday Night').last);
      await tester.pumpAndSettle();
      await read(tester, 'T-12');

      expect(db.paramsOf('door_scan_ticket').single!['p_event'], 'e2');
    });

    testWidgets('changing event clears an answer that belongs to the old one', (tester) async {
      db.handlers['door_events'] = (_) => [eventRow(id: 'e1', title: 'Friday Night'), eventRow(id: 'e2', title: 'Saturday Night')];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada')];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-13');
      expect(find.byKey(const Key('scan-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saturday Night').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-result')), findsNothing);
    });

    testWidgets('no event right now says so', (tester) async {
      db.handlers['door_events'] = (_) => <dynamic>[];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('door-message')), findsOneWidget);
      expect(find.textContaining('No event to scan for right now'), findsOneWidget);
      expect(find.byKey(const Key('fake-camera')), findsNothing);
    });

    testWidgets('a server without the door migration says so, with no pointless retry', (tester) async {
      db.handlers['door_events'] = (_) => throw const PostgrestException(message: 'no function', code: '42883');
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('door-retry')), findsNothing);
    });

    testWidgets('a failed load offers a retry that works', (tester) async {
      var fail = true;
      db.handlers['door_events'] = (_) => fail ? throw Exception('offline') : [eventRow()];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('try again'), findsOneWidget);

      fail = false;
      await tester.tap(find.byKey(const Key('door-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Friday Night'), findsOneWidget);
    });
  });

  group('Guests', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('guest-search-field')), text);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for two letters first, and does not search for fewer', (tester) async {
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('at least two letters'), findsOneWidget);

      await type(tester, 'a');
      expect(db.count('door_guests'), 0);
      // One letter is "no search yet", not "no guest matches".
      expect(find.textContaining('at least two letters'), findsOneWidget);
      expect(find.byKey(const Key('no-guests')), findsNothing);
    });

    testWidgets('finds guests by name and shows each with their ticket', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada Lovelace', 'T-1'), guestRow('Adam Smith', 'T-2', checkedInAt: '2026-10-09T22:00:00Z')];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ad');

      expect(db.paramsOf('door_guests'), [
        {'p_event': 'e1', 'p_query': 'ad'},
      ]);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('General × 2'), findsNWidgets(2));
      expect(find.byKey(const Key('admit-T-1')), findsOneWidget);
      expect(find.byKey(const Key('guest-in')), findsOneWidget, reason: 'Adam is already in');
      expect(find.byKey(const Key('admit-T-2')), findsNothing, reason: 'a guest who is in cannot be admitted again');
    });

    testWidgets('admitting from the list uses the same checks, marks the guest in, and re-reads the count', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada Lovelace', 'T-1')];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada Lovelace', tier: 'General', quantity: 2)];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ada');

      await tester.tap(find.byKey(const Key('admit-T-1')));
      await tester.pumpAndSettle();

      expect(db.paramsOf('door_scan_ticket'), [
        {'p_ticket_code': 'T-1', 'p_event': 'e1'},
      ]);
      expect(label(tester), 'Admit');
      expect(find.byKey(const Key('guest-in')), findsOneWidget);
      expect(find.byKey(const Key('admit-T-1')), findsNothing);
      expect(db.count('door_events'), 2);

      await tester.tap(find.byKey(const Key('scan-next'))); // "Done"
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-result')), findsNothing);
    });

    testWidgets('a non-transferable ticket asks for its code inline, and the guest stays out until it is right', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada', 'T-1', needsCode: true)];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada')];
      db.handlers['door_verify_ticket_code'] = (_) => [scanRow('ok', name: 'Ada', tier: 'General', quantity: 2)];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ada');
      expect(find.text('Needs an entry code'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admit-T-1')));
      await tester.pumpAndSettle();
      expect(label(tester), 'Entry code required');
      expect(find.byKey(const Key('guest-in')), findsNothing);

      await tester.enterText(find.byKey(const Key('entry-code-field')), '654321');
      await tester.tap(find.byKey(const Key('verify-code')));
      await tester.pumpAndSettle();
      expect(label(tester), 'Admit');
      expect(find.byKey(const Key('guest-in')), findsOneWidget);
    });

    testWidgets('a refused admission does not mark the guest in', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada', 'T-1')];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('expired', name: 'Ada')];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ada');
      await tester.tap(find.byKey(const Key('admit-T-1')));
      await tester.pumpAndSettle();

      expect(label(tester), 'Event has ended');
      expect(find.byKey(const Key('guest-in')), findsNothing);
      expect(find.byKey(const Key('admit-T-1')), findsOneWidget);
    });

    testWidgets('no match says so', (tester) async {
      db.handlers['door_guests'] = (_) => <dynamic>[];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'zz');
      expect(find.byKey(const Key('no-guests')), findsOneWidget);
    });

    testWidgets('a failed search says so in words', (tester) async {
      db.handlers['door_guests'] = (_) => throw const PostgrestException(message: 'not authorized');
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ada');
      expect(find.byKey(const Key('search-error')), findsOneWidget);
      expect(find.textContaining('access has ended'), findsOneWidget);
    });

    testWidgets('a slow, older search never replaces a newer one', (tester) async {
      final slow = Completer<dynamic>();
      var call = 0;
      db.handlers['door_guests'] = (p) {
        call++;
        return call == 1 ? slow.future : [guestRow('Ada Newer', 'T-NEW')];
      };
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('guest-search-field')), 'ad');
      await tester.pump(const Duration(milliseconds: 50)); // first search starts and hangs
      await tester.enterText(find.byKey(const Key('guest-search-field')), 'ada');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Ada Newer'), findsOneWidget);

      slow.complete([guestRow('Ada Older', 'T-OLD')]); // arrives late
      await tester.pumpAndSettle();
      expect(find.text('Ada Older'), findsNothing);
      expect(find.text('Ada Newer'), findsOneWidget);
    });

    testWidgets('clearing the box forgets the results', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada', 'T-1')];
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await type(tester, 'ada');
      expect(find.text('Ada'), findsOneWidget);

      await type(tester, '');
      expect(find.text('Ada'), findsNothing);
      expect(find.textContaining('at least two letters'), findsOneWidget);
    });
  });

  group('the event is shared between Scan and Guests', () {
    testWidgets('the choice made on one is the choice on the other', (tester) async {
      db.handlers['door_events'] = (_) => [eventRow(id: 'e1', title: 'Friday Night'), eventRow(id: 'e2', title: 'Saturday Night')];
      db.handlers['door_guests'] = (_) => [guestRow('Ada', 'T-1')];
      final container = ProviderContainer(overrides: [doorServiceProvider.overrideWithValue(db.service)]);
      addTearDown(container.dispose);

      container.read(selectedDoorEventProvider('m1').notifier).state = 'e2';
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)))),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('guest-search-field')), 'ada');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(db.paramsOf('door_guests').single!['p_event'], 'e2');
    });

    test('a chosen event that is no longer on the list falls back to the default', () {
      final events = [
        for (final row in [eventRow(id: 'e1', startsInHours: -1), eventRow(id: 'e2', startsInHours: 5)]) parseDoorEvent(row)!,
      ];
      expect(resolveEvent(events, 'gone')!.eventId, 'e1');
      expect(resolveEvent(events, 'e2')!.eventId, 'e2');
      expect(resolveEvent(events, null)!.eventId, 'e1');
      expect(resolveEvent(const [], 'e1'), isNull);
    });
  });
}

