import 'package:bottles_up_vendor/features/door_staff/providers/door_staff_providers.dart';
import 'package:bottles_up_vendor/features/door_staff/screens/club_door_staff_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_staff_backend.dart';

late FakeDoorStaffBackend db;
late Future<List<OrgVenue>> Function() venues;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget host(Workspace ws) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        doorStaffServiceProvider.overrideWithValue(db.doorService),
        ownerVenuesProvider.overrideWith((ref, org) => venues()),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ClubDoorStaffScreen(workspace: ws))),
    );

Future<void> open(WidgetTester tester, [Workspace ws = manager]) async {
  tester.view.physicalSize = const Size(800, 3000);
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

void main() {
  setUp(() {
    db = FakeDoorStaffBackend();
    venues = () async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'published')];
    db.permissions['v1'] = [permissionRow('a1', 'e1', 'Rooftop Sessions'), permissionRow('a2', 'e2', 'Summer Closing', organizer: 'Other Events', approved: false)];
    db.clubStaff['v1'] = [
      clubStaffRow(member: 'm1', person: 'Dan Door'),
      clubStaffRow(invitation: 'i1', person: 'wait@x.example', state: 'invited'),
      clubStaffRow(member: 'm2', person: 'Old Olga', state: 'expired'),
    ];
  });

  testWidgets('a manager sees each event at the club with the organizer, the permission and its sentence', (tester) async {
    await open(tester);
    expect(find.text('Rooftop Sessions'), findsOneWidget);
    expect(find.textContaining('Night Events may not invite door staff for this event.'), findsOneWidget);
    expect(find.textContaining('The terms are not agreed yet'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('club-door-switch-a1'))).value, isFalse);
    expect(find.textContaining('cannot change prices'), findsOneWidget);
    expect(db.paramsOf('venue_door_permissions').single, {'p_venue': 'v1'});
  });

  testWidgets('allowing it is saved at once and said', (tester) async {
    await open(tester);
    await tapKey(tester, 'club-door-switch-a1');
    expect(db.paramsOf('set_organizer_door_staff').single, {'p_agreement': 'a1', 'p_allowed': true});
    expect(find.textContaining('Allowed. Night Events can invite door staff for Rooftop Sessions.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('club-door-switch-a1'))).value, isTrue);
    expect(find.textContaining('Night Events may invite door staff for this event.'), findsOneWidget);
  });

  testWidgets('turning it off asks first, says what it does, and only then saves', (tester) async {
    db.permissions['v1']![0]['door_staff_allowed'] = true;
    await open(tester);
    await tapKey(tester, 'club-door-switch-a1');
    expect(find.textContaining('Invitations still waiting for Rooftop Sessions are cancelled'), findsOneWidget);
    expect(find.textContaining('People already in keep their access'), findsOneWidget);
    await tapKey(tester, 'keep');
    expect(db.count('set_organizer_door_staff'), 0);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('club-door-switch-a1'))).value, isTrue);
    await tapKey(tester, 'club-door-switch-a1');
    await tapKey(tester, 'confirm-remove');
    expect(db.paramsOf('set_organizer_door_staff').single, {'p_agreement': 'a1', 'p_allowed': false});
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('club-door-switch-a1'))).value, isFalse);
  });

  testWidgets('a refusal from the database is shown in its own words and the switch stays as it was', (tester) async {
    await open(tester);
    db.beforeCall = (fn) {
      if (fn == 'set_organizer_door_staff') throw PostgrestException(message: 'this agreement has ended', code: 'P0001');
    };
    await tapKey(tester, 'club-door-switch-a1');
    expect(find.text('This agreement has ended.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('club-door-switch-a1'))).value, isFalse);
  });

  testWidgets('the organizers\' door staff and invitations are listed with the event and the state', (tester) async {
    await open(tester);
    expect(find.text('Dan Door'), findsOneWidget);
    expect(find.text('wait@x.example'), findsOneWidget);
    expect(find.textContaining('Rooftop Sessions · Night Events\nHas access'), findsOneWidget);
    expect(find.textContaining('Invited, not accepted yet'), findsOneWidget);
    expect(find.byKey(const Key('club-door-revoke-m1')), findsOneWidget);
    expect(find.byKey(const Key('club-door-revoke-i1')), findsOneWidget);
    expect(find.byKey(const Key('club-door-revoke-m2')), findsNothing, reason: 'access that has ended offers nothing to take away');
  });

  testWidgets('removing a person asks first, then takes their access away; cancelling an invitation likewise', (tester) async {
    await open(tester);
    await tapKey(tester, 'club-door-revoke-m1');
    expect(find.text('Remove Dan Door?'), findsOneWidget);
    await tapKey(tester, 'keep');
    expect(db.count('revoke_event_door_access'), 0);
    await tapKey(tester, 'club-door-revoke-m1');
    await tapKey(tester, 'confirm-remove');
    expect(db.paramsOf('revoke_event_door_access').single, {'p_membership': 'm1', 'p_invitation': null});
    expect(find.text('Dan Door'), findsNothing);
    await tapKey(tester, 'club-door-revoke-i1');
    expect(find.text('Cancel the invitation to wait@x.example?'), findsOneWidget);
    await tapKey(tester, 'confirm-remove');
    expect(db.paramsOf('revoke_event_door_access').last, {'p_membership': null, 'p_invitation': 'i1'});
  });

  testWidgets('with nothing yet, it says so', (tester) async {
    db.permissions['v1'] = [];
    db.clubStaff['v1'] = [];
    await open(tester);
    expect(find.byKey(const Key('club-door-none')), findsOneWidget);
    expect(find.byKey(const Key('club-door-staff-none')), findsOneWidget);
  });

  testWidgets('a failed read is plain with Try again, in each half separately', (tester) async {
    db.beforeCall = (fn) {
      if (fn == 'venue_event_door_staff') throw StateError('relation "site_memberships" does not exist');
    };
    await open(tester);
    expect(find.byKey(const Key('club-door-staff-error')), findsOneWidget);
    expect(find.textContaining('relation'), findsNothing);
    expect(find.text('Rooftop Sessions'), findsOneWidget, reason: 'the permissions still show');
    db.beforeCall = null;
    await tapKey(tester, 'club-door-staff-retry');
    expect(find.text('Dan Door'), findsOneWidget);
  });

  testWidgets('an owner picks a club; each club has its own permissions and people', (tester) async {
    db.permissions['v2'] = [permissionRow('a9', 'e9', 'Harbour Party', organizer: 'Harbour Events')];
    db.clubStaff['v2'] = [];
    await open(tester, owner);
    expect(find.byKey(const Key('club-door-venues')), findsOneWidget);
    expect(find.text('Rooftop Sessions'), findsOneWidget);
    await tapKey(tester, 'club-door-venue-v2');
    expect(find.text('Harbour Party'), findsOneWidget);
    expect(find.text('Rooftop Sessions'), findsNothing);
    expect(db.paramsOf('venue_door_permissions').last, {'p_venue': 'v2'});
  });

  testWidgets('an owner with no venue is told, and a failed venue list is plain with Try again', (tester) async {
    venues = () async => const [];
    await open(tester, owner);
    expect(find.byKey(const Key('club-door-no-venues')), findsOneWidget);
    var fail = true;
    venues = () async {
      if (fail) throw StateError('relation "site_venues" does not exist');
      return const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')];
    };
    await open(tester, owner);
    expect(find.byKey(const Key('club-door-error')), findsOneWidget);
    expect(find.textContaining('relation'), findsNothing);
    fail = false;
    await tapKey(tester, 'club-door-retry');
    expect(find.text('Rooftop Sessions'), findsOneWidget);
  });
}
