import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_guests/logic/guest_rules.dart';
import 'package:bottles_up_vendor/features/organizer_guests/providers/guest_providers.dart';
import 'package:bottles_up_vendor/features/organizer_guests/screens/organizer_guests_screen.dart';
import 'package:bottles_up_vendor/features/organizer_guests/services/guest_service.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String m) => PostgrestException(message: m, code: 'P0001');

class FakeGuestBackend {
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  bool allowed = true;

  final Map<String, List<Map<String, dynamic>>> guestsByEvent = {
    'e1': [
      {'order_id': 'o1', 'customer_name': 'Cleo Crown', 'ticket_code': 'T-CLEO', 'tier_name': 'VIP', 'quantity': 3, 'checked_in_at': null},
      {'order_id': 'o2', 'customer_name': 'Ada Lovelace', 'ticket_code': 'T-ADA', 'tier_name': 'General', 'quantity': 1, 'checked_in_at': '2026-10-09T21:30:00Z'},
    ],
    'e2': [],
  };

  OrganizerGuestService get service => OrganizerGuestService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String f) => [for (final c in calls) if (c.function == f) c.params ?? const {}];

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    if (!allowed) throw refuse('not allowed');
    final guests = guestsByEvent[params!['p_event']] ?? const [];
    switch (function) {
      case 'organizer_guest_summary':
        return {
          'orders': guests.length,
          'tickets_sold': guests.fold<int>(0, (s, g) => s + (g['quantity'] as int)),
          'checked_in': guests.where((g) => g['checked_in_at'] != null).fold<int>(0, (s, g) => s + (g['quantity'] as int)),
          'by_tier': guests.isEmpty ? [] : [{'tier': 'General', 'sold': 1, 'checked_in': 1}, {'tier': 'VIP', 'sold': 3, 'checked_in': 0}],
        };
      case 'organizer_guests':
        final q = ((params['p_query'] as String?) ?? '').toLowerCase();
        return [for (final g in guests) if (q.isEmpty || (g['customer_name'] as String).toLowerCase().contains(q) || (g['ticket_code'] as String).toLowerCase().contains(q)) g];
    }
    throw StateError('unexpected $function');
  }
}

late FakeGuestBackend db;

const organizer = Workspace(membershipId: 'w', orgId: 'o9', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

Future<void> open(WidgetTester tester, {List<OrgEvent>? events}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final list = events ?? [OrgEvent(eventId: 'e1', title: 'Night One', startDate: DateTime(2026, 11, 1), status: OrgEventStatus.published), OrgEvent(eventId: 'e2', title: 'Night Two', startDate: DateTime(2026, 11, 8), status: OrgEventStatus.draft)];
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [organizerGuestServiceProvider.overrideWithValue(db.service), organizerEventsProvider.overrideWith((ref, org) async => list)],
    child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: OrganizerGuestsScreen(workspace: organizer))),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => db = FakeGuestBackend());

  group('rules', () {
    test('a summary and a guest are read', () {
      final s = parseGuestSummary({'orders': 2, 'tickets_sold': 4, 'checked_in': 1, 'by_tier': [{'tier': 'VIP', 'sold': 3, 'checked_in': 0}]})!;
      expect(s.remaining, 3);
      expect(s.progress, '1 of 4 checked in');
      expect(s.tiers.single.tier, 'VIP');
      final g = parseGuest({'order_id': 'o', 'customer_name': 'Ada', 'tier_name': 'General', 'quantity': 2, 'ticket_code': 'T-A'})!;
      expect(g.ticketLine, 'General · 2 tickets');
      expect(g.checkedIn, isFalse);
      expect(parseGuest({'order_id': 'o', 'quantity': 1})!.ticketLine, 'Ticket · 1 ticket');
      expect(parseGuest({'customer_name': 'x'}), isNull);
    });

    test('the search needs two characters, or nothing', () {
      expect(checkGuestSearch('a'), 'Type at least 2 characters to search.');
      expect(checkGuestSearch(''), isNull);
      expect(checkGuestSearch(' ada '), isNull);
    });

    test('check-in in words', () {
      expect(checkedInLabel(null), 'Not checked in');
      expect(checkedInLabel(DateTime.utc(2026, 10, 9, 21, 30)), startsWith('Checked in '));
    });
  });

  group('the Guests tab', () {
    testWidgets('shows the first event with sold and checked-in numbers, by ticket type, and who bought', (tester) async {
      await open(tester);
      expect(db.calledWith('organizer_guest_summary').first, {'p_event': 'e1'});
      expect(tester.widget<Text>(find.byKey(const Key('guests-sold'))).data, '4 tickets sold');
      expect(tester.widget<Text>(find.byKey(const Key('guests-progress'))).data, '1 of 4 checked in');
      expect(tester.widget<Text>(find.byKey(const Key('guests-remaining'))).data, '3 still to arrive');
      expect(tester.widget<Text>(find.byKey(const Key('guests-tier-1'))).data, 'VIP: 0 of 3 checked in');
      expect(find.text('Cleo Crown'), findsOneWidget);
      expect(find.text('VIP · 3 tickets · T-CLEO'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('guest-state-o1'))).data, 'Not checked in');
      expect(tester.widget<Text>(find.byKey(const Key('guest-state-o2'))).data, startsWith('Checked in'));
    });

    testWidgets('searching asks the database, needs two characters, and says when no one matches', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('guests-search')), 'a');
      await tapKey(tester, 'guests-search-go');
      expect(find.text('Type at least 2 characters to search.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('guests-search')), 'ada');
      await tapKey(tester, 'guests-search-go');
      expect(db.calledWith('organizer_guests').last, {'p_event': 'e1', 'p_query': 'ada'});
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Cleo Crown'), findsNothing);
      await tester.enterText(find.byKey(const Key('guests-search')), 'zzz');
      await tapKey(tester, 'guests-search-go');
      expect(find.byKey(const Key('guests-empty')), findsOneWidget);
      expect(find.text('No one matches that.'), findsOneWidget);
    });

    testWidgets('choosing another event shows its numbers and clears the search', (tester) async {
      await open(tester);
      await tapKey(tester, 'guests-event');
      await tester.tap(find.text('Night Two').last);
      await tester.pumpAndSettle();
      expect(db.calledWith('organizer_guest_summary').last, {'p_event': 'e2'});
      expect(find.text('No tickets have been bought yet.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('guests-sold'))).data, '0 tickets sold');
    });

    testWidgets('no events, no access, no backend and a dropped connection are said in words', (tester) async {
      await open(tester, events: const []);
      expect(find.byKey(const Key('guests-no-events')), findsOneWidget);
      db.allowed = false;
      await open(tester);
      expect(find.byKey(const Key('guests-error')), findsOneWidget);
      db.allowed = true;
      db.missing = true;
      await open(tester);
      expect(find.byKey(const Key('guests-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester);
      db.offline = false;
      expect(find.byKey(const Key('ops-retry')), findsNWidgets(2), reason: 'the numbers and the list each offer Try again');
      while (find.byKey(const Key('ops-retry')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('ops-retry')).first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Cleo Crown'), findsOneWidget);
      expect(find.byKey(const Key('guests-sold')), findsOneWidget);
    });

    testWidgets('a cut-off list says so', (tester) async {
      db.guestsByEvent['e1'] = [for (var i = 0; i < 100; i++) {'order_id': 'o$i', 'customer_name': 'Guest $i', 'ticket_code': 'T$i', 'tier_name': 'General', 'quantity': 1, 'checked_in_at': null}];
      tester.view.physicalSize = const Size(800, 12000);
      await open(tester);
      expect(find.byKey(const Key('guests-cut')), findsOneWidget);
    });
  });
}
