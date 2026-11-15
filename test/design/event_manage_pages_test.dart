import 'dart:io';

import 'package:bottles_up_vendor/features/events/models/event_team_member.dart';
import 'package:bottles_up_vendor/features/events/models/ticket_type.dart';
import 'package:bottles_up_vendor/features/events/providers/guest_list_provider.dart';
import 'package:bottles_up_vendor/features/events/providers/scheduled_releases_provider.dart';
import 'package:bottles_up_vendor/features/events/screens/guest_list_screen.dart';
import 'package:bottles_up_vendor/features/events/screens/manage_event_tables_screen.dart';
import 'package:bottles_up_vendor/features/events/screens/manage_lineup_screen.dart';
import 'package:bottles_up_vendor/features/events/screens/manage_ticket_tiers_screen.dart';
import 'package:bottles_up_vendor/features/events/screens/scheduled_releases_screen.dart';
import 'package:bottles_up_vendor/features/events/services/event_team_service.dart';
import 'package:bottles_up_vendor/shared/models/analytics_models.dart';
import 'package:bottles_up_vendor/shared/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'classic_detail_screens_test.dart' show pumpPage, shot;

// The five pages behind an event (ticket tiers, team and lineup, tables, guest list, scheduled releases) in the design's look. They could not be shown without a live database
// because two of them built their own database access; they now take it from a provider (a ticket service and an event team service), so these tests give them fakes.

// ── fakes ──────────────────────────────────────────────────────────────────────────────

class FakeTickets extends TicketService {
  FakeTickets(this.tiers);

  List<TicketType> tiers;
  final created = <String>[];
  final updated = <String>[];
  final deleted = <String>[];
  final toggled = <String, bool>{};

  @override
  Future<List<TicketType>> getTicketTypes(String eventId) async => tiers;

  @override
  Future<Map<String, dynamic>> getTicketSalesSummary(String eventId) async {
    final capacity = tiers.fold<int>(0, (s, t) => s + t.capacity);
    final sold = tiers.fold<int>(0, (s, t) => s + t.soldCount);
    final revenue = tiers.fold<double>(0, (s, t) => s + t.soldCount * t.price);
    return {'total_capacity': capacity, 'total_sold': sold, 'total_available': capacity - sold, 'total_revenue': revenue};
  }

  @override
  Future<TicketType> createTicketType(String eventId, TicketType ticket) async {
    created.add('${ticket.name}|${ticket.price}|${ticket.capacity}');
    tiers = [...tiers, ticket];
    return ticket;
  }

  @override
  Future<TicketType> updateTicketType(String ticketId, TicketType ticket) async {
    updated.add('$ticketId|${ticket.name}|${ticket.price}|${ticket.capacity}');
    tiers = [for (final t in tiers) t.id == ticketId ? ticket : t];
    return ticket;
  }

  @override
  Future<void> deleteTicketType(String ticketId) async {
    deleted.add(ticketId);
    tiers = tiers.where((t) => t.id != ticketId).toList();
  }

  @override
  Future<void> toggleActiveStatus(String ticketId, bool isActive) async {
    toggled[ticketId] = isActive;
    tiers = [for (final t in tiers) t.id == ticketId ? t.copyWith(isActive: isActive) : t];
  }
}

class FakeTeam extends EventTeamService {
  FakeTeam(this.members);

  List<EventTeamMember> members;
  final added = <String>[];
  final updated = <String>[];
  final removed = <String>[];

  @override
  Future<List<EventTeamMember>> list(String eventId) async => members;

  @override
  Future<void> add({required String eventId, required String name, required String role, String? email, String? phone}) async {
    added.add('$name|$role');
    members = [...members, member('new$name', name, role)];
  }

  @override
  Future<void> update(String id, {required String name, required String role, String? email, String? phone}) async {
    updated.add('$id|$name|$role');
    members = [for (final m in members) m.id == id ? member(id, name, role) : m];
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    members = members.where((m) => m.id != id).toList();
  }
}

class FakeGuests extends GuestListNotifier {
  // The real notifier starts loading from the database as it is made; here that fails at once (no database) and the answer below replaces it.
  FakeGuests(super.eventId, List<GuestListEntry> guests, this.checkedIn, {Object? error}) {
    state = error != null ? AsyncValue.error(error, StackTrace.empty) : AsyncValue.data(guests);
  }

  /// Who was checked in. Shared with the test, because the page asks for a fresh notifier after every change (it invalidates the provider).
  final List<String> checkedIn;

  @override
  Future<bool> checkInGuest(String guestId) async {
    checkedIn.add(guestId);
    return true;
  }
}

class FakeReleases extends ScheduledReleasesNotifier {
  FakeReleases(super.eventId, List<ScheduledTicketRelease> releases) {
    state = AsyncValue.data(releases);
  }
}

// ── data ───────────────────────────────────────────────────────────────────────────────

final _t0 = DateTime(2026, 1, 1);

TicketType tier(String id, String name, {double price = 40, int capacity = 100, int sold = 0, bool active = true, String? description}) =>
    TicketType(id: id, eventId: 'e1', name: name, price: price, capacity: capacity, soldCount: sold, isActive: active, description: description, createdAt: _t0, updatedAt: _t0);

EventTeamMember member(String id, String name, String role, {String? email, String? phone}) =>
    EventTeamMember(id: id, eventId: 'e1', name: name, role: role, email: email, phone: phone, createdAt: _t0, updatedAt: _t0);

GuestListEntry guest(String id, String name, {bool arrived = false, String? email, String? ticket}) => GuestListEntry(id: id, name: name, email: email, ticketType: ticket, checkedIn: arrived);

ScheduledTicketRelease release(String id, String name, DateTime when, {int qty = 50, double price = 25, bool active = true}) =>
    ScheduledTicketRelease(id: id, eventId: 'e1', name: name, releaseDate: when, ticketQuantity: qty, price: price, isActive: active, createdAt: _t0);

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  group('Ticket tiers', () {
    Future<FakeTickets> open(WidgetTester tester, List<TicketType> tiers) async {
      final fake = FakeTickets(tiers);
      await pumpPage(tester, () => const ManageTicketTiersScreen(eventId: 'e1', eventName: 'Afro Nights'), height: 2200, overrides: [ticketServiceProvider.overrideWithValue(fake)]);
      return fake;
    }

    final two = [tier('t1', 'Early Bird', price: 30, capacity: 100, sold: 95, description: 'First 100'), tier('t2', 'General', price: 50, capacity: 200, sold: 0, active: false)];

    testWidgets('the event\'s name over "Ticket Tiers", four figures, the count and a card per tier', (tester) async {
      await open(tester, two);
      expect(find.text('AFRO NIGHTS'), findsOneWidget);
      expect(find.text('Ticket Tiers'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tiers-sold')), matching: find.text('95')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tiers-capacity')), matching: find.text('300')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tiers-available')), matching: find.text('205')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tiers-revenue')), matching: find.text('\$2850.00')), findsOneWidget);
      expect(find.text('Ticket Tiers (2)'), findsOneWidget);
      expect(find.byKey(const Key('tier-t1')), findsOneWidget);
      expect(find.text('First 100'), findsOneWidget);
      expect(find.text('95 / 100'), findsOneWidget);
      expect(find.text('95.0% sold'), findsOneWidget);
      await shot(tester, 'tiers');
    });

    testWidgets('an inactive tier says Inactive; one with nothing left says Sold Out', (tester) async {
      await open(tester, [tier('t1', 'Early Bird', capacity: 10, sold: 10), tier('t2', 'General', active: false)]);
      expect(find.descendant(of: find.byKey(const Key('tier-t1')), matching: find.text('Sold Out')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tier-t2')), matching: find.text('Inactive')), findsOneWidget);
    });

    testWidgets('Deactivate asks the service; Delete is offered only for a tier nothing has been sold from, and asks first', (tester) async {
      final fake = await open(tester, two);
      await tester.tap(find.byKey(const Key('tier-menu-t1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tier-delete')), findsNothing, reason: 'it has 95 sold');
      await tester.tap(find.byKey(const Key('tier-toggle')));
      await tester.pumpAndSettle();
      expect(fake.toggled, {'t1': false});

      await tester.tap(find.byKey(const Key('tier-menu-t2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tier-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Ticket Tier'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.deleted, isEmpty);

      await tester.tap(find.byKey(const Key('tier-menu-t2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tier-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(fake.deleted, ['t2']);
    });

    testWidgets('Edit changes the tier through the service, not by adding a new one', (tester) async {
      final fake = await open(tester, two);
      await tester.tap(find.byKey(const Key('tier-menu-t2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tier-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Ticket Tier'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Price *'), '55');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(fake.updated, ['t2|General|55.0|200']);
      expect(fake.created, isEmpty);
    });

    testWidgets('Add Tier needs a name, a price and a capacity, then creates one', (tester) async {
      final fake = await open(tester, const []);
      expect(find.byKey(const Key('tiers-empty')), findsOneWidget);
      expect(find.text('No ticket tiers yet'), findsOneWidget);
      await shot(tester, 'tiers_empty');
      await tester.tap(find.byKey(const Key('tier-add')));
      await tester.pumpAndSettle();
      expect(find.text('Add Ticket Tier'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fake.created, isEmpty, reason: 'nothing is created from an empty form');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tier Name *'), 'VIP');
      await tester.enterText(find.widgetWithText(TextFormField, 'Price *'), '90');
      await tester.enterText(find.widgetWithText(TextFormField, 'Capacity *'), '20');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fake.created, ['VIP|90.0|20']);
      expect(find.text('Ticket Tiers (1)'), findsOneWidget);
    });
  });

  group('Team and lineup', () {
    Future<FakeTeam> open(WidgetTester tester, List<EventTeamMember> members) async {
      final fake = FakeTeam(members);
      await pumpPage(tester, () => const ManageLineupScreen(eventId: 'e1', eventName: 'Afro Nights'), height: 2200, overrides: [eventTeamServiceProvider.overrideWithValue(fake)]);
      return fake;
    }

    final team = [member('m1', 'DJ Kato', TeamRole.dj, email: 'kato@x.test'), member('m2', 'Sam', TeamRole.security, phone: '+1 416 555 0101'), member('m3', 'Lee', TeamRole.bartender)];

    testWidgets('DJs and the rest in two sections, with how many, each with role, e-mail and phone', (tester) async {
      await open(tester, team);
      expect(find.text('AFRO NIGHTS'), findsOneWidget);
      expect(find.text('Team & Lineup'), findsOneWidget);
      expect(find.text('3 team members'), findsOneWidget);
      expect(find.text('DJs & Performers (1)'), findsOneWidget);
      expect(find.text('Other Team Members (2)'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-m1')), matching: find.text('DJ')), findsOneWidget);
      expect(find.text('kato@x.test'), findsOneWidget);
      expect(find.text('+1 416 555 0101'), findsOneWidget);
      await shot(tester, 'lineup');
    });

    testWidgets('no DJ yet says so; nobody at all says so and offers to add', (tester) async {
      await open(tester, [member('m2', 'Sam', TeamRole.security)]);
      expect(find.byKey(const Key('lineup-no-djs')), findsOneWidget);
      expect(find.text('1 team member'), findsOneWidget);
      await open(tester, const []);
      expect(find.byKey(const Key('lineup-empty')), findsOneWidget);
      expect(find.text('No team members yet'), findsOneWidget);
      expect(find.byKey(const Key('lineup-fab')), findsNothing);
    });

    testWidgets('Remove asks first, then removes through the service', (tester) async {
      final fake = await open(tester, team);
      await tester.tap(find.byKey(const Key('member-menu-m2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Team Member'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.removed, isEmpty);
      await tester.tap(find.byKey(const Key('member-menu-m2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(fake.removed, ['m2']);
      expect(find.text('2 team members'), findsOneWidget);
    });

    testWidgets('Edit changes the member through the service, not by adding a new one', (tester) async {
      final fake = await open(tester, team);
      await tester.tap(find.byKey(const Key('member-menu-m3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Team Member'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Leigh');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(fake.updated, ['m3|Leigh|${TeamRole.bartender}']);
      expect(fake.added, isEmpty);
    });

    testWidgets('Add Team Member needs a name, then adds one through the service', (tester) async {
      final fake = await open(tester, const []);
      await tester.tap(find.byKey(const Key('lineup-add')));
      await tester.pumpAndSettle();
      expect(find.text('Add Team Member'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fake.added, isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Ada');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(fake.added, ['Ada|${TeamRole.dj}']);
    });
  });

  group('Tables', () {
    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> rows) =>
        pumpPage(tester, () => const ManageEventTablesScreen(eventId: 'e1'), height: 2000, overrides: [eventTablesProvider('e1').overrideWith((ref) async => rows)]);

    Map<String, dynamic> table(String id, String name, {bool vip = false, bool active = true, int capacity = 8, num price = 200, String? where}) => {
      'id': id,
      'name': name,
      'is_vip': vip,
      'is_active': active,
      'capacity': capacity,
      'price': price,
      'location_description': where,
    };

    testWidgets('three figures and a card per table, with VIP and Off sale marked', (tester) async {
      await open(tester, [table('a', 'Booth 1', vip: true, where: 'By the DJ'), table('b', 'Side 2', active: false, capacity: 4, price: 100)]);
      expect(tester.widget<Text>(find.byKey(const Key('tables-total'))).data, '2');
      expect(tester.widget<Text>(find.byKey(const Key('tables-active'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('tables-vip'))).data, '1');
      expect(find.descendant(of: find.byKey(const Key('table-a')), matching: find.text('VIP')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('table-b')), matching: find.text('Off sale')), findsOneWidget);
      expect(find.text('Capacity: 8 guests · Deposit: \$200'), findsOneWidget);
      expect(find.text('By the DJ'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('table-switch-b'))).value, isFalse);
      await shot(tester, 'tables');
    });

    testWidgets('no tables says so and offers the first; Add opens the sheet', (tester) async {
      await open(tester, const []);
      expect(find.byKey(const Key('tables-empty')), findsOneWidget);
      expect(find.text('No tables yet'), findsOneWidget);
      expect(find.byKey(const Key('tables-fab')), findsNothing);
      await tester.tap(find.byKey(const Key('tables-add-first')));
      await tester.pumpAndSettle();
      expect(find.text('Table Name *'), findsOneWidget);
    });
  });

  group('Guest list', () {
    Future<List<String>> open(WidgetTester tester, List<GuestListEntry> guests, {Object? error}) async {
      final checkedIn = <String>[];
      await pumpPage(tester, () => const GuestListScreen(eventId: 'e1'), height: 2200, overrides: [guestListProvider('e1').overrideWith((ref) => FakeGuests('e1', guests, checkedIn, error: error))]);
      return checkedIn;
    }

    final guests = [guest('g1', 'Ada Obi', arrived: true, email: 'ada@x.test', ticket: 'VIP'), guest('g2', 'Ben Cole'), guest('g3', 'Cy Dunn')];

    testWidgets('three figures, a card per guest, who has arrived and who has not', (tester) async {
      await open(tester, guests);
      expect(tester.widget<Text>(find.byKey(const Key('guests-total'))).data, '3');
      expect(tester.widget<Text>(find.byKey(const Key('guests-arrived'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('guests-waiting'))).data, '2');
      expect(find.byKey(const Key('guest-arrived-g1')), findsOneWidget);
      expect(find.byKey(const Key('guest-checkin-g2')), findsOneWidget);
      expect(find.byKey(const Key('guest-checkin-g1')), findsNothing, reason: 'an arrived guest has nothing left to do');
      expect(find.text('VIP'), findsOneWidget);
      await shot(tester, 'guests');
    });

    testWidgets('the filters and the search narrow the list', (tester) async {
      await open(tester, guests);
      await tester.tap(find.byKey(const Key('guest-filter-Arrived')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guest-g1')), findsOneWidget);
      expect(find.byKey(const Key('guest-g2')), findsNothing);
      await tester.tap(find.byKey(const Key('guest-filter-Waiting')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guest-g1')), findsNothing);
      expect(find.byKey(const Key('guest-g2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guest-filter-All')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('guests-search')), 'cy');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guest-g3')), findsOneWidget);
      expect(find.byKey(const Key('guest-g2')), findsNothing);
      await tester.enterText(find.byKey(const Key('guests-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guests-none')), findsOneWidget);
      expect(find.text('No guests found'), findsOneWidget);
    });

    testWidgets('Check in asks the notifier', (tester) async {
      final checkedIn = await open(tester, guests);
      await tester.tap(find.byKey(const Key('guest-checkin-g2')));
      await tester.pumpAndSettle();
      expect(checkedIn, ['g2']);
    });

    testWidgets('no guests says so; a failed load says so and offers Retry', (tester) async {
      await open(tester, const []);
      expect(find.text('No guests yet'), findsOneWidget);
      await open(tester, const [], error: Exception('x'));
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Scheduled releases', () {
    Future<void> open(WidgetTester tester, List<ScheduledTicketRelease> releases) =>
        pumpPage(tester, () => const ScheduledReleasesScreen(eventId: 'e1'), height: 2000, overrides: [scheduledReleasesProvider('e1').overrideWith((ref) => FakeReleases('e1', releases))]);

    testWidgets('three figures; a release still to come says when, one that has happened says Released', (tester) async {
      final now = DateTime.now();
      await open(tester, [release('r1', 'Early Bird', now.subtract(const Duration(days: 3)), qty: 40), release('r2', 'General', now.add(const Duration(days: 5, hours: 1)), qty: 60, active: false)]);
      expect(tester.widget<Text>(find.byKey(const Key('releases-total'))).data, '2');
      expect(tester.widget<Text>(find.byKey(const Key('releases-upcoming'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('releases-tickets'))).data, '100');
      expect(tester.widget<Text>(find.byKey(const Key('release-status-r1'))).data, 'Released');
      expect(tester.widget<Text>(find.byKey(const Key('release-status-r2'))).data, 'Releases in 5 days');
      expect(find.descendant(of: find.byKey(const Key('release-r2')), matching: find.text('Inactive')), findsOneWidget);
      expect(find.text('40 tickets'), findsOneWidget);
      expect(find.text('\$25.00'), findsWidgets);
      await shot(tester, 'releases');
    });

    testWidgets('no releases says so', (tester) async {
      await open(tester, const []);
      expect(find.byKey(const Key('releases-empty')), findsOneWidget);
      expect(find.text('No scheduled releases'), findsOneWidget);
      expect(find.byKey(const Key('releases-add')), findsOneWidget);
    });

    testWidgets('Add Release opens its form', (tester) async {
      await open(tester, const []);
      await tester.tap(find.byKey(const Key('releases-add')));
      await tester.pumpAndSettle();
      expect(find.text('Add Scheduled Release'), findsOneWidget);
    });
  });
}
