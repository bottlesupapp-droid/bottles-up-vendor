import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/complimentary/providers/complimentary_providers.dart';
import 'package:bottles_up_vendor/features/complimentary/screens/complimentary_screen.dart';
import 'package:bottles_up_vendor/features/inventory/providers/inventory_providers.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_offers_backend.dart';

// The Complimentary bottles screen (website 20261123100000; brief section 20). The list, the form for a new offer, and each step from there. Which steps are open is whatever the database says (`actions`).
// The link is e-mailed from the offer's sheet (see complimentary_send_test.dart).

late FakeOffersBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget host(Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    complimentaryServiceProvider.overrideWithValue(db.service),
    inventoryServiceProvider.overrideWithValue(db.inventory),
    ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'published')]),
  ],
  child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
);

Future<void> open(WidgetTester tester, Workspace w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ComplimentaryScreen(workspace: w, clock: () => DateTime(2026, 10, 9, 22))));
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

String label(WidgetTester tester, String key) => tester.widget<BuStatusPill>(find.byKey(Key(key))).label;
String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

const actionKeys = ['offer-action-set_location', 'offer-action-accept', 'offer-action-mark_delivered', 'offer-action-cancel'];
List<String> shownActions(WidgetTester tester) => [
  for (final k in actionKeys)
    if (find.byKey(Key(k)).evaluate().isNotEmpty) k,
];

Future<void> openOffer(WidgetTester tester, String id) async {
  // A card lets one tap through per double-tap time, so a person who opens the same offer again does so a moment later, not in the same instant.
  await tester.pump(const Duration(milliseconds: 400));
  await tapKey(tester, 'offer-$id');
}

void main() {
  setUp(() => db = FakeOffersBackend());

  group('The list', () {
    testWidgets('the manager sees each offer with who it is for and its state, under a note that says how the link is sent', (tester) async {
      db.offers = [offerRow(), offerRow(id: 'o2', status: 'location_submitted', location: 'Booth 1', setBy: 'recipient', name: null, email: 'zed@x.example'), offerRow(id: 'o3', status: 'delivered')];
      await open(tester, manager);
      expect(db.paramsOf('comp_offers_list').single, {'p_venue': 'v1'});
      expect(textOf(tester, 'offers-note'), contains('press E-mail the link'));
      expect(find.text('Club A'), findsOneWidget);
      expect(
        [
          for (final id in ['o1', 'o2', 'o3']) label(tester, 'offer-status-$id'),
        ],
        ['Approved', 'Location submitted', 'Delivered'],
      );
      expect(find.descendant(of: find.byKey(const Key('offer-o1')), matching: find.textContaining('2 × Patron · 750ml')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('offer-o1')), matching: find.textContaining('Gina · gina@x.example')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('offer-o1')), matching: find.textContaining('has not been e-mailed yet')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('offer-o2')), matching: find.textContaining('zed@x.example')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('offer-o2')), matching: find.textContaining('Booth 1')), findsOneWidget);
    });

    testWidgets('the owner chooses a club first, and can choose another', (tester) async {
      await open(tester, owner);
      expect(db.count('comp_offers_list'), 0);
      await tapKey(tester, 'offers-club-v2');
      expect(db.paramsOf('comp_offers_list').single, {'p_venue': 'v2'});
      await tapKey(tester, 'offers-change-club');
      expect(find.byKey(const Key('offers-pick-club')), findsOneWidget);
    });

    testWidgets('no offers, a server without the migration, a lost connection and a refusal are said in words', (tester) async {
      await open(tester, manager);
      expect(find.byKey(const Key('offers-empty')), findsOneWidget);
      db.missing = true;
      await open(tester, manager);
      expect(textOf(tester, 'offers-error'), 'The offers are not set up on this server yet.');
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, manager);
      expect(find.byKey(const Key('offers-error')), findsOneWidget);
      db.offline = false;
      db.offers = [offerRow()];
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('offer-o1')), findsOneWidget);
      db.handlers['comp_offers_list'] = (_) => throw refuse('not allowed');
      await open(tester, manager);
      expect(find.byKey(const Key('offers-error')), findsOneWidget);
    });
  });

  group('A new offer', () {
    testWidgets('the form checks what is typed, then sends it; the list is read again and the message says nothing has been sent', (tester) async {
      await open(tester, manager);
      await tapKey(tester, 'offer-new');
      expect(db.count('stock_list'), 1, reason: 'the bottles come from the club\'s menu');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Choose the bottle.'), findsOneWidget);
      await tapKey(tester, 'offer-bottle');
      await tester.tap(find.text('Patron · 750ml').last);
      await tester.pumpAndSettle();
      await typeIn(tester, 'offer-quantity', '13');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Choose from 1 to 12 bottles.'), findsOneWidget);
      await typeIn(tester, 'offer-quantity', '2');
      await typeIn(tester, 'offer-email', 'gina');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter the e-mail address the link is for.'), findsOneWidget);
      await typeIn(tester, 'offer-email', 'gina@x.example');
      await typeIn(tester, 'offer-reason', 'x');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why, in at least 3 characters. It is kept with the offer.'), findsOneWidget);
      expect(db.count('comp_offer_create'), 0, reason: 'nothing is sent until it is right');
      await typeIn(tester, 'offer-reason', 'Birthday table');
      await typeIn(tester, 'offer-name', 'Gina');
      await typeIn(tester, 'offer-sign', 'Happy Birthday');
      await tapKey(tester, 'offer-expiry');
      await tester.tap(find.text('3 days').last);
      await tester.pumpAndSettle();
      final lists = db.count('comp_offers_list');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('comp_offer_create').single, {
        'p_venue': 'v1',
        'p_bottle': 'p1',
        'p_quantity': 2,
        'p_email': 'gina@x.example',
        'p_name': 'Gina',
        'p_reason': 'Birthday table',
        'p_sign': 'Happy Birthday',
        'p_event': null,
        'p_expires_hours': 72,
      });
      expect(find.text('The offer is made. Open it and press E-mail the link to send it.'), findsOneWidget);
      expect(db.count('comp_offers_list'), greaterThan(lists));
    });

    testWidgets('backing out sends nothing, and a menu that cannot be read is said in words', (tester) async {
      await open(tester, manager);
      await tapKey(tester, 'offer-new');
      await tapKey(tester, 'dialog-back');
      expect(db.count('comp_offer_create'), 0);
      db.handlers['stock_list'] = (_) => throw Exception('SocketException: connection lost');
      await tapKey(tester, 'offer-new');
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });

    testWidgets('a refusal (the club has not set its limits) is the database\'s sentence', (tester) async {
      db.handlers['comp_offer_create'] = (_) => throw refuse('free bottles are not set up for this club yet: the owner sets the limits first');
      await open(tester, manager);
      await tapKey(tester, 'offer-new');
      await tapKey(tester, 'offer-bottle');
      await tester.tap(find.text('Vodka').last);
      await tester.pumpAndSettle();
      await typeIn(tester, 'offer-email', 'gina@x.example');
      await typeIn(tester, 'offer-reason', 'Birthday');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Free bottles are not set up for this club yet: the owner sets the limits first.'), findsOneWidget);
      expect(db.paramsOf('comp_offer_create').single!['p_expires_hours'], 24, reason: 'the link lasts 24 hours unless staff choose otherwise');
    });
  });

  group('An offer', () {
    testWidgets('the steps offered are exactly what the database says are open', (tester) async {
      for (final entry in {'set_location': 'offer-action-set_location', 'accept': 'offer-action-accept', 'mark_delivered': 'offer-action-mark_delivered', 'cancel': 'offer-action-cancel'}.entries) {
        db.offers = [
          offerRow(actions: [entry.key]),
        ];
        await open(tester, manager);
        await openOffer(tester, 'o1');
        expect(shownActions(tester), [entry.value], reason: entry.key);
      }
      db.offers = [offerRow(status: 'delivered')];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      expect(shownActions(tester), isEmpty);
      expect(find.byKey(const Key('offer-sheet-nothing')), findsOneWidget);
    });

    testWidgets('the sheet shows what the offer is, why, where, and what became of the free bottle', (tester) async {
      db.offers = [offerRow(status: 'accepted', location: 'Booth 1', setBy: 'recipient', concession: 'pending', booking: 'b1')];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      expect(textOf(tester, 'offer-sheet-item'), '2 × Patron · 750ml');
      expect(textOf(tester, 'offer-sheet-status'), 'Accepted for service · A free bottle is on the booking');
      expect(textOf(tester, 'offer-sheet-place'), 'Place: Booth 1 (chosen by the recipient)');
      expect(textOf(tester, 'offer-sheet-concession'), 'Free bottle waiting for approval (over the club\'s limit)');
      expect(find.text('Why: Birthday table'), findsOneWidget);
      db.offers = [offerRow(status: 'location_submitted', location: 'Booth 2', setBy: 'staff')];
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await open(tester, manager);
      await openOffer(tester, 'o1');
      expect(textOf(tester, 'offer-sheet-place'), 'Place: Booth 2 (chosen by staff)');
      expect(find.text('Sign: Happy Birthday'), findsOneWidget);
      expect(find.textContaining('recorded as complimentary, never as a sale'), findsOneWidget);
    });

    testWidgets('placing at a table: the club\'s tables are listed by label and the chosen one is sent', (tester) async {
      db.offers = [offerRow()];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-set_location');
      expect(find.text('Booth 1 · Main floor'), findsOneWidget);
      expect(find.text('Booth 2'), findsOneWidget);
      await tapKey(tester, 'offer-table-t1');
      expect(db.paramsOf('comp_offer_set_location').single, {'p_offer': 'o1', 'p_table': 't1'});
      expect(find.text('Placed at Booth 1. Now choose the booking.'), findsOneWidget);
    });

    testWidgets('accepting: the bookings at that table tonight are listed, the chosen one is sent, and the guest is told it is on their booking', (tester) async {
      db.offers = [offerRow(status: 'location_submitted', location: 'Booth 1', setBy: 'recipient')];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-accept');
      expect(db.paramsOf('comp_offer_bookings').single, {'p_offer': 'o1', 'p_night': '2026-10-09'});
      expect(find.text('Which booking at Booth 1?'), findsOneWidget);
      expect(find.text('Ada Evening · Booth 1 · 2 guests · ADA-EVENING'), findsOneWidget);
      await tapKey(tester, 'offer-booking-b1');
      expect(db.paramsOf('comp_offer_accept').single, {'p_offer': 'o1', 'p_booking': 'b1'});
      expect(find.text('Accepted. A free bottle is on Ada Evening\'s booking.'), findsOneWidget);
    });

    testWidgets('over the club\'s limit, accepting says the free bottle waits for the owner', (tester) async {
      db.offers = [offerRow(status: 'location_submitted', location: 'Booth 1', setBy: 'staff')];
      db.handlers['comp_offer_accept'] = (_) => {'status': 'accepted', 'concession_status': 'pending'};
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-accept');
      await tapKey(tester, 'offer-booking-b1');
      expect(find.text('Accepted. The free bottle is over the club\'s limit, so it waits for the owner to approve it.'), findsOneWidget);
    });

    testWidgets('with no confirmed booking at that table tonight it says so and sends nothing', (tester) async {
      db.offers = [offerRow(status: 'location_submitted', location: 'Booth 1', setBy: 'staff')];
      db.bookings = [];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-accept');
      expect(textOf(tester, 'offer-no-bookings'), 'There is no confirmed booking at Booth 1 tonight.');
      expect(db.count('comp_offer_accept'), 0);
    });

    testWidgets('marking delivered asks first; backing out sends nothing', (tester) async {
      db.offers = [offerRow(status: 'accepted', location: 'Booth 1', setBy: 'staff', concession: 'applied')];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-mark_delivered');
      expect(textOf(tester, 'offer-confirm-message'), '2 × Patron · 750ml for Gina · gina@x.example has reached the table.');
      await tapKey(tester, 'confirm-back');
      expect(db.count('comp_offer_mark_delivered'), 0);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-mark_delivered');
      await tapKey(tester, 'confirm-yes');
      expect(db.paramsOf('comp_offer_mark_delivered').single, {'p_offer': 'o1'});
      expect(find.text('Marked as delivered.'), findsOneWidget);
    });

    testWidgets('cancelling needs a reason, then sends it', (tester) async {
      db.offers = [offerRow()];
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-cancel');
      await typeIn(tester, 'text-field', 'x');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why, in at least 3 characters.'), findsOneWidget);
      expect(db.count('comp_offer_cancel'), 0);
      await typeIn(tester, 'text-field', 'The guest cannot come');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('comp_offer_cancel').single, {'p_offer': 'o1', 'p_reason': 'The guest cannot come'});
      expect(find.text('The offer is cancelled.'), findsOneWidget);
    });

    testWidgets('a refusal is the database\'s sentence and the list is read again to show what is true now', (tester) async {
      db.offers = [offerRow(status: 'location_submitted', location: 'Booth 1', setBy: 'staff')];
      db.handlers['comp_offer_accept'] = (_) {
        db.offers = [offerRow(status: 'expired')];
        throw refuse('this offer has expired');
      };
      await open(tester, manager);
      await openOffer(tester, 'o1');
      await tapKey(tester, 'offer-action-accept');
      final before = db.count('comp_offers_list');
      await tapKey(tester, 'offer-booking-b1');
      expect(find.text('This offer has expired.'), findsOneWidget);
      expect(db.count('comp_offers_list'), greaterThan(before));
      expect(label(tester, 'offer-status-o1'), 'Expired');
    });
  });
}
