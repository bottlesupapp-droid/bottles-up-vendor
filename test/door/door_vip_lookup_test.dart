import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/vip/providers/vip_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vip/fake_vip_backend.dart';
import 'fake_door_backend.dart';

late FakeDoorBackend door;
late FakeVipBackend vip;

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: [doorServiceProvider.overrideWithValue(door.service), vipServiceProvider.overrideWithValue(vip.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
    );

Future<void> open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(screen));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> lookUp(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('lookup-query')), text);
  await tester.pump();
  await tapKey(tester, 'lookup-go');
}

FakeVip ada() => FakeVip('m1', 'Ada Lovelace', email: 'ada@example.com', tier: 'Gold', host: 'Mia Manager', preferences: 'still water, no ice', notes: 'allergic to nuts', code: 'ADA00001')
  ..perks.addAll([FakePerk('k1', 'entry', 'Priority entry', max: 1), FakePerk('k2', 'service', 'Welcome shot', max: 1), FakePerk('k3', 'discount', '10 percent off', max: 3, period: 'total')]);

void main() {
  setUp(() {
    door = FakeDoorBackend();
    door.handlers['door_events'] = (_) => [eventRow()];
    vip = FakeVipBackend(role: 'door')..members.add(ada());
  });

  testWidgets('a club door can open the VIP lookup from Guests', (tester) async {
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    expect(find.byKey(const Key('vip-lookup-open')), findsOneWidget);
    expect(find.byKey(const Key('guest-search-field')), findsOneWidget, reason: 'the ticket search is still there');
    await tapKey(tester, 'vip-lookup-open');
    expect(find.byKey(const Key('vip-lookup')), findsOneWidget);
  });

  testWidgets('the door sees the entry perk and nothing else of the guest: no preferences, contact, notes, service or discount perks', (tester) async {
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    await tapKey(tester, 'vip-lookup-open');
    await lookUp(tester, 'ada');
    expect(vip.calledWith('vip_lookup').single['p_venue'], 'v1', reason: 'it asks about the club this door works at');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Priority entry'), findsOneWidget);
    expect(find.text('Welcome shot'), findsNothing);
    expect(find.text('10 percent off'), findsNothing);
    expect(find.byKey(const Key('lookup-prefs-m1')), findsNothing);
    expect(find.byKey(const Key('lookup-contact-m1')), findsNothing);
    expect(find.byKey(const Key('lookup-notes-m1')), findsNothing);
  });

  testWidgets('the door can find a guest by credential code and redeem the entry perk once', (tester) async {
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    await tapKey(tester, 'vip-lookup-open');
    await lookUp(tester, 'ADA00001');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tapKey(tester, 'lookup-redeem-k1');
    expect(vip.calledWith('vip_redeem').single['p_perk'], 'k1');
    expect(find.text('Used'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('lookup-redeem-k1'))).onPressed, isNull, reason: 'a perk with one use cannot be given twice');
  });

  testWidgets('an ended membership shows as ended with nothing to give', (tester) async {
    vip.members.add(FakeVip('m3', 'Cleo Past', status: 'ended')..perks.add(FakePerk('k9', 'entry', 'Priority entry', max: 1)));
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    await tapKey(tester, 'vip-lookup-open');
    await lookUp(tester, 'cleo');
    expect(find.byKey(const Key('lookup-no-benefits')), findsOneWidget);
    expect(find.byKey(const Key('lookup-redeem-k9')), findsNothing);
  });

  testWidgets('the button is there even when the club has no event tonight', (tester) async {
    door.handlers['door_events'] = (_) => [];
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    expect(find.text('No event to search right now.'), findsOneWidget);
    expect(find.byKey(const Key('vip-lookup-open')), findsOneWidget);
  });

  testWidgets('a door that works one event has no club, so it gets no VIP button (the database would refuse it)', (tester) async {
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)));
    expect(find.byKey(const Key('vip-lookup-open')), findsNothing);
    expect(find.byKey(const Key('guest-search-field')), findsOneWidget);
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: '', debounce: Duration(milliseconds: 10)));
    expect(find.byKey(const Key('vip-lookup-open')), findsNothing, reason: 'an empty venue is no venue');
  });

  testWidgets('a refusal from the database is shown in words, not hidden', (tester) async {
    vip.role = 'stranger';
    await open(tester, const DoorGuestsScreen(membershipId: 'm1', venueId: 'v1', debounce: Duration(milliseconds: 10)));
    await tapKey(tester, 'vip-lookup-open');
    await lookUp(tester, 'ada');
    expect(find.text("You don't have access to do that."), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });
}
