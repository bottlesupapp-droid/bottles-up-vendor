import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
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

    test('no other section of any role is built yet: they all say so, honestly', () {
      for (final role in WorkspaceRole.values) {
        for (final section in navigationFor(role).sections) {
          final built = builtSectionFor(as(role), section.id);
          final isDoorScreen = role == WorkspaceRole.door && (section.id == 'scan' || section.id == 'guests');
          expect(built != null, isDoorScreen, reason: '${role.name}/${section.id}');
        }
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
