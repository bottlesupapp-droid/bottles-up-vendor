import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/vip/providers/vip_providers.dart';
import 'package:bottles_up_vendor/features/vip/screens/vip_form_screen.dart';
import 'package:bottles_up_vendor/features/vip/screens/vip_lookup_screen.dart';
import 'package:bottles_up_vendor/features/vip/screens/vip_profile_screen.dart';
import 'package:bottles_up_vendor/features/vip/screens/vip_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_vip_backend.dart';

late FakeVipBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        vipServiceProvider.overrideWithValue(db.service),
        chatPeopleProvider.overrideWith((ref, venue) async => const [ChatPerson(userId: 'u-mia', name: 'Mia Manager', role: 'manager'), ChatPerson(userId: 'u-sam', name: 'Sam Server', role: 'server')]),
        ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

FakeVip ada() => FakeVip('m1', 'Ada Lovelace', email: 'ada@example.com', tier: 'Gold', host: 'Mia Manager', preferences: 'still water, no ice', notes: 'allergic to nuts', code: 'ADA00001')
  ..perks.addAll([FakePerk('k1', 'entry', 'Priority entry', max: 1), FakePerk('k2', 'service', 'Welcome shot', max: 1), FakePerk('k3', 'discount', '10 percent off', max: 3, period: 'total')]);

void main() {
  setUp(() {
    db = FakeVipBackend();
    db.members.add(ada());
    db.members.add(FakeVip('m2', 'Bob Barlow', phone: '+1 555 0100'));
    db.members.add(FakeVip('m3', 'Cleo Past', email: 'cleo@example.com', status: 'ended')..endedReason = 'asked to leave');
  });

  group('The list (manager)', () {
    testWidgets('shows active guests with tier, host and perks; ended ones only when asked for', (tester) async {
      await open(tester, const VipScreen(workspace: manager));
      expect(db.calledWith('vip_list').first['p_venue'], 'v1');
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Gold · host Mia Manager · 3 perks'), findsOneWidget);
      expect(find.text('VIP · 0 perks'), findsOneWidget);
      expect(find.text('Cleo Past'), findsNothing);
      await tapKey(tester, 'vip-show-ended');
      expect(find.text('Cleo Past'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('vip-status-m3'))).data, 'Ended');
    });

    testWidgets('a search narrows it; no match is said in words', (tester) async {
      await open(tester, const VipScreen(workspace: manager));
      await typeIn(tester, 'vip-search', 'bob');
      await tapKey(tester, 'vip-search-go');
      expect(find.text('Bob Barlow'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      await typeIn(tester, 'vip-search', 'zzz');
      await tapKey(tester, 'vip-search-go');
      expect(find.byKey(const Key('vip-empty')), findsOneWidget);
      expect(find.text('No one matches that.'), findsOneWidget);
    });

    testWidgets('the owner picks a club first', (tester) async {
      await open(tester, const VipScreen(workspace: owner));
      expect(find.byKey(const Key('vip-pick-club')), findsOneWidget);
      await tapKey(tester, 'vip-club-v2');
      expect(db.calledWith('vip_list').first['p_venue'], 'v2');
      expect(find.byKey(const Key('vip-list')), findsOneWidget);
    });

    testWidgets('a person without access, and a backend without VIP, are told', (tester) async {
      db.role = 'server';
      await open(tester, const VipScreen(workspace: manager));
      expect(find.byKey(const Key('vip-error')), findsOneWidget);
      db.role = 'manager';
      db.missing = true;
      await open(tester, const VipScreen(workspace: manager));
      expect(find.byKey(const Key('vip-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
    });
  });

  group('Adding and changing a guest', () {
    testWidgets('the form checks the name, the contact and the dates, then adds the guest with a host', (tester) async {
      await open(tester, const VipScreen(workspace: manager));
      await tapKey(tester, 'vip-add');
      await tapKey(tester, 'vip-save');
      expect(find.text('Enter the guest\'s name.'), findsOneWidget);
      await typeIn(tester, 'vip-name', 'Dan Future');
      await tapKey(tester, 'vip-save');
      expect(find.text('Enter an email or a phone number.'), findsOneWidget);
      await typeIn(tester, 'vip-email', 'dan@example.com');
      await typeIn(tester, 'vip-tier', 'Silver');
      await tapKey(tester, 'vip-host');
      await tester.tap(find.text('Sam Server · Server').last);
      await tester.pumpAndSettle();
      await typeIn(tester, 'vip-prefs', 'sparkling water');
      await tapKey(tester, 'vip-save');
      final sent = db.calledWith('vip_add').single;
      expect(sent['p_venue'], 'v1');
      final d = sent['p_details'] as Map;
      expect(d['name'], 'Dan Future');
      expect(d['email'], 'dan@example.com');
      expect(d['tier'], 'Silver');
      expect(d['host'], 'u-sam');
      expect(d['preferences'], 'sparkling water');
      expect(d.containsKey('phone'), isFalse, reason: 'only what was filled in is sent when adding');
      expect(d['valid_from'], isNotNull);
      expect(find.text('Dan Future'), findsOneWidget, reason: 'back on the list, with the new guest');
    });

    testWidgets('an end date is picked from a calendar, and can be cleared', (tester) async {
      await open(tester, const VipScreen(workspace: manager));
      await tapKey(tester, 'vip-add');
      expect(find.text('No end date'), findsOneWidget);
      await tapKey(tester, 'valid-until-value');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('No end date'), findsNothing);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('No end date'), findsOneWidget);
    });

    testWidgets('if saving is refused everything typed stays, with the reason', (tester) async {
      db.role = 'server';
      await open(tester, const VipFormScreen(venueId: 'v1'));
      await typeIn(tester, 'vip-name', 'Dan Future');
      await typeIn(tester, 'vip-email', 'dan@example.com');
      await tapKey(tester, 'vip-save');
      expect(find.text("You don't have access to do that."), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('vip-name'))).controller!.text, 'Dan Future');
    });

    testWidgets('changing a guest sends every field, so a cleared one is cleared', (tester) async {
      final profile = await db.service.detail('m1');
      await open(tester, VipFormScreen(venueId: 'v1', existing: profile));
      expect(tester.widget<TextField>(find.byKey(const Key('vip-name'))).controller!.text, 'Ada Lovelace');
      await typeIn(tester, 'vip-tier', 'Platinum');
      await typeIn(tester, 'vip-prefs', '');
      await tapKey(tester, 'vip-save');
      final d = db.calledWith('vip_update').single['p_details'] as Map;
      expect(d['tier'], 'Platinum');
      expect(d['preferences'], isNull);
      expect(d.containsKey('preferences'), isTrue, reason: 'a null clears it');
      expect(db.member('m1').preferences, isNull);
    });
  });

  group('A guest', () {
    Future<void> profile(WidgetTester tester, [String id = 'm1']) => open(tester, VipProfileScreen(memberId: id, venueId: 'v1'));

    testWidgets('shows contact, notes, code and every perk with its use', (tester) async {
      await profile(tester);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byKey(const Key('vip-profile-email')), findsOneWidget);
      expect(find.byKey(const Key('vip-notes-shown')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('vip-code'))).data, 'Credential code: ADA00001');
      expect(find.text('Entry · 0 of 1 tonight'), findsOneWidget);
      expect(find.text('Discount · 0 of 3 in total'), findsOneWidget);
    });

    testWidgets('redeeming a perk records it, shows the use, and stops at the limit', (tester) async {
      await profile(tester);
      await tapKey(tester, 'vip-redeem-k1');
      expect(find.text('Priority entry recorded. No uses left.'), findsOneWidget);
      expect(find.text('Entry · 1 of 1 tonight'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('vip-redeem-k1'))).onPressed, isNull, reason: 'used up');
      expect(find.byKey(const Key('vip-visit-0')), findsOneWidget);
      expect(db.calledWith('vip_redeem').single['p_perk'], 'k1');
    });

    testWidgets('adding a perk takes a kind, a name, a limit and a period', (tester) async {
      await profile(tester);
      await tapKey(tester, 'vip-add-perk');
      await tapKey(tester, 'perk-save');
      expect(find.text('Say what the perk is.'), findsOneWidget);
      await tapKey(tester, 'perk-kind-entry');
      await typeIn(tester, 'perk-label', 'Fast lane');
      await typeIn(tester, 'perk-max', '2');
      await tapKey(tester, 'perk-period-total');
      await tapKey(tester, 'perk-save');
      expect(find.text('Perk added.'), findsOneWidget);
      expect(db.calledWith('vip_add_perk').single, {'p_member': 'm1', 'p_kind': 'entry', 'p_label': 'Fast lane', 'p_max_uses': 2, 'p_period': 'total'});
      expect(find.text('Entry · 0 of 2 in total'), findsOneWidget);
    });

    testWidgets('a perk can be ended, and is then struck through with no Redeem', (tester) async {
      await profile(tester);
      await tapKey(tester, 'vip-end-perk-k2');
      expect(find.text('Perk ended.'), findsOneWidget);
      expect(find.byKey(const Key('vip-redeem-k2')), findsNothing);
      expect(find.textContaining('ended'), findsWidgets);
    });

    testWidgets('inviting queues it and says it has NOT been sent', (tester) async {
      await profile(tester);
      await tapKey(tester, 'vip-invite');
      expect(find.text('Invitation queued. It has not been sent yet.'), findsOneWidget);
      expect(find.byKey(const Key('vip-invited')), findsOneWidget);
      expect(find.text('Invite again'), findsOneWidget);
      await tapKey(tester, 'vip-invite');
      expect(find.text('An invitation was queued a moment ago.'), findsOneWidget);
    });

    testWidgets('a guest with no email is not offered an invitation', (tester) async {
      await profile(tester, 'm2');
      expect(find.byKey(const Key('vip-invite')), findsNothing);
    });

    testWidgets('ending a membership needs a reason; an ended one can be reinstated', (tester) async {
      await profile(tester);
      await tapKey(tester, 'vip-end');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why the membership is ending.'), findsOneWidget);
      await typeIn(tester, 'text-field', 'asked to leave');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Membership ended.'), findsOneWidget);
      expect(find.text('Gold · Ended'), findsOneWidget);
      expect(find.byKey(const Key('vip-ended-reason')), findsOneWidget);
      expect(find.byKey(const Key('vip-end')), findsNothing);
      expect(tester.widget<TextButton>(find.byKey(const Key('vip-add-perk'))).onPressed, isNull, reason: 'no perks for an ended guest');
      await tapKey(tester, 'vip-reinstate');
      expect(find.text('Membership restored.'), findsOneWidget);
      expect(find.text('Gold · Active'), findsOneWidget);
    });
  });

  group('Lookup (server)', () {
    Widget lookup() => VipLookupScreen(venueId: 'v1', clock: fridayNight);

    testWidgets('three letters are needed; then a server sees service perks and preferences only', (tester) async {
      db.role = 'server';
      await open(tester, lookup());
      await typeIn(tester, 'lookup-query', 'ad');
      await tapKey(tester, 'lookup-go');
      expect(find.text('Type at least 3 letters of the name, or the credential code.'), findsOneWidget);
      expect(db.calledWith('vip_lookup'), isEmpty);
      await typeIn(tester, 'lookup-query', 'ada');
      await tapKey(tester, 'lookup-go');
      expect(db.calledWith('vip_lookup').single, {'p_venue': 'v1', 'p_query': 'ada', 'p_night': '2026-10-09'});
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.byKey(const Key('lookup-prefs-m1')), findsOneWidget);
      expect(find.byKey(const Key('lookup-contact-m1')), findsNothing, reason: 'a server sees no contact details');
      expect(find.byKey(const Key('lookup-notes-m1')), findsNothing);
      expect(find.text('Welcome shot'), findsOneWidget);
      expect(find.text('Priority entry'), findsNothing);
      expect(find.text('10 percent off'), findsNothing);
    });

    testWidgets('redeeming a service perk records it and shows it used', (tester) async {
      db.role = 'server';
      await open(tester, lookup());
      await typeIn(tester, 'lookup-query', 'ada');
      await tapKey(tester, 'lookup-go');
      await tapKey(tester, 'lookup-redeem-k2');
      expect(find.text('Welcome shot recorded. No uses left.'), findsOneWidget);
      expect(db.calledWith('vip_redeem').single, {'p_perk': 'k2', 'p_night': '2026-10-09', 'p_note': null});
      expect(find.text('Used'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('lookup-redeem-k2'))).onPressed, isNull);
    });

    testWidgets('an ended membership is shown as such with no benefits to give', (tester) async {
      await open(tester, lookup());
      await typeIn(tester, 'lookup-query', 'cleo');
      await tapKey(tester, 'lookup-go');
      expect(tester.widget<Text>(find.byKey(const Key('lookup-status-m3'))).data, startsWith('VIP · Ended'));
      expect(find.byKey(const Key('lookup-no-benefits')), findsOneWidget);
    });

    testWidgets('a manager also sees contact and notes; no match is said in words', (tester) async {
      await open(tester, lookup());
      await typeIn(tester, 'lookup-query', 'ada');
      await tapKey(tester, 'lookup-go');
      expect(find.byKey(const Key('lookup-contact-m1')), findsOneWidget);
      expect(find.byKey(const Key('lookup-notes-m1')), findsOneWidget);
      await typeIn(tester, 'lookup-query', 'nobody');
      await tapKey(tester, 'lookup-go');
      expect(find.byKey(const Key('lookup-none')), findsOneWidget);
    });

    testWidgets('someone with no access is told, and sees nothing', (tester) async {
      db.role = 'security';
      await open(tester, lookup());
      await typeIn(tester, 'lookup-query', 'ada');
      await tapKey(tester, 'lookup-go');
      expect(find.text("You don't have access to do that."), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
    });
  });
}
