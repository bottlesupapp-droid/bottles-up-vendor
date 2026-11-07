import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/bottle_signs/widgets/signs_load_notice.dart';
import 'package:bottles_up_vendor/features/cash_review/providers/cash_providers.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/cash_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/summary_screen.dart';
import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart' show ChatPerson;
import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/chat/screens/chat_screen.dart';
import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:bottles_up_vendor/features/door_sales/providers/door_sales_providers.dart';
import 'package:bottles_up_vendor/features/door_sales/screens/door_sales_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/organizer_events_screen.dart';
import 'package:bottles_up_vendor/features/organizer_guests/providers/guest_providers.dart';
import 'package:bottles_up_vendor/features/organizer_guests/screens/organizer_guests_screen.dart';
import 'package:bottles_up_vendor/features/seating/providers/seating_providers.dart';
import 'package:bottles_up_vendor/features/seating/screens/server_scan_screen.dart';
import 'package:bottles_up_vendor/features/security/providers/security_providers.dart';
import 'package:bottles_up_vendor/features/security/screens/alerts_screen.dart';
import 'package:bottles_up_vendor/features/security/screens/tasks_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/desk_chip.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/screens/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

import '../cash_review/fake_cash_backend.dart';
import '../chat/fake_chat_backend.dart';
import '../door/fake_door_backend.dart';
import '../door_sales/fake_door_sales_backend.dart';
import '../organizer_events/fake_organizer_events_backend.dart' as oe;
import '../organizer_guests/organizer_guests_test.dart' show FakeGuestBackend;
import '../seating/fake_seating_backend.dart';
import '../security/fake_security_backend.dart';
import '../table_service/fake_table_backend.dart';
import '../team/fake_team_backend.dart' as tm;
import 'role_test_support.dart';

void main() {
  setUpAll(loadInter);

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the verifier: Review, Cash and Summary', () {
    testWidgets('Review has a Payments eyebrow, "Payments to check", the club, and a card per payment', (tester) async {
      final db = FakeTableBackend()..role = 'verifier';
      db.now = DateTime(2026, 10, 9, 21);
      db.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);
      db.addPayment('b1', 3000);
      db.addPayment('b1', 500, status: 'disputed');
      await showScreen(tester, PaymentReviewScreen(workspace: verifierWs, clock: friday9pm), [tableServiceServiceProvider.overrideWithValue(db.service)]);
      expect(find.text('PAYMENTS'), findsOneWidget);
      expect(find.text('Payments to check'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.text('2 payments waiting'), findsOneWidget);
      final cards = find.byWidgetPredicate((w) => w is BuCard && w.key.toString().contains('review-'));
      expect(cards, findsNWidgets(2));
      final states = tester.widgetList<DeskChip>(find.byWidgetPredicate((w) => w is DeskChip && w.key.toString().contains('review-state-'))).toList();
      expect({for (final c in states) c.text: c.color}, {'Pending': bu.amber, 'Disputed': bu.red});
    });

    testWidgets('why a payment cannot be checked is said in amber, and the button to check it is the one orange button', (tester) async {
      final db = FakeTableBackend()..role = 'verifier';
      db.now = DateTime(2026, 10, 9, 21);
      db.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);
      db.addPayment('b1', 500, status: 'disputed');
      db.addPayment('b1', 3000);
      await showScreen(tester, PaymentReviewScreen(workspace: verifierWs, clock: friday9pm), [tableServiceServiceProvider.overrideWithValue(db.service)]);
      final why = find.byWidgetPredicate((w) => w is Text && w.key.toString().contains('review-why-'));
      expect(why, findsOneWidget);
      expect(textColor(tester, why), bu.amber);
      expect(find.byWidgetPredicate((w) => w is FilledButton && w.key.toString().contains('verify-')), findsOneWidget);
    });

    testWidgets('nothing waiting is said in a card', (tester) async {
      final db = FakeTableBackend()..role = 'verifier';
      await showScreen(tester, PaymentReviewScreen(workspace: verifierWs, clock: friday9pm), [tableServiceServiceProvider.overrideWithValue(db.service)]);
      expect(find.ancestor(of: find.byKey(const Key('review-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });

    FakeCashBackend cash() {
      final db = FakeCashBackend();
      db.collected['u-sam'] = 7800;
      db.collected['u-me'] = 2000;
      db.handovers
        ..add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10)))
        ..add(FakeHandover('h2', 'u-bea', 4000, DateTime(2026, 10, 9, 22, 40), status: 'acknowledged', counted: 3900, receivedBy: 'u-me'))
        ..add(FakeHandover('h3', 'u-bea', 1000, DateTime(2026, 10, 9, 22, 50), status: 'acknowledged', counted: 1000, receivedBy: 'u-me'));
      return db;
    }

    testWidgets('Cash has a Payments eyebrow, two section titles, and a card per person and per handover', (tester) async {
      await showScreen(tester, CashScreen(workspace: verifierWs, clock: friday9pm), [cashServiceProvider.overrideWithValue(cash().service)]);
      expect(find.text('PAYMENTS'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Cash held'), findsOneWidget);
      expect(find.text('Handovers'), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('cash-line-0'))).padding, EdgeInsets.zero);
      expect(find.byKey(const Key('handover-h1')), findsOneWidget);
    });

    testWidgets('a counted handover shows its difference: amber when short, green when it matched', (tester) async {
      await showScreen(tester, CashScreen(workspace: verifierWs, clock: friday9pm), [cashServiceProvider.overrideWithValue(cash().service)]);
      expect(textColor(tester, find.byKey(const Key('difference-h2'))), bu.amber);
      expect(textColor(tester, find.byKey(const Key('difference-h3'))), bu.green);
    });

    testWidgets('a handover waiting to be counted has the one orange "Count" button', (tester) async {
      await showScreen(tester, CashScreen(workspace: verifierWs, clock: friday9pm), [cashServiceProvider.overrideWithValue(cash().service)]);
      expect(tester.widget<FilledButton>(find.byKey(const Key('count-h1'))).onPressed, isNotNull);
    });

    testWidgets('Summary lists the night\'s figures in one grouped card, a figure that needs a person amber when it is not zero', (tester) async {
      await showScreen(tester, VerifierSummaryScreen(workspace: verifierWs, clock: friday9pm), [cashServiceProvider.overrideWithValue(cash().service)]);
      expect(find.text('PAYMENTS'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.byType(BuListCard), findsOneWidget);
      for (final k in ['summary-recorded', 'summary-checked', 'summary-to-check', 'summary-disputed', 'summary-flags-open', 'summary-flags-resolved', 'summary-handovers-waiting', 'summary-handovers-counted', 'summary-difference']) {
        expect(find.descendant(of: find.byType(BuListCard), matching: find.byKey(Key(k))), findsOneWidget, reason: k);
      }
      Color value(String k) => textColor(tester, find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)).last);
      expect(value('summary-handovers-waiting'), bu.amber, reason: 'one handover is waiting');
      expect(value('summary-recorded') == bu.amber, isFalse, reason: 'a total that asks nothing of anyone is never highlighted');
      expect(value('summary-handovers-counted') == bu.amber, isFalse);
      expect(value('summary-flags-open') == bu.amber, isFalse, reason: 'nothing is flagged: a zero is not highlighted even on a row that can need a person');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the door: Scan, Guests and Door sales', () {
    late FakeDoorBackend db;
    ValueChanged<String>? emit;

    Widget camera(BuildContext context, ValueChanged<String> onCode) {
      emit = onCode;
      return const SizedBox(key: Key('fake-camera'));
    }

    setUp(() {
      db = FakeDoorBackend();
      emit = null;
      db.handlers['door_events'] = (_) => [eventRow()];
    });

    Future<void> scan(WidgetTester tester) => showScreen(tester, DoorScanScreen(membershipId: 'm1', cameraBuilder: camera), [doorServiceProvider.overrideWithValue(db.service)]);

    BoxDecoration panel(WidgetTester tester) => tester.widget<Container>(find.byKey(const Key('scan-result'))).decoration! as BoxDecoration;

    testWidgets('Scan has a Door eyebrow, the event card first (highlighted, with how many are in), and the camera in a rounded frame', (tester) async {
      await scan(tester);
      expect(find.text('DOOR'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('door-event-bar'))).highlight, isTrue);
      expect(find.text('3 of 10 guests in'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('camera-area'))).top, greaterThan(tester.getRect(find.byKey(const Key('door-event-bar'))).bottom));
      final clip = tester.widget<ClipRRect>(find.ancestor(of: find.byKey(const Key('camera-area')), matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.circular(BuRadius.card));
    });

    testWidgets('the admitted bar is a pill-shaped bar on a faint neutral track', (tester) async {
      await scan(tester);
      final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('admitted-progress')));
      expect(bar.backgroundColor, Colors.white.withValues(alpha: 0.10));
      expect(bar.minHeight, 8);
      expect(bar.value, closeTo(0.3, 0.001));
    });

    testWidgets('only Admit is green: the design\'s green, amber and red, with a matching tinted panel and edge', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada', tier: 'General', quantity: 1)];
      await scan(tester);
      emit!('T-1');
      await tester.pumpAndSettle();
      expect(panel(tester).border!.top.color, bu.green);
      expect(panel(tester).color, bu.green.withValues(alpha: 0.14));
      expect(panel(tester).border!.top.width, 1.5);
      expect(panel(tester).borderRadius, BorderRadius.circular(BuRadius.card));

      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pump();
      db.handlers['door_scan_ticket'] = (_) => [scanRow('not_paid', name: 'Pat')];
      emit!('T-2');
      await tester.pumpAndSettle();
      expect(panel(tester).border!.top.color, bu.red);

      await tester.tap(find.byKey(const Key('scan-next')));
      await tester.pump();
      db.handlers['door_scan_ticket'] = (_) => [scanRow('code_required', name: 'Ada', tier: 'Table guest', quantity: 1)];
      emit!('T-3');
      await tester.pumpAndSettle();
      expect(panel(tester).border!.top.color, bu.amber);
    });

    testWidgets('the group stepper uses the kit\'s round plus and minus, and the Admit button is the orange one', (tester) async {
      db.handlers['door_scan_ticket'] = (_) => [groupRow('group', quantity: 4)];
      await scan(tester);
      emit!('GA-1');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('group-less')), matching: find.byIcon(Ionicons.remove_circle_outline)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('group-more')), matching: find.byIcon(Ionicons.add_circle_outline)), findsOneWidget);
      expect(find.byKey(const Key('admit-group')), findsOneWidget);
      // a group is "one more step": amber, not green
      expect(panel(tester).border!.top.color, bu.amber);
    });

    testWidgets('a message (no event, a failure) is a card in the middle of the screen, with Try again when it can help', (tester) async {
      db.handlers['door_events'] = (_) => <Map<String, dynamic>>[];
      await scan(tester);
      expect(find.ancestor(of: find.byKey(const Key('door-message')), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('door-retry')), findsOneWidget);
    });

    testWidgets('typing a code uses the theme\'s field (no heavy outline) beside the one orange "Check"', (tester) async {
      await scan(tester);
      final field = tester.widget<TextField>(find.byKey(const Key('manual-code-field')));
      expect(field.decoration!.border, isNull);
      expect(find.byKey(const Key('manual-check')), findsOneWidget);
    });

    testWidgets('Guests has a Door eyebrow; a guest is a card with a green "In" pill when already in, or the Admit button when not', (tester) async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada Lovelace', 'T-1'), guestRow('Adam Smith', 'T-2', checkedInAt: '2026-10-09T22:00:00Z')];
      await showScreen(tester, const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)), [doorServiceProvider.overrideWithValue(db.service)]);
      await tester.enterText(find.byKey(const Key('guest-search-field')), 'ad');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('DOOR'), findsOneWidget);
      expect(find.text('Guests'), findsOneWidget);
      expect(find.byKey(const Key('guest-T-1')), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('guest-T-1'))).margin, const EdgeInsets.only(top: BuSpace.s));
      final inChip = tester.widget<DeskChip>(find.byKey(const Key('guest-in')));
      expect([inChip.text, inChip.color, inChip.icon], ['In', bu.green, Ionicons.checkmark_circle]);
      expect(find.byKey(const Key('admit-T-1')), findsOneWidget);
      expect(find.byKey(const Key('admit-T-2')), findsNothing);
    });

    testWidgets('the search field is the theme\'s, with a search icon', (tester) async {
      await showScreen(tester, const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)), [doorServiceProvider.overrideWithValue(db.service)]);
      final field = tester.widget<TextField>(find.byKey(const Key('guest-search-field')));
      expect(field.decoration!.border, isNull);
      expect(find.byIcon(Ionicons.search_outline), findsOneWidget);
    });

    group('Door sales', () {
      late FakeDoorSalesBackend sales;
      setUp(() => sales = FakeDoorSalesBackend());

      Future<void> open(WidgetTester tester) => showScreen(
            tester,
            const DoorSalesScreen(membershipId: 'm1'),
            [doorServiceProvider.overrideWithValue(db.service), doorSalesServiceProvider.overrideWithValue(sales.service), saleKeyMakerProvider.overrideWithValue(() => 'k1')],
            height: 3000,
          );

      testWidgets('has a Door eyebrow, the event card, and three numbered steps with section headings', (tester) async {
        await open(tester);
        expect(find.text('DOOR'), findsOneWidget);
        expect(find.text('Door sales'), findsOneWidget);
        expect(find.byKey(const Key('door-event-bar')), findsOneWidget);
        for (final step in ['1. Ticket type', '2. Guest details', '3. How did the guest pay?']) {
          expect(find.text(step), findsOneWidget, reason: step);
        }
        expect(find.byType(BuSectionHeader), findsNWidgets(3));
      });

      testWidgets('a ticket type is a card; the chosen one is highlighted with an orange tick, a sold-out one cannot be chosen', (tester) async {
        await open(tester);
        expect(tester.widget<BuCard>(find.byKey(const Key('sale-tier-t-gen'))).highlight, isFalse);
        await tester.tap(find.byKey(const Key('sale-tier-t-gen')));
        await tester.pumpAndSettle();
        expect(tester.widget<BuCard>(find.byKey(const Key('sale-tier-t-gen'))).highlight, isTrue);
        final tick = tester.widget<Icon>(find.byKey(const Key('sale-selected')));
        expect([tick.icon, tick.color], [Ionicons.checkmark_circle, bu.orangeSoft]);
        expect(tester.widget<BuCard>(find.byKey(const Key('sale-tier-t-full'))).onTap, isNull);
        expect(tester.widget<BuCard>(find.byKey(const Key('sale-tier-t-gen'))).onTap, isNotNull);
      });

      testWidgets('the fields are the theme\'s (no heavy outline), the two ways to pay share the row, and "Review and issue" is the width of the form', (tester) async {
        await open(tester);
        for (final k in ['sale-name', 'sale-email', 'sale-phone']) {
          expect(tester.widget<TextField>(find.byKey(Key(k))).decoration!.border, isNull, reason: k);
        }
        final method = tester.getRect(find.byKey(const Key('sale-method')));
        final submit = tester.getRect(find.byKey(const Key('sale-submit')));
        expect(method.width, 393 - 2 * BuSpace.page);
        expect(submit.width, 393 - 2 * BuSpace.page);
      });

      testWidgets('a closed sale and a missing ticket list are said in cards', (tester) async {
        sales.windowOpen = false;
        await open(tester);
        expect(find.ancestor(of: find.byKey(const Key('sale-closed')), matching: find.byType(BuCard)), findsOneWidget);
      });
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Security: Alerts and Tasks', () {
    late FakeSecurityBackend db;
    List<Override> overrides() => [
          securityServiceProvider.overrideWithValue(db.service),
          securityPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
          chatPeopleProvider.overrideWith((ref, venue) async => const <ChatPerson>[]),
        ];

    setUp(() {
      db = FakeSecurityBackend();
      db.now = DateTime.utc(2026, 10, 9, 22, 30);
      db.alerts
        ..add(FakeAlert('a1', 'fight', 'Main bar', urgent: true, details: 'Two guests arguing', at: DateTime.utc(2026, 10, 9, 22, 20)))
        ..add(FakeAlert('a2', 'medical', 'Dance floor', raisedByMe: true, at: DateTime.utc(2026, 10, 9, 22, 5), status: 'acknowledged'))
        ..add(FakeAlert('a3', 'fight', 'Door', urgent: true, status: 'resolved', at: DateTime.utc(2026, 10, 9, 21, 50)));
      db.tasks
        ..add(FakeTask('t1', 'Check the fire exits', details: 'Back and side doors'))
        ..add(FakeTask('t2', 'Sweep the smoking area', status: 'done'));
    });

    Future<void> alerts(WidgetTester tester) => showScreen(tester, AlertsScreen(workspace: securityWs, clock: () => DateTime(2026, 10, 9, 22, 30)), overrides());
    Future<void> tasks(WidgetTester tester, {Workspace? ws}) => showScreen(tester, TasksScreen(workspace: ws ?? securityWs, clock: () => DateTime(2026, 10, 9, 22, 30)), overrides());

    testWidgets('Alerts has a Security eyebrow, the club, "Raise an alert" as the one orange action and the shared night bar', (tester) async {
      await alerts(tester);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      final raise = find.byKey(const Key('alert-raise'));
      expect(find.descendant(of: raise, matching: find.byIcon(Ionicons.notifications_outline)), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('night-label'))).top, greaterThan(tester.getRect(raise).bottom));
    });

    testWidgets('an urgent alert that is still open is lit red, with an URGENT pill; a plain one, and an urgent one that is resolved, are not', (tester) async {
      await alerts(tester);
      expect(tester.widget<BuCard>(find.byKey(const Key('alert-a1'))).accent, bu.red);
      expect(tester.widget<BuCard>(find.byKey(const Key('alert-a2'))).accent, isNull);
      expect(tester.widget<BuCard>(find.byKey(const Key('alert-a3'))).accent, isNull, reason: 'a resolved alert is no longer shouting');
      expect(tester.widget<DeskChip>(find.byKey(const Key('alert-urgent-a1'))).color, bu.red);
    });

    testWidgets('an open urgent alert has a red warning icon; the others a quiet bell', (tester) async {
      await alerts(tester);
      final urgent = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('alert-a1')), matching: find.byType(Icon)).first);
      expect([urgent.icon, urgent.color], [Ionicons.warning_outline, bu.red]);
      final plain = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('alert-a2')), matching: find.byType(Icon)).first);
      expect([plain.icon, plain.color], [Ionicons.notifications_outline, bu.muted]);
    });

    testWidgets('Tasks has a Security eyebrow and a card per task; a manager has "New task"', (tester) async {
      await tasks(tester);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.byKey(const Key('task-t1')), findsOneWidget);
      expect(find.byKey(const Key('task-new')), findsNothing, reason: 'only a manager adds tasks');
      expect(tester.widget<BuCard>(find.byKey(const Key('task-t1'))).margin, const EdgeInsets.only(top: BuSpace.s));
      await tasks(tester, ws: const Workspace(membershipId: 'm-mm', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A'));
      expect(find.descendant(of: find.byKey(const Key('task-new')), matching: find.byIcon(Ionicons.add)), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the organizer: Events and Guests', () {
    late oe.FakeOrganizerEventsBackend ev;
    setUp(() {
      ev = oe.FakeOrganizerEventsBackend();
      ev.events
        ..add(oe.eventRow('e1', 'Rooftop Sunset', status: 'draft', capacity: 300, address: '1 King St W'))
        ..add(oe.eventRow('e2', 'Promoter Night', status: 'published', venue: 'Active Lounge', end: '2031-10-25T04:00:00Z'));
    });

    Future<void> events(WidgetTester tester) => showScreen(tester, OrganizerEventsScreen(workspace: organizerWs, clock: () => DateTime(2026, 10, 9, 21)), [organizerEventsServiceProvider.overrideWithValue(ev.service)]);

    testWidgets('has an Organizer eyebrow and "Your events", two buttons (create is the orange one), and the groups as small orange labels', (tester) async {
      await events(tester);
      expect(find.text('ORGANIZER'), findsOneWidget);
      expect(find.text('Your events'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('create-event')), matching: find.byIcon(Ionicons.add)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('invite-team')), matching: find.byIcon(Ionicons.person_add_outline)), findsOneWidget);
      expect(find.text('DRAFTS'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(textColor(tester, find.text('DRAFTS')), bu.orange);
    });

    testWidgets('an event is a card; a draft is an amber pill, a live event a green one', (tester) async {
      await events(tester);
      expect(tester.widget<BuCard>(find.byKey(const Key('event-e1'))).margin, const EdgeInsets.only(bottom: BuSpace.m));
      expect(chipColor(tester, 'status-e1'), bu.amber);
      expect(chipColor(tester, 'status-e2'), bu.green);
    });

    testWidgets('when where each event stands cannot be read, a draft is still amber and a published event still green', (tester) async {
      ev.statesFail = true;
      await events(tester);
      expect(chipColor(tester, 'status-e1'), bu.amber);
      expect(chipColor(tester, 'status-e2'), bu.green);
    });

    testWidgets('Remove is red; Copy event link, on a live event, has the kit\'s link icon', (tester) async {
      await events(tester);
      final remove = tester.widget<TextButton>(find.byKey(const Key('remove-e1')));
      expect(remove.style!.foregroundColor!.resolve({}), bu.red);
      expect(find.descendant(of: find.byKey(const Key('copy-link-e2')), matching: find.byIcon(Ionicons.link_outline)), findsOneWidget);
    });

    testWidgets('no events says so in a card; a failure is a card with Try again', (tester) async {
      ev.events.clear();
      await events(tester);
      expect(tester.widget<BuCard>(find.byKey(const Key('no-events'))).padding, const EdgeInsets.all(BuSpace.xl));
      ev.failAll = Exception('offline');
      await events(tester);
      expect(find.ancestor(of: find.byKey(const Key('events-error')), matching: find.byType(BuCard)), findsOneWidget);
    });

    testWidgets('Guests has an Organizer eyebrow, a highlighted summary card, and the guests as one grouped list with the checked-in ones in green', (tester) async {
      final g = FakeGuestBackend();
      await showScreen(tester, OrganizerGuestsScreen(workspace: organizerWs), [organizerEventsServiceProvider.overrideWithValue(ev.service), organizerGuestServiceProvider.overrideWithValue(g.service)]);
      expect(find.text('ORGANIZER'), findsOneWidget);
      expect(find.text('Guests'), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('guests-summary'))).highlight, isTrue);
      expect(find.descendant(of: find.byType(BuListCard), matching: find.byKey(const Key('guest-o1'))), findsOneWidget);
      expect(textColor(tester, find.byKey(const Key('guest-state-o2'))), bu.green, reason: 'Ada has checked in');
      expect(textColor(tester, find.byKey(const Key('guest-state-o1'))) == bu.green, isFalse);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Chat and Team', () {
    testWidgets('Chat has a Messages eyebrow, the scope under it, "New message" and the chats in one grouped list with an icon tile each', (tester) async {
      final chat = FakeChatBackend();
      chat.conversations
        ..add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1', members: {'me', 'sam'}))
        ..add(FakeConversation('e1', 'event', 'Night One', eventId: 'ev1', deleteAfter: DateTime.utc(2026, 10, 25, 12)));
      chat.add('c1', 'sam', 'Sam Server', 'Table 4 needs a fresh ice bucket', ago: const Duration(minutes: 6));
      await showScreen(tester, ChatScreen(workspace: managerWs, clock: () => DateTime.utc(2026, 10, 9, 21, 42)), [chatServiceProvider.overrideWithValue(chat.service)]);
      expect(find.text('MESSAGES'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-new')), matching: find.byIcon(Ionicons.create_outline)), findsOneWidget);
      expect(find.byType(BuListCard), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-row-c1')), matching: find.byIcon(Ionicons.people_outline)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-row-e1')), matching: find.byIcon(Ionicons.calendar_outline)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-row-c1')), matching: find.byType(BuIconTile)), findsOneWidget);
    });

    testWidgets('an unread count is an orange pill with white text', (tester) async {
      final chat = FakeChatBackend();
      chat.conversations.add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1', members: {'me', 'sam'}));
      chat.add('c1', 'sam', 'Sam Server', 'hello', ago: const Duration(minutes: 6));
      await showScreen(tester, ChatScreen(workspace: managerWs, clock: () => DateTime.utc(2026, 10, 9, 21, 42)), [chatServiceProvider.overrideWithValue(chat.service)]);
      final badge = tester.widget<Container>(find.byKey(const Key('chat-unread-c1')));
      expect((badge.decoration! as BoxDecoration).color, bu.orange);
      expect(textColor(tester, find.descendant(of: find.byKey(const Key('chat-unread-c1')), matching: find.text('1'))), Colors.white);
    });

    testWidgets('Team has a People eyebrow, two buttons, an invitation card and a card per member with a pill for their state', (tester) async {
      final team = tm.FakeTeamBackend();
      team.members
        ..add(tm.memberRow('m1', name: 'Mia Manager', email: 'mia@club.example', role: 'manager'))
        ..add(tm.memberRow('m3', name: null, email: 'old@club.example', role: 'door', state: 'ended'));
      team.invitations.add(tm.invitationRow('i1', email: 'new@club.example', role: 'door', sent: 1));
      await showScreen(tester, TeamScreen(workspace: ownerWs), [teamServiceProvider.overrideWithValue(team.service)]);
      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('invite-button')), matching: find.byIcon(Ionicons.person_add_outline)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('shifts-button')), matching: find.byIcon(Ionicons.time_outline)), findsOneWidget);
      expect(find.byKey(const Key('invitation-i1')), findsOneWidget);
      expect(find.byKey(const Key('member-m1')), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('member-m1'))).margin, const EdgeInsets.only(bottom: BuSpace.s));
      expect(tester.widget<DeskChip>(find.descendant(of: find.byKey(const Key('member-m1')), matching: find.byType(DeskChip))).color, bu.green, reason: 'active');
      expect(tester.widget<DeskChip>(find.descendant(of: find.byKey(const Key('invitation-i1')), matching: find.byType(DeskChip)).first).color, bu.orangeSoft, reason: 'an invitation that is waiting');
    });

    testWidgets('the removal button is red', (tester) async {
      final team = tm.FakeTeamBackend();
      team.members.add(tm.memberRow('m2', name: 'Sam Server', email: 'sam@club.example', role: 'server'));
      await showScreen(tester, TeamScreen(workspace: ownerWs), [teamServiceProvider.overrideWithValue(team.service)]);
      expect(tester.widget<TextButton>(find.byKey(const Key('remove-m2'))).style!.foregroundColor!.resolve({}), bu.red);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the server\'s Scan tab and the signs notice', () {
    testWidgets('Scan has a Your shift eyebrow, its line of help, the camera in a rounded frame, and a match as a tappable row with a green "Seated" pill', (tester) async {
      final db = FakeSeatingBackend();
      db.bookings.add(FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace'));
      await showScreen(
        tester,
        ServerScanScreen(workspace: serverWs, clock: friday9pm, cameraBuilder: (c, onCode) => const SizedBox(key: Key('fake-camera'))),
        [seatingServiceProvider.overrideWithValue(db.service)],
      );
      expect(find.text('YOUR SHIFT'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(textColor(tester, find.textContaining('Scan the QR on the guest')), bu.muted);
      await tester.enterText(find.byKey(const Key('scan-search')), 'ADA111');
      await tester.tap(find.byKey(const Key('scan-search-go')));
      await tester.pumpAndSettle();
      final match = find.byKey(const Key('match-b1'));
      expect(match, findsOneWidget);
      expect(find.descendant(of: match, matching: find.byType(BuListRow)), findsOneWidget);
      expect(tester.widget<BuCard>(match).padding, EdgeInsets.zero);
    });

    testWidgets('a guest who has already been seated is marked with a green "Seated" pill', (tester) async {
      final db = FakeSeatingBackend();
      db.bookings.add(FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace')..seated = true);
      await showScreen(
        tester,
        ServerScanScreen(workspace: serverWs, clock: friday9pm, cameraBuilder: (c, onCode) => const SizedBox(key: Key('fake-camera'))),
        [seatingServiceProvider.overrideWithValue(db.service)],
      );
      await tester.enterText(find.byKey(const Key('scan-search')), 'ADA111');
      await tester.tap(find.byKey(const Key('scan-search-go')));
      await tester.pumpAndSettle();
      final pill = tester.widget<DeskChip>(find.descendant(of: find.byKey(const Key('match-b1')), matching: find.byType(DeskChip)));
      expect([pill.text, pill.color], ['Seated', bu.green]);
    });

    testWidgets('the notice that bottle signs could not be read is an amber card with Try again', (tester) async {
      var retried = 0;
      await showScreen(tester, SignsLoadNotice(signs: AsyncValue.error(Exception('offline'), StackTrace.empty), onRetry: () => retried++), const []);
      expect(tester.widget<BuCard>(find.byKey(const Key('signs-notice'))).accent, bu.amber);
      expect(find.byKey(const Key('signs-notice-text')), findsOneWidget);
      await tester.tap(find.byKey(const Key('signs-notice-retry')));
      expect(retried, 1);
    });
  });
}
