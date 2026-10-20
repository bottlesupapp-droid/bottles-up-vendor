import 'dart:async';

import 'package:bottles_up_vendor/features/discounts/providers/discount_providers.dart';
import 'package:bottles_up_vendor/features/discounts/screens/discounts_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_discount_backend.dart';

late FakeDiscountBackend db;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget host(Workspace ws) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        discountServiceProvider.overrideWithValue(db.service),
        ownerVenuesProvider.overrideWith((ref, orgId) async => [const OrgVenue(id: 'v1', name: 'Club A', status: 'published')]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: DiscountsScreen(workspace: ws))),
    );

Future<void> open(WidgetTester tester, Workspace ws) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ws));
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

String field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
bool saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('limits-save'))).onPressed != null;

const set10 = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};

void main() {
  setUp(() {
    db = FakeDiscountBackend()..role = 'manager';
    db.limits = Map.of(set10);
    db.addBooking('b1');
  });

  group('waiting for approval', () {
    testWidgets('lists what waits, with who asked, why, and the buttons for what the manager may decide', (tester) async {
      final ok = db.addConcession('b1', amount: 4000, percent: 20, status: 'pending');
      await open(tester, manager);
      expect(find.byKey(Key('pending-${ok.id}')), findsOneWidget);
      expect(find.text('20% discount: \$40.00 off'), findsOneWidget);
      expect(find.text('Ada Lovelace · VIP booth · AB12CD'), findsOneWidget);
      expect(find.text('Regular guest'), findsOneWidget);
      expect(find.textContaining('Asked by Sam Server (server)'), findsOneWidget);
      expect(find.byKey(Key('approve-${ok.id}')), findsOneWidget);
      expect(find.byKey(Key('decline-${ok.id}')), findsOneWidget);
    });

    testWidgets('your own request, and one above what a manager may approve, have no buttons and say why', (tester) async {
      final own = db.addConcession('b1', by: 'u-me', byRole: 'manager', amount: 4000, percent: 20);
      final big = db.addConcession('b1', amount: 10000, percent: 50);
      await open(tester, manager);
      for (final c in [own, big]) {
        expect(find.byKey(Key('approve-${c.id}')), findsNothing);
        expect(find.byKey(Key('cannot-${c.id}')), findsOneWidget);
      }
    });

    testWidgets('the owner can decide the big one', (tester) async {
      db.role = 'owner';
      final big = db.addConcession('b1', amount: 10000, percent: 50);
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      expect(find.byKey(Key('approve-${big.id}')), findsOneWidget);
    });

    testWidgets('approving applies it and takes it off the list', (tester) async {
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await open(tester, manager);
      await tapKey(tester, 'approve-${c.id}');
      expect(find.text('Approve 20% discount: \$40.00 off?'), findsOneWidget);
      await tapKey(tester, 'decide-go');
      expect(db.paramsOf('desk_decide_concession').single, {'p_id': c.id, 'p_approve': true, 'p_note': null});
      expect(find.text('Approved: 20% discount: \$40.00 off. It is applied to the table.'), findsOneWidget);
      expect(find.byKey(Key('pending-${c.id}')), findsNothing);
      expect(find.byKey(const Key('discounts-empty')), findsOneWidget);
      expect(db.bookings['b1']!.discount, 4000);
    });

    testWidgets('declining needs a reason the person can be told', (tester) async {
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await open(tester, manager);
      await tapKey(tester, 'decline-${c.id}');
      await tapKey(tester, 'decide-go');
      expect(find.text('Say why it is declined, so the person can be told.'), findsOneWidget);
      expect(db.paramsOf('desk_decide_concession'), isEmpty);
      await enter(tester, 'decide-note', 'Too generous');
      await tapKey(tester, 'decide-go');
      expect(db.paramsOf('desk_decide_concession').single, {'p_id': c.id, 'p_approve': false, 'p_note': 'Too generous'});
      expect(find.text('Declined: 20% discount: \$40.00 off.'), findsOneWidget);
    });

    testWidgets('the database refusing is shown in the dialog', (tester) async {
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await open(tester, manager);
      await tapKey(tester, 'approve-${c.id}');
      c.status = 'declined';
      await tapKey(tester, 'decide-go');
      expect(find.text('This request has already been decided.'), findsOneWidget);
    });

    testWidgets('Not now closes it and changes nothing', (tester) async {
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await open(tester, manager);
      await tapKey(tester, 'approve-${c.id}');
      await tapKey(tester, 'decide-back');
      expect(db.paramsOf('desk_decide_concession'), isEmpty);
      expect(find.byKey(Key('pending-${c.id}')), findsOneWidget);
    });

    testWidgets('a second tap while the first is going decides once', (tester) async {
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await open(tester, manager);
      await tapKey(tester, 'approve-${c.id}');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('decide-go')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('decide-go'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_decide_concession'), hasLength(1));
    });

    testWidgets('a free bottle request reads as one', (tester) async {
      db.addConcession('b1', kind: 'free_bottle', quantity: 2, amount: 50000);
      await open(tester, manager);
      expect(find.text('2 × Patron free'), findsOneWidget);
    });

    testWidgets('nothing waiting says so', (tester) async {
      await open(tester, manager);
      expect(find.text('Nothing is waiting for approval.'), findsOneWidget);
    });

    testWidgets('a failed read says so with Try again', (tester) async {
      db.failAll = Exception('boom');
      await open(tester, manager);
      expect(find.byKey(const Key('discounts-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.failAll = null;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('discounts-error')), findsNothing);
    });
  });

  group('for an owner', () {
    testWidgets('the owner picks the club first', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      expect(find.byKey(const Key('discounts-pick-club')), findsOneWidget);
      expect(db.paramsOf('desk_pending_concessions'), isEmpty);
      await tapKey(tester, 'discounts-club-v1');
      expect(find.byKey(const Key('discounts-waiting')), findsOneWidget);
      expect(db.paramsOf('desk_pending_concessions').single, {'p_venue': 'v1'});
    });
  });

  group('the limits', () {
    testWidgets('a manager reads them in words and cannot change them', (tester) async {
      await open(tester, manager);
      await tapKey(tester, 'tab-limits');
      expect(find.text('A server may give up to 10% off and 2 free bottles a night.'), findsOneWidget);
      expect(find.text('A manager may give up to 25% off, and the managers share 4 free bottles a night.'), findsOneWidget);
      expect(find.text('Only one discount may be on a table.'), findsOneWidget);
      expect(find.byKey(const Key('limits-owner-only')), findsOneWidget);
      expect(find.byKey(const Key('limits-save')), findsNothing);
    });

    testWidgets('with no limits set, a manager is told nobody but the owner can give anything', (tester) async {
      db.limits = null;
      await open(tester, manager);
      await tapKey(tester, 'tab-limits');
      expect(find.textContaining('No limits are set'), findsOneWidget);
    });

    testWidgets('the owner sees the saved limits in the boxes, with nothing to save yet', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      expect([field(tester, 'limit-server-percent'), field(tester, 'limit-manager-percent'), field(tester, 'limit-server-bottles'), field(tester, 'limit-manager-bottles')], ['10', '25', '2', '4']);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('limit-stacking'))).value, isFalse);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('the owner changes them and saves all five', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      await enter(tester, 'limit-server-percent', '15');
      await enter(tester, 'limit-manager-bottles', '8');
      await tapKey(tester, 'limit-stacking');
      expect(saveEnabled(tester), isTrue);
      await tapKey(tester, 'limits-save');
      expect(db.paramsOf('save_venue_discount_limits').single, {
        'p_venue': 'v1',
        'p_details': {'server_max_percent': 15, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 8, 'allow_stacking': true},
      });
      expect(find.textContaining('Saved. Servers and managers can give discounts'), findsOneWidget);
      expect(db.limits!['server_max_percent'], 15);
      expect(find.text('A server may give up to 15% off and 2 free bottles a night.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a club with no limits yet starts at zero and can save them', (tester) async {
      db.role = 'owner';
      db.limits = null;
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      expect(field(tester, 'limit-server-percent'), '0');
      expect(saveEnabled(tester), isTrue);
      await enter(tester, 'limit-manager-percent', '20');
      await tapKey(tester, 'limits-save');
      expect(db.limits, isNotNull);
      expect(db.limits!['manager_max_percent'], 20);
    });

    testWidgets('a server allowed more than a manager is said before anything is sent', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      await enter(tester, 'limit-server-percent', '30');
      await tapKey(tester, 'limits-save');
      expect(find.text('A server cannot be allowed a bigger discount than a manager.'), findsOneWidget);
      expect(db.paramsOf('save_venue_discount_limits'), isEmpty);
    });

    testWidgets('a number out of range or not a number is said', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      await enter(tester, 'limit-server-percent', 'x');
      await enter(tester, 'limit-manager-bottles', '501');
      await tapKey(tester, 'limits-save');
      expect(find.text('A server\'s discount limit is a whole number from 0 to 100.'), findsOneWidget);
      expect(find.text('The managers\' free bottles a night is a whole number from 0 to 500.'), findsOneWidget);
    });

    testWidgets('a connection failure keeps what was typed and says what to do', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      await enter(tester, 'limit-server-percent', '15');
      db.beforeCall = (f) {
        if (f == 'save_venue_discount_limits') throw Exception('socket closed');
      };
      await tapKey(tester, 'limits-save');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      expect(field(tester, 'limit-server-percent'), '15');
    });

    testWidgets('a second tap on Save while the first is going saves once', (tester) async {
      db.role = 'owner';
      await open(tester, owner);
      await tapKey(tester, 'discounts-club-v1');
      await tapKey(tester, 'tab-limits');
      await enter(tester, 'limit-server-percent', '15');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('limits-save')));
      await tester.tap(find.byKey(const Key('limits-save')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('save_venue_discount_limits'), hasLength(1));
    });

    testWidgets('a failed read of the limits says so with Try again', (tester) async {
      db.beforeCall = (f) {
        if (f == 'venue_discount_limits') throw Exception('boom');
      };
      await open(tester, manager);
      await tapKey(tester, 'tab-limits');
      expect(find.byKey(const Key('limits-error')), findsOneWidget);
    });
  });
}
