import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/organizer_events_screen.dart';
import 'package:bottles_up_vendor/features/team/screens/team_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/role_navigation.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_section_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace as(WorkspaceRole role) => Workspace(
      membershipId: 'm-${role.name}',
      orgId: 'o',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: 'v1',
      venueName: 'Club A',
    );

void main() {
  group('which sections are built', () {
    test('the door role gets the scanner on Scan and the guest search on Guests, for its own membership', () {
      final scan = builtSectionFor(as(WorkspaceRole.door), 'scan');
      expect(scan, isA<DoorScanScreen>());
      expect((scan as DoorScanScreen).membershipId, 'm-door');
      final guests = builtSectionFor(as(WorkspaceRole.door), 'guests');
      expect(guests, isA<DoorGuestsScreen>());
      expect((guests as DoorGuestsScreen).membershipId, 'm-door');
    });

    test('the manager\'s Floor shows the bookings of the manager\'s own club', () {
      final floor = builtSectionFor(as(WorkspaceRole.manager), 'floor');
      expect(floor, isA<FloorScreen>());
      expect((floor as FloorScreen).venueId, 'v1');
      expect(floor.venueName, 'Club A');
    });

    test('an owner\'s workspace is not tied to a club, so a Floor opened for one has nothing to fetch', () {
      const owner = Workspace(membershipId: 'm-o', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
      expect(builtSectionFor(owner, 'floor'), isNull, reason: 'the owner has no Floor tab');
      const manager = Workspace(membershipId: 'm-m', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager);
      expect((builtSectionFor(manager, 'floor') as FloorScreen).venueId, isNull);
    });

    test('no other section of any role is built yet: they all say so, honestly', () {
      for (final role in WorkspaceRole.values) {
        for (final section in navigationFor(role).sections) {
          final built = builtSectionFor(as(role), section.id);
          final isDoorScreen = role == WorkspaceRole.door && (section.id == 'scan' || section.id == 'guests');
          final isFloor = role == WorkspaceRole.manager && section.id == 'floor';
          final isOwnerScreen = role == WorkspaceRole.owner && (section.id == 'home' || section.id == 'venues');
          final isTeam = (role == WorkspaceRole.owner || role == WorkspaceRole.manager) && section.id == 'team';
          final isOrganizerEvents = role == WorkspaceRole.organizer && (section.id == 'home' || section.id == 'events');
          final isServerDesk = role == WorkspaceRole.server && (section.id == 'tables' || section.id == 'orders' || section.id == 'requests');
          final isManagerNight = role == WorkspaceRole.manager && (section.id == 'tonight' || section.id == 'orders');
          final isVerifierReview = role == WorkspaceRole.verifier && section.id == 'review';
          expect(
            built != null,
            isDoorScreen || isFloor || isOwnerScreen || isTeam || isOrganizerEvents || isServerDesk || isManagerNight || isVerifierReview,
            reason: '${role.name}/${section.id}',
          );
        }
      }
    });

    test('a server gets My Tables, Orders and Requests; Scan waits for table check-in, and Chat for chat', () {
      expect(builtSectionFor(as(WorkspaceRole.server), 'tables'), isA<MyTablesScreen>());
      expect(builtSectionFor(as(WorkspaceRole.server), 'orders'), isA<OrdersScreen>());
      expect(builtSectionFor(as(WorkspaceRole.server), 'requests'), isA<ServiceRequestsScreen>());
      for (final id in ['scan', 'chat']) {
        expect(builtSectionFor(as(WorkspaceRole.server), id), isNull, reason: id);
      }
    });

    test('a manager\'s Floor can give a booking to a server: it is given the business', () {
      const manager = Workspace(membershipId: 'm-m', orgId: 'o9', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
      expect((builtSectionFor(manager, 'floor') as FloorScreen).orgId, 'o9');
    });

    test('a manager gets Tonight and Orders for their own club; More is still a placeholder', () {
      final tonight = builtSectionFor(as(WorkspaceRole.manager), 'tonight');
      expect(tonight, isA<TonightScreen>());
      expect((tonight as TonightScreen).workspace.venueId, 'v1');
      final orders = builtSectionFor(as(WorkspaceRole.manager), 'orders');
      expect(orders, isA<OrdersScreen>());
      expect((orders as OrdersScreen).workspace.venueId, 'v1');
      expect(builtSectionFor(as(WorkspaceRole.manager), 'more'), isNull);
    });

    test('a verifier\'s Review is the queue of payments to check; their other tabs wait for cash handover and flagging', () {
      final review = builtSectionFor(as(WorkspaceRole.verifier), 'review');
      expect(review, isA<PaymentReviewScreen>());
      expect((review as PaymentReviewScreen).workspace.venueId, 'v1');
      for (final id in ['cash', 'exceptions', 'summary']) {
        expect(builtSectionFor(as(WorkspaceRole.verifier), id), isNull, reason: id);
      }
    });

    test('Tonight, Orders and Review are for those roles only', () {
      for (final role in WorkspaceRole.values) {
        if (role != WorkspaceRole.manager) expect(builtSectionFor(as(role), 'tonight'), isNull, reason: '${role.name}/tonight');
        if (role != WorkspaceRole.manager && role != WorkspaceRole.server) expect(builtSectionFor(as(role), 'orders'), isNull, reason: '${role.name}/orders');
        if (role != WorkspaceRole.verifier) expect(builtSectionFor(as(role), 'review'), isNull, reason: '${role.name}/review');
      }
    });

    test('the Team tab is built for the owner and the manager, each for their own workspace, and for nobody else', () {
      final owner = builtSectionFor(as(WorkspaceRole.owner), 'team');
      expect(owner, isA<TeamScreen>());
      expect((owner as TeamScreen).workspace.role, WorkspaceRole.owner);
      final manager = builtSectionFor(as(WorkspaceRole.manager), 'team');
      expect(manager, isA<TeamScreen>());
      expect((manager as TeamScreen).workspace.venueId, 'v1');
      for (final role in WorkspaceRole.values.where((r) => r != WorkspaceRole.owner && r != WorkspaceRole.manager)) {
        expect(builtSectionFor(as(role), 'team'), isNull, reason: role.name);
      }
    });

    test('a server\'s Scan is not the ticket scanner: it is for table bookings, which are not built here', () {
      expect(builtSectionFor(as(WorkspaceRole.server), 'scan'), isNull);
    });

    test('the organizer\'s Home and Events are the business\'s events; nobody else gets them', () {
      for (final id in ['home', 'events']) {
        final screen = builtSectionFor(as(WorkspaceRole.organizer), id);
        expect(screen, isA<OrganizerEventsScreen>(), reason: id);
        expect((screen as OrganizerEventsScreen).workspace.role, WorkspaceRole.organizer);
      }
      for (final role in WorkspaceRole.values.where((r) => r != WorkspaceRole.organizer)) {
        expect(builtSectionFor(as(role), 'events'), isNull, reason: '${role.name} has no Events screen of the organizer\'s kind');
      }
      expect(builtSectionFor(as(WorkspaceRole.owner), 'home'), isNot(isA<OrganizerEventsScreen>()));
    });

    test('an organizer\'s Guests is not the door guest list', () {
      expect(builtSectionFor(as(WorkspaceRole.organizer), 'guests'), isNull);
    });

    test('Door Sales is not built, so it is not a till that looks real', () {
      expect(builtSectionFor(as(WorkspaceRole.door), 'door-sales'), isNull);
    });
  });
}
