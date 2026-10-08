import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
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
          expect(built != null, isDoorScreen || isFloor || isOwnerScreen, reason: '${role.name}/${section.id}');
        }
      }
    });

    test('a manager\'s other tabs are still placeholders: Orders needs bottle orders, which are not shown yet', () {
      for (final id in ['tonight', 'orders', 'team', 'more']) {
        expect(builtSectionFor(as(WorkspaceRole.manager), id), isNull, reason: id);
      }
    });

    test('a server\'s Scan is not the ticket scanner: it is for table bookings, which are not built here', () {
      expect(builtSectionFor(as(WorkspaceRole.server), 'scan'), isNull);
    });

    test('an organizer\'s Guests is not the door guest list', () {
      expect(builtSectionFor(as(WorkspaceRole.organizer), 'guests'), isNull);
    });

    test('Door Sales is not built, so it is not a till that looks real', () {
      expect(builtSectionFor(as(WorkspaceRole.door), 'door-sales'), isNull);
    });
  });
}
