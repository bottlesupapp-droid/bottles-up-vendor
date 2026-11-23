import 'dart:async';

import 'package:bottles_up_vendor/features/business_name/providers/business_name_providers.dart';
import 'package:bottles_up_vendor/features/business_name/services/business_name_service.dart';
import 'package:bottles_up_vendor/features/more/screens/more_screen.dart';
import 'package:bottles_up_vendor/features/more/screens/workspace_settings_screen.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The REAL path: More's "settings" page for a workspace (`moreDestinationFor`), the real provider for the service (only its database call is faked), and the real workspace list provider (counted).

Workspace ws(WorkspaceRole role) => Workspace(
  membershipId: 'm1',
  orgId: 'org-1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: role,
);

void main() {
  late List<Map<String, dynamic>> calls;
  late int workspaceListLoads;
  Completer<void>?
  hold; // when set, the database answers only after it completes

  Future<void> open(WidgetTester tester, WorkspaceRole role) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessNameServiceProvider.overrideWithValue(
            BusinessNameService(
              rpc: (function, {params}) async {
                calls.add({'function': function, ...?params});
                if (hold != null) await hold!.future;
                return [
                  {
                    'new_name': params!['p_name'],
                    'events_updated': 2,
                    'can_change_again_at': null,
                  },
                ];
              },
            ),
          ),
          workspaceSnapshotProvider.overrideWith((ref) async {
            workspaceListLoads++;
            return WorkspaceSnapshot.ready([ws(role)]);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: moreDestinationFor(ws(role), 'settings')!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    calls = [];
    workspaceListLoads = 0;
    hold = null;
  });

  testWidgets(
    'the owner\'s Settings has the business name row, wired to the real service for THIS business',
    (tester) async {
      await open(tester, WorkspaceRole.owner);
      expect(find.byType(WorkspaceSettingsScreen), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-business-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('business-name-field')),
        'Club Co Toronto',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('business-name-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('business-name-confirm')));
      await tester.pumpAndSettle();

      expect(calls, [
        {
          'function': 'rename_business',
          'p_org': 'org-1',
          'p_name': 'Club Co Toronto',
        },
      ]);
      expect(find.text('Club Co Toronto'), findsOneWidget);
      expect(find.textContaining('2 upcoming events show it'), findsOneWidget);
    },
  );

  testWidgets(
    'after a rename the workspace list is asked for again (so the new name shows everywhere), and not before',
    (tester) async {
      await open(tester, WorkspaceRole.owner);
      // the list is only read by something that watches it; read it once the way the app's router and shell do
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceSettingsScreen)),
      );
      container.listen(workspaceSnapshotProvider, (_, __) {});
      await tester.pumpAndSettle();
      final before = workspaceListLoads;
      expect(before, greaterThan(0));

      await tester.tap(find.byKey(const Key('settings-business-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('business-name-field')),
        'Club Co Toronto',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('business-name-continue')));
      await tester.pumpAndSettle();
      expect(
        workspaceListLoads,
        before,
        reason: 'asked again before anything was saved',
      );

      hold =
          Completer<
            void
          >(); // the database is slow: the list must not be refreshed while the rename is still being saved
      await tester.tap(find.byKey(const Key('business-name-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls.length, 1, reason: 'the rename was sent');
      expect(
        workspaceListLoads,
        before,
        reason: 'the list was refreshed before the rename was saved',
      );
      hold!.complete();
      await tester.pumpAndSettle();

      expect(workspaceListLoads, before + 1);
    },
  );

  testWidgets(
    'an organizer gets it too; a manager\'s Settings is the plain one with the name read only (and needs no providers at all)',
    (tester) async {
      await open(tester, WorkspaceRole.organizer);
      expect(find.text('Change'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: moreDestinationFor(ws(WorkspaceRole.manager), 'settings')!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Club Co'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
      expect(
        find.textContaining('Only the business owner can change it'),
        findsOneWidget,
      );
    },
  );
}
