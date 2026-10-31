import 'dart:async';

import 'package:bottles_up_vendor/features/bottle_signs/logic/sign_rules.dart';
import 'package:bottles_up_vendor/features/bottle_signs/providers/bottle_sign_providers.dart';
import 'package:bottles_up_vendor/features/bottle_signs/screens/bottle_signs_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sign_backend.dart';

// More > Bottle signs: how a club uses signs, which bottles, whether a manager approves servers' signs, and the signs waiting.

late FakeSignBackend db;

const managerWs = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const ownerWs = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Future<void> open(WidgetTester tester, Workspace ws) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      bottleSignServiceProvider.overrideWithValue(db.service),
      ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')]),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: BottleSignsScreen(workspace: ws))),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

SegmentedButton<SignMode> modeButton(WidgetTester tester) => tester.widget<SegmentedButton<SignMode>>(find.byKey(const Key('sign-mode')));

void main() {
  setUp(() {
    db = FakeSignBackend();
    db.bottles['p'] = FakeSignBottle('p', 'Patron', category: 'Tequila', eligible: true);
    db.bottles['g'] = FakeSignBottle('g', 'Grey Goose', category: 'Vodka');
    db.lines['l1'] = FakeSignLine('l1', 'b1', 'p', name: 'Patron', quantity: 2, guest: 'Ada Lovelace');
    db.lines['l2'] = FakeSignLine('l2', 'b1', 'g', name: 'Grey Goose', guest: 'Grace Hopper');
  });

  group('how signs work at the club', () {
    testWidgets('start off: the choice, what it means, and no bottle list', (tester) async {
      await open(tester, managerWs);
      expect(find.text('Bottle signs'), findsOneWidget);
      expect(modeButton(tester).selected, {SignMode.off});
      expect(find.text('Nobody can put a sign on an order.'), findsOneWidget);
      expect(find.byKey(const Key('sign-bottle-p')), findsNothing);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-review'))).value, isFalse);
      expect(db.calledWith('venue_sign_settings').single, {'p_venue': 'v1'});
    });

    testWidgets('choosing every bottle saves just the mode and says what it means', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'sign-mode-all');
      expect(db.calledWith('save_venue_sign_settings').single, {'p_venue': 'v1', 'p_details': {'mode': 'all'}});
      expect(db.mode, 'all');
      expect(find.text('Any bottle on the menu can carry a sign.'), findsOneWidget);
      expect(find.byKey(const Key('sign-bottle-p')), findsNothing);
    });

    testWidgets('choosing chosen bottles lists the menu; a bottle is switched on and off', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'sign-mode-selected');
      expect(db.mode, 'selected');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-bottle-p'))).value, isTrue);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-bottle-g'))).value, isFalse);
      expect(find.text('Tequila'), findsOneWidget);
      await tapKey(tester, 'sign-bottle-g');
      expect(db.calledWith('set_bottle_sign_eligible').single, {'p_venue': 'v1', 'p_bottle': 'g', 'p_eligible': true});
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-bottle-g'))).value, isTrue);
      await tapKey(tester, 'sign-bottle-p');
      expect(db.bottles['p']!.eligible, isFalse);
    });

    testWidgets('a club with no bottles on its menu is told so', (tester) async {
      db.bottles.clear();
      db.mode = 'selected';
      await open(tester, managerWs);
      expect(find.byKey(const Key('sign-no-bottles')), findsOneWidget);
    });

    testWidgets('the approval switch saves just that', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'sign-review');
      expect(db.calledWith('save_venue_sign_settings').single, {'p_venue': 'v1', 'p_details': {'review_required': true}});
      expect(db.review, isTrue);
      expect(db.mode, 'off', reason: 'the mode is not touched');
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-review'))).value, isTrue);
    });

    testWidgets('while a change is on its way the controls wait, so a second tap sends nothing more', (tester) async {
      await open(tester, managerWs);
      db.gates['save_venue_sign_settings'] = Completer<void>();
      await tester.tap(find.byKey(const Key('sign-mode-all')));
      await tester.pump();
      expect(modeButton(tester).onSelectionChanged, isNull);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('sign-review'))).onChanged, isNull);
      await tester.tap(find.byKey(const Key('sign-review')), warnIfMissed: false);
      await tester.pump();
      expect(db.calledWith('save_venue_sign_settings'), hasLength(1));
      db.gates['save_venue_sign_settings']!.complete();
      await tester.pumpAndSettle();
      expect(modeButton(tester).onSelectionChanged, isNotNull);
      expect(db.calledWith('save_venue_sign_settings'), hasLength(1));
    });

    testWidgets('a refusal is said in the database\'s words, and the screen looks again', (tester) async {
      await open(tester, managerWs);
      db.role = 'server';
      await tapKey(tester, 'sign-mode-all');
      expect(find.text('You don\'t have access to do that.'), findsWidgets);
      expect(db.mode, 'off');
    });

    testWidgets('a server without the migration is told it is not set up yet, with nothing to retry', (tester) async {
      db.missing = true;
      await open(tester, managerWs);
      expect(find.byKey(const Key('signs-error')), findsOneWidget);
      expect(find.textContaining('not set up on this server yet'), findsWidgets);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
    });

    testWidgets('a dropped connection says to try again, and trying again works', (tester) async {
      db.offline = true;
      await open(tester, managerWs);
      expect(find.byKey(const Key('signs-error')), findsOneWidget);
      db.offline = false;
      await tester.tap(find.byKey(const Key('ops-retry')).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sign-mode')), findsOneWidget);
    });
  });

  group('the owner', () {
    testWidgets('picks the club first, then it is the same screen for that club', (tester) async {
      await open(tester, ownerWs);
      expect(find.byKey(const Key('signs-pick-club')), findsOneWidget);
      expect(db.calls, isEmpty);
      await tapKey(tester, 'signs-club-v2');
      expect(db.calledWith('venue_sign_settings').single, {'p_venue': 'v2'});
      await tapKey(tester, 'sign-mode-all');
      expect(db.calledWith('save_venue_sign_settings').single['p_venue'], 'v2');
    });
  });

  group('signs waiting for approval', () {
    FakeSignLine waiting(String id) => db.lines[id]!
      ..text = 'Cheers'
      ..status = 'pending_review'
      ..setBy = 'u-sam';

    testWidgets('are listed with the words, the bottle, the guest and who wrote them', (tester) async {
      db.review = true;
      waiting('l1');
      await open(tester, managerWs);
      expect(find.byKey(const Key('pending-sign-l1')), findsOneWidget);
      expect(find.text('“Cheers”'), findsOneWidget);
      expect(find.text('2 × Patron · for Ada Lovelace · from Sam Server'), findsOneWidget);
      expect(find.byKey(const Key('pending-sign-l2')), findsNothing);
    });

    testWidgets('none waiting says so', (tester) async {
      await open(tester, managerWs);
      expect(find.byKey(const Key('pending-signs-empty')), findsOneWidget);
      expect(find.text('No sign is waiting for you.'), findsOneWidget);
    });

    testWidgets('approving sends the approval and the list looks again', (tester) async {
      db.review = true;
      waiting('l1');
      await open(tester, managerWs);
      await tapKey(tester, 'pending-approve-l1');
      expect(db.calledWith('desk_review_bottle_sign').single, {'p_line': 'l1', 'p_decision': 'approve', 'p_note': null});
      expect(find.text('Sign approved.'), findsOneWidget);
      expect(find.byKey(const Key('pending-sign-l1')), findsNothing);
      expect(find.byKey(const Key('pending-signs-empty')), findsOneWidget);
    });

    testWidgets('a second tap while approving sends nothing more', (tester) async {
      waiting('l1');
      await open(tester, managerWs);
      db.gates['desk_review_bottle_sign'] = Completer<void>();
      await tester.tap(find.byKey(const Key('pending-approve-l1')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('pending-approve-l1'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('pending-decline-l1'))).onPressed, isNull);
      db.gates['desk_review_bottle_sign']!.complete();
      await tester.pumpAndSettle();
      expect(db.calledWith('desk_review_bottle_sign'), hasLength(1));
    });

    testWidgets('declining asks for a reason; too short is said without sending anything', (tester) async {
      waiting('l1');
      await open(tester, managerWs);
      await tapKey(tester, 'pending-decline-l1');
      expect(find.text('"Cheers"'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('decline-reason')), 'no');
      await tapKey(tester, 'decline-confirm');
      expect(find.byKey(const Key('decline-error')), findsOneWidget);
      expect(find.text('Say why the sign is declined (at least 3 characters).'), findsOneWidget);
      expect(db.calledWith('desk_review_bottle_sign'), isEmpty);
    });

    testWidgets('declining with a reason sends it trimmed and the sign leaves the queue', (tester) async {
      waiting('l1');
      await open(tester, managerWs);
      await tapKey(tester, 'pending-decline-l1');
      await tester.enterText(find.byKey(const Key('decline-reason')), '  Please check the spelling ');
      await tapKey(tester, 'decline-confirm');
      expect(db.calledWith('desk_review_bottle_sign').single, {'p_line': 'l1', 'p_decision': 'reject', 'p_note': 'Please check the spelling'});
      expect(db.lines['l1']!.status, 'rejected');
      expect(find.text('Sign declined.'), findsOneWidget);
      expect(find.byKey(const Key('pending-sign-l1')), findsNothing);
    });

    testWidgets('backing out of the decline sends nothing', (tester) async {
      waiting('l1');
      await open(tester, managerWs);
      await tapKey(tester, 'pending-decline-l1');
      await tapKey(tester, 'decline-cancel');
      expect(db.calledWith('desk_review_bottle_sign'), isEmpty);
      expect(find.byKey(const Key('pending-sign-l1')), findsOneWidget);
    });

    testWidgets('the database refusing is shown in the dialog, which stays open', (tester) async {
      waiting('l1');
      await open(tester, managerWs);
      await tapKey(tester, 'pending-decline-l1');
      db.lines['l1']!.status = 'approved';
      await tester.enterText(find.byKey(const Key('decline-reason')), 'Too late now');
      await tapKey(tester, 'decline-confirm');
      expect(find.text('This sign was already reviewed.'), findsOneWidget);
      expect(find.byKey(const Key('decline-reason')), findsOneWidget);
    });
  });
}
