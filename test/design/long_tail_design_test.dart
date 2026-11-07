import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart' show ChatPerson;
import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/inventory/providers/inventory_providers.dart';
import 'package:bottles_up_vendor/features/inventory/screens/inventory_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/security/providers/security_providers.dart';
import 'package:bottles_up_vendor/features/security/screens/incidents_screen.dart';
import 'package:bottles_up_vendor/features/vip/providers/vip_providers.dart';
import 'package:bottles_up_vendor/features/vip/screens/vip_screen.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart' show WorkspaceSnapshot;
import 'package:bottles_up_vendor/features/workspace/models/role_navigation.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_load_failed_screen.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_section_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

import '../inventory/fake_inventory_backend.dart';
import '../security/fake_security_backend.dart';
import '../vip/fake_vip_backend.dart';
import '../workspace/fake_auth.dart';
import '../workspace/no_workspace_screen_test.dart' show Harness;
import 'role_test_support.dart';

void main() {
  setUpAll(loadInter);

  group('the More pages have the kit\'s page header: an eyebrow, the title, and the page\'s button at the right', () {
    testWidgets('Incidents: a Security eyebrow, and "Report" beside the title', (tester) async {
      final db = FakeSecurityBackend();
      await showScreen(tester, IncidentsScreen(workspace: securityWs, clock: friday9pm), [securityServiceProvider.overrideWithValue(db.service), securityPollIntervalProvider.overrideWithValue(const Duration(hours: 1))]);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Incidents'), findsOneWidget);
      expect(find.byType(BuPageHeader), findsOneWidget);
      final header = tester.getRect(find.byType(BuPageHeader));
      final report = tester.getRect(find.byKey(const Key('incident-report')));
      expect(report.right, closeTo(header.right, 1), reason: 'the button is at the right of the header');
      expect(report.top, lessThan(header.bottom));
    });

    testWidgets('Inventory: a Stock eyebrow, and "History" beside the title', (tester) async {
      final db = FakeInventoryBackend();
      await showScreen(tester, InventoryScreen(workspace: managerWs, clock: friday9pm), [inventoryServiceProvider.overrideWithValue(db.service)]);
      expect(find.text('STOCK'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.byType(BuPageHeader), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('stock-history-all'))).right, closeTo(tester.getRect(find.byType(BuPageHeader)).right, 1));
    });

    testWidgets('VIP guests: a Guests eyebrow, and "Add" beside the title', (tester) async {
      final db = FakeVipBackend();
      await showScreen(tester, VipScreen(workspace: managerWs), [
        vipServiceProvider.overrideWithValue(db.service),
        chatPeopleProvider.overrideWith((ref, venue) async => const <ChatPerson>[]),
        ownerVenuesProvider.overrideWith((ref, org) async => const <OrgVenue>[]),
      ]);
      expect(find.text('GUESTS'), findsOneWidget);
      expect(find.text('VIP guests'), findsOneWidget);
      expect(find.byType(BuPageHeader), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('vip-add')), matching: find.byIcon(Ionicons.person_add_outline)), findsOneWidget);
    });
  });

  group('the screens a person meets before they have a workspace', () {
    testWidgets('"Set up your business" has a Welcome eyebrow, a larger title, the invitation in a card, all on the warm backdrop', (tester) async {
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();
      expect(find.text('WELCOME'), findsOneWidget);
      expect(find.byKey(const Key('no-workspace-title')), findsOneWidget);
      expect(find.byType(BuBackdrop), findsOneWidget);
      expect(find.ancestor(of: find.byKey(const Key('invitation-field')), matching: find.byType(BuCard)), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('invitation-field'))).decoration!.border, isNull);
      expect(find.byKey(const Key('use-invitation-button')), findsOneWidget);
      expect(find.byKey(const Key('check-again-button')), findsOneWidget);
    });

    testWidgets('"We could not load your workspace" is a card on the backdrop, with an amber icon tile and the one orange Retry', (tester) async {
      tester.view.physicalSize = const Size(393, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fakeAuth(FakeAuthNotifier(const SupabaseAuthState())),
          workspaceSnapshotProvider.overrideWith((ref) async => const WorkspaceSnapshot.error('offline')),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const WorkspaceLoadFailedScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BuBackdrop), findsOneWidget);
      expect(find.ancestor(of: find.byKey(const Key('workspace-failed-title')), matching: find.byType(BuCard)), findsOneWidget);
      final tile = tester.widget<Container>(find.descendant(of: find.byType(BuIconTile), matching: find.byType(Container)).first);
      expect((tile.decoration! as BoxDecoration).color, bu.amber.withValues(alpha: 0.12));
      expect(tester.widget<Icon>(find.descendant(of: find.byType(BuIconTile), matching: find.byIcon(Ionicons.cloud_offline_outline))).color, bu.amber);
      expect(textColor(tester, find.byKey(const Key('workspace-failed-body'))), bu.muted);
      expect(find.byKey(const Key('workspace-retry')), findsOneWidget);
    });
  });

  group('a tab that has no screen yet', () {
    testWidgets('has the role as its eyebrow, the tab\'s name as its title, what it will hold in muted text, and the plain "Not built yet" in a card', (tester) async {
      final section = navigationFor(WorkspaceRole.verifier).byId('review')!;
      await showScreen(tester, NotBuiltYetSection(workspace: verifierWs, section: section), const []);
      expect(find.byType(BuPageHeader), findsOneWidget);
      expect(find.text(verifierWs.role.label.toUpperCase()), findsOneWidget);
      expect(find.text(section.label), findsOneWidget);
      expect(textColor(tester, find.text(section.summary)), bu.muted);
      expect(tester.widget<BuCard>(find.byKey(const Key('not-built-yet'))).padding, const EdgeInsets.all(BuSpace.l));
      expect(find.textContaining('Not built yet.'), findsOneWidget);
    });
  });
}

