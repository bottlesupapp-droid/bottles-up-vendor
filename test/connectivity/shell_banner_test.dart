import 'package:bottles_up_vendor/core/connectivity/connection_monitor.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/widgets/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ws = Workspace(membershipId: 'm1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

Widget app({required bool enabled, required Future<bool> Function() probe}) {
  final router = GoRouter(initialLocation: '/w/m1/home', routes: [
    ShellRoute(
      builder: (context, state, child) => WorkspaceShell(membershipId: 'm1', child: child),
      routes: [GoRoute(path: '/w/:membershipId/:section', builder: (_, __) => const Center(child: Text('the screen')))],
    ),
  ]);
  return ProviderScope(
    overrides: [
      workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready(const [ws])),
      connectionMonitorEnabledProvider.overrideWithValue(enabled),
      connectionProbeProvider.overrideWithValue(probe),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('a phone that cannot reach the server is told so inside every workspace, under the who-and-where bar, and the screen stays usable', (tester) async {
    var up = false;
    await tester.pumpWidget(app(enabled: true, probe: () async => up));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-banner')), findsNothing, reason: 'nothing is said before two checks have failed');
    await tester.pump(connectionCheckEvery);
    await tester.pump(connectionCheckEvery);
    await tester.pump();
    expect(find.byKey(const Key('connection-banner')), findsOneWidget);
    expect(find.text('the screen'), findsOneWidget);
    expect(find.byKey(const Key('workspace-context-bar')), findsOneWidget);
    up = true;
    await tester.tap(find.byKey(const Key('connection-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('connection-banner')), findsNothing);
    // Take the app down before the next timer fires.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with the monitor off (tests, previews) nothing is ever shown and no timer runs', (tester) async {
    await tester.pumpWidget(app(enabled: false, probe: () async => false));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 5));
    expect(find.byKey(const Key('connection-banner')), findsNothing);
  });
}
