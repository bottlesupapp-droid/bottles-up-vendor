import 'package:bottles_up_vendor/features/workspace/models/role_navigation.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

// The client's Phase 2 brief, section 2 ("Mobile navigation"), word for word.
const _brief = <WorkspaceRole, List<String>>{
  WorkspaceRole.owner: ['Home', 'Venues', 'Money', 'Reports', 'More'],
  WorkspaceRole.manager: ['Tonight', 'Floor', 'Orders', 'Team', 'More'],
  WorkspaceRole.organizer: ['Home', 'Events', 'Guests', 'Chat', 'More'],
  WorkspaceRole.server: ['My Tables', 'Orders', 'Scan', 'Requests', 'Chat'],
  WorkspaceRole.door: ['Scan', 'Guests', 'Door Sales', 'Chat'],
  WorkspaceRole.security: ['Alerts', 'Tasks', 'Chat', 'Incidents'],
  WorkspaceRole.verifier: ['Review', 'Cash', 'Exceptions', 'Summary'],
};

void main() {
  test('every role in the brief has a navigation, and nothing extra', () {
    expect(_brief.keys.toSet(), WorkspaceRole.values.toSet());
  });

  for (final entry in _brief.entries) {
    test('${entry.key.label} sees exactly the tabs the brief lists, in order', () {
      expect(navigationFor(entry.key).sections.map((s) => s.label).toList(), entry.value);
    });
  }

  test('tab ids are unique within a role and safe to put in a URL', () {
    final safe = RegExp(r'^[a-z][a-z-]*$');
    for (final role in WorkspaceRole.values) {
      final ids = navigationFor(role).sections.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: '$role has duplicate ids');
      for (final id in ids) {
        expect(safe.hasMatch(id), isTrue, reason: '$role id "$id"');
      }
    }
  });

  test('every tab says what it will hold, so an unbuilt tab is never blank', () {
    for (final role in WorkspaceRole.values) {
      for (final s in navigationFor(role).sections) {
        expect(s.summary.trim(), isNotEmpty, reason: '$role/${s.id}');
      }
    }
  });

  test('a role lands on its first tab', () {
    expect(navigationFor(WorkspaceRole.manager).landing.id, 'tonight');
    expect(navigationFor(WorkspaceRole.door).landing.id, 'scan');
    expect(navigationFor(WorkspaceRole.verifier).landing.id, 'review');
  });

  test('indexOf and byId agree, and unknown ids are handled', () {
    final nav = navigationFor(WorkspaceRole.server);
    expect(nav.indexOf('requests'), 3);
    expect(nav.byId('requests')!.label, 'Requests');
    expect(nav.byId('tonight'), isNull);
    expect(nav.indexOf('tonight'), 0);
  });

  test('paths put the membership in the address, so the active workspace survives a reload', () {
    expect(workspaceSectionPath('abc', 'team'), '/w/abc/team');
    final w = Workspace.tryParse({
      'membership_id': 'abc',
      'role': 'door',
      'org_id': 'o',
      'org_name': 'N',
      'org_kind': 'organizer',
    })!;
    expect(workspaceLandingPath(w), '/w/abc/scan');
  });
}
