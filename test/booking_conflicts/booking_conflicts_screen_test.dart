import 'dart:async';

import 'package:bottles_up_vendor/features/booking_conflicts/logic/conflict_rules.dart';
import 'package:bottles_up_vendor/features/booking_conflicts/providers/conflict_providers.dart';
import 'package:bottles_up_vendor/features/booking_conflicts/screens/booking_conflicts_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_conflict_backend.dart';

late FakeConflictBackend db;
final List<Uri> opened = [];
Object? openFails;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget host({Workspace ws = manager, ConflictAsker? ask}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        bookingConflictServiceProvider.overrideWithValue(db.service),
        ownerVenuesProvider.overrideWith((ref, orgId) async => [const OrgVenue(id: 'v1', name: 'Club A', status: 'published'), const OrgVenue(id: 'v2', name: 'Club B', status: 'published')]),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BookingConflictsScreen(
            workspace: ws,
            contact: (uri) async {
              final broken = openFails;
              if (broken != null) throw broken;
              opened.add(uri);
            },
            ask: ask ?? (c, k) async => null,
            clock: () => DateTime(2026, 11, 14, 22),
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, {Workspace ws = manager, ConflictAsker? ask}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ws: ws, ask: ask));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

ConflictAsker answer(ConflictResolution how, String note) => (c, k) async => ConflictAnswer(how, note);
List<(String, Map<String, dynamic>?)> resolves() => [for (final c in db.calls) if (c.$1 == 'desk_resolve_booking_conflict') c];

void main() {
  setUp(() {
    db = FakeConflictBackend();
    opened.clear();
    openFails = null;
  });

  testWidgets('lists the club\'s open ones with what a manager needs to act: who, when, how much, what is wrong, and a way to reach them', (tester) async {
    db.add('k1', name: 'Late Payer');
    db.rows.last.code = 'CF0002';
    await open(tester);
    expect(db.calls.first.$2, {'p_venue': 'v1', 'p_include_resolved': false});
    expect(find.text('Late Payer'), findsOneWidget);
    expect(find.text('Saturday Nov 14 · 21:00 · Last booth'), findsOneWidget);
    expect(find.text('CF0002'), findsOneWidget);
    expect(find.text('Paid \$100.00 · 2 guests'), findsOneWidget);
    expect(find.byKey(const Key('conflict-line-k1')), findsOneWidget);
    expect(find.textContaining('No confirmation has been sent to them.'), findsOneWidget);
    expect(find.text('Needs you'), findsOneWidget);
    for (final k in ['call-k1', 'email-k1', 'open-k1', 'settle-k1']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
  });

  testWidgets('says what to do when nothing is double-booked', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('conflicts-empty')), findsOneWidget);
    expect(find.text('No table is double-booked. Nothing for you to do.'), findsOneWidget);
  });

  testWidgets('a settled one is hidden until asked for, and then has its words and no buttons', (tester) async {
    db.add('k1');
    db.add('k2', status: 'resolved')
      ..resolution = 'moved'
      ..note = 'Moved to table 4';
    await open(tester);
    expect(find.byKey(const Key('conflict-k2')), findsNothing);
    await tapKey(tester, 'show-settled');
    expect(db.calls.last.$2, {'p_venue': 'v1', 'p_include_resolved': true});
    expect(find.byKey(const Key('conflict-k2')), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Settled: moved to another table.'), findsOneWidget);
    expect(find.text('“Moved to table 4”'), findsOneWidget);
    for (final k in ['call-k2', 'email-k2', 'open-k2', 'settle-k2']) {
      expect(find.byKey(Key(k)), findsNothing, reason: k);
    }
    expect(find.byKey(const Key('settle-k1')), findsOneWidget);
  });

  testWidgets('when everything is settled and settled ones are shown, an empty list says so differently', (tester) async {
    await open(tester);
    await tapKey(tester, 'show-settled');
    expect(find.text('No table has been double-booked.'), findsOneWidget);
  });

  testWidgets('a failed read says what failed and can be tried again', (tester) async {
    db.failAll = Exception('SocketException: Failed host lookup');
    await open(tester);
    expect(find.byKey(const Key('conflicts-error')), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    db.failAll = null;
    db.add('k1');
    await tapKey(tester, 'ops-retry');
    expect(find.byKey(const Key('conflict-k1')), findsOneWidget);
  });

  testWidgets('a server database without the migration says so', (tester) async {
    db.failAll = PostgrestExceptionFor.missing();
    await open(tester);
    expect(find.text('The double-booked tables are not set up on this server yet.'), findsOneWidget);
  });

  group('reaching the guest', () {
    testWidgets('Call and E-mail open the guest\'s own number and address', (tester) async {
      db.add('k1', phone: '+1 555 0100', email: 'ada@example.com');
      await open(tester);
      await tapKey(tester, 'call-k1');
      await tapKey(tester, 'email-k1');
      expect(opened.map((u) => u.toString()), ['tel:+1%20555%200100', 'mailto:ada@example.com']);
    });

    testWidgets('a guest with only an e-mail address has no Call button, and the other way round', (tester) async {
      db.rows.add(FakeConflict('k1', phone: null, email: 'ada@example.com'));
      db.rows.add(FakeConflict('k2', phone: '+1 555 0100', email: null));
      await open(tester);
      expect(find.byKey(const Key('call-k1')), findsNothing);
      expect(find.byKey(const Key('email-k1')), findsOneWidget);
      expect(find.byKey(const Key('call-k2')), findsOneWidget);
      expect(find.byKey(const Key('email-k2')), findsNothing);
    });

    testWidgets('a phone that cannot open it says so', (tester) async {
      db.add('k1');
      openFails = Exception('no handler');
      await open(tester);
      await tapKey(tester, 'call-k1');
      expect(find.text('This could not be opened on this phone.'), findsOneWidget);
    });

    testWidgets('Open booking goes to the booking\'s own page, where it can be moved or refunded', (tester) async {
      db.add('k1', bookingId: 'b-77', name: 'Late Payer');
      await open(tester);
      await tapKey(tester, 'open-k1');
      final page = tester.widget<TableDetailScreen>(find.byType(TableDetailScreen));
      expect([page.bookingId, page.title], ['b-77', 'Last booth · Late Payer']);
    });
  });

  group('settling one', () {
    testWidgets('the manager says how and why; the database records it; the card leaves the open list and the manager is told', (tester) async {
      db.add('k1', overbooked: false);
      await open(tester, ask: answer(ConflictResolution.moved, 'Moved to table 4, guest called'));
      await tapKey(tester, 'settle-k1');
      expect(resolves().single.$2, {'p_conflict': 'k1', 'p_resolution': 'moved', 'p_note': 'Moved to table 4, guest called'});
      expect(find.text('Saved: moved to another table.'), findsOneWidget);
      expect(find.byKey(const Key('conflict-k1')), findsNothing);
      expect(find.byKey(const Key('conflicts-empty')), findsOneWidget);
      expect(db.rows.single.status, 'resolved');
    });

    testWidgets('backing out sends nothing', (tester) async {
      db.add('k1');
      await open(tester);
      await tapKey(tester, 'settle-k1');
      expect(resolves(), isEmpty);
      expect(find.byKey(const Key('conflict-k1')), findsOneWidget);
    });

    testWidgets('a refusal is the database\'s own words, nothing is faked, and the list is read again', (tester) async {
      db.add('k1', overbooked: true);
      await open(tester, ask: answer(ConflictResolution.moved, 'Moved to table 4'));
      final reads = db.calls.where((c) => c.$1 == 'desk_booking_conflicts').length;
      await tapKey(tester, 'settle-k1');
      expect(find.text('That table is still double-booked: move the booking to another table first.'), findsOneWidget);
      expect(db.rows.single.status, 'open');
      expect(db.calls.where((c) => c.$1 == 'desk_booking_conflicts').length, greaterThan(reads));
      expect(find.byKey(const Key('settle-k1')), findsOneWidget, reason: 'it can be tried again');
    });

    testWidgets('"refunded" is refused while the booking is still paid, and accepted once it is cancelled', (tester) async {
      db.add('k1', bookingStatus: 'paid');
      await open(tester, ask: answer(ConflictResolution.refunded, 'Paid back in full'));
      await tapKey(tester, 'settle-k1');
      expect(find.text('Refund or cancel the booking first.'), findsOneWidget);
      db.rows.single.bookingStatus = 'cancelled';
      await tapKey(tester, 'settle-k1');
      expect(find.text('Saved: refunded or cancelled.'), findsOneWidget);
      expect(db.rows.single.status, 'resolved');
    });

    testWidgets('while it goes through the button waits: two quick taps are one save', (tester) async {
      db.add('k1', overbooked: false);
      var asked = 0;
      await open(tester, ask: (c, k) async {
        asked++;
        return const ConflictAnswer(ConflictResolution.kept, 'Opened another booth');
      });
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('settle-k1')));
      await tester.tap(find.byKey(const Key('settle-k1')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('settle-k1')), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(resolves(), hasLength(1));
    });

    testWidgets('a lost connection says so plainly and keeps the conflict open', (tester) async {
      db.add('k1');
      await open(tester, ask: answer(ConflictResolution.kept, 'Opened another booth'));
      db.failOn['desk_resolve_booking_conflict'] = Exception('SocketException: Failed host lookup');
      await tapKey(tester, 'settle-k1');
      expect(find.text('This could not be saved. Check your connection and look at the list before trying again.'), findsOneWidget);
      expect(find.byKey(const Key('conflict-k1')), findsOneWidget);
    });
  });

  group('the sheet that asks', () {
    testWidgets('names the three ways, asks for a few words, and says what is missing', (tester) async {
      db.add('k1', overbooked: false);
      await open(tester, ask: askHowSettled);
      await tapKey(tester, 'settle-k1');
      expect(find.text('How was it settled?'), findsOneWidget);
      for (final c in ConflictResolution.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      await tapKey(tester, 'settle-save');
      expect(find.text('Say how it was settled.'), findsOneWidget);
      await tapKey(tester, 'how-moved');
      expect(find.byKey(const Key('settle-problem')), findsNothing, reason: 'choosing clears the message');
      await tapKey(tester, 'settle-save');
      expect(find.text('Say what was done, in a few words.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('settle-note')), '  Moved to table 4  ');
      await tester.pump();
      expect(find.byKey(const Key('settle-problem')), findsNothing, reason: 'typing clears the message');
      await tapKey(tester, 'settle-save');
      expect(resolves().single.$2, {'p_conflict': 'k1', 'p_resolution': 'moved', 'p_note': 'Moved to table 4'});
      expect(db.rows.single.status, 'resolved');
    });
  });

  group('for an owner', () {
    testWidgets('the owner picks the club first, then sees that club\'s double-booked tables', (tester) async {
      db.add('k1', venue: 'v1', name: 'Guest One');
      db.add('k2', venue: 'v2', name: 'Guest Two');
      await open(tester, ws: owner);
      expect(find.byKey(const Key('conflicts-pick-club')), findsOneWidget);
      expect(db.calls, isEmpty);
      await tapKey(tester, 'conflicts-club-v2');
      expect(db.calls.first.$2, {'p_venue': 'v2', 'p_include_resolved': false});
      expect(find.text('Guest Two'), findsOneWidget);
      expect(find.text('Guest One'), findsNothing);
    });
  });
}
