import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/terms_of_service_screen.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/no_workspace_screen.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_selector_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../workspace/fake_auth.dart';

/// In-memory PKCE storage, so the test never touches the device's preferences.
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}

Workspace owner(String id, String orgName) => Workspace(membershipId: id, orgId: 'o-$id', orgName: orgName, orgKind: 'venue_owner', role: WorkspaceRole.owner);

/// What the test changes while the app is running: the workspace list the database would answer with.
final _workspaces = StateProvider<WorkspaceSnapshot>((ref) => const WorkspaceSnapshot.loading());

/// The REAL router (app_router.dart) in a real [MaterialApp.router], with only the people and their workspaces made up, and a way to change both while it runs.
class Harness {
  Harness(this.auth, WorkspaceSnapshot snapshot) {
    container = ProviderContainer(overrides: [
      fakeAuth(auth),
      _workspaces.overrideWith((ref) => snapshot),
      workspaceSnapshotProvider.overrideWith((ref) async => ref.watch(_workspaces)),
    ]);
  }

  final FakeAuthNotifier auth;
  late final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);
  String get place => router.routerDelegate.currentConfiguration.uri.toString();
  int get depth => router.routerDelegate.currentConfiguration.matches.length;

  void setWorkspaces(WorkspaceSnapshot snapshot) => container.read(_workspaces.notifier).state = snapshot;

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider), theme: ThemeData.dark())),
    ));
    await tester.pumpAndSettle();
  }
}

Harness signedInOwner() => Harness(
      FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true)),
      WorkspaceSnapshot.ready([owner('m1', 'Old name'), owner('m2', 'Other club')]),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      authOptions: FlutterAuthClientOptions(autoRefreshToken: false, localStorage: const EmptyLocalStorage(), pkceAsyncStorage: _MemoryAsyncStorage()),
    );
  });

  group('the router keeps the person where they are', () {
    testWidgets('a signed-in owner with two businesses lands on the list of workspaces', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);

      expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
      expect(h.place, '/workspaces');
    });

    testWidgets('the workspace list refreshing (a business renamed) does not send the person back to the start', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();
      expect(h.place, '/w/m1/more');
      final before = h.router;

      h.setWorkspaces(WorkspaceSnapshot.ready([owner('m1', 'New name'), owner('m2', 'Other club')]));
      await tester.pumpAndSettle();

      expect(h.place, '/w/m1/more', reason: 'the person was bounced to the start');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byKey(const Key('more-list')), findsOneWidget);
      expect(identical(h.router, before), isTrue, reason: 'the router was rebuilt');
    });

    testWidgets('...and a page they had opened on top stays on top, with the same stack under it', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();
      h.router.push('/legal/terms');
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      final depth = h.depth;

      h.setWorkspaces(WorkspaceSnapshot.ready([owner('m1', 'New name'), owner('m2', 'Other club')]));
      await tester.pumpAndSettle();

      expect(find.byType(TermsOfServiceScreen), findsOneWidget, reason: 'the page they were reading was closed');
      expect(h.depth, depth, reason: 'the stack changed');

      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more-list')), findsOneWidget, reason: 'back does not return to where they were');
    });

    testWidgets('the sign-in token renewing (the same person, a new session object) does not move them either', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();
      final before = h.router;

      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: true), vendorChecked: true);
      await tester.pumpAndSettle();

      expect(h.place, '/w/m1/more');
      expect(find.byKey(const Key('more-list')), findsOneWidget);
      expect(identical(h.router, before), isTrue);
    });

    testWidgets('signing out still takes them to the sign-in page, from wherever they are', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();

      final before = h.router;
      h.auth.state = const SupabaseAuthState();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.place, '/login');
      expect(identical(h.router, before), isTrue, reason: 'signing out rebuilt the router');
    });

    testWidgets('signing in from the sign-in page still takes them on, to their workspaces', (tester) async {
      final h = Harness(FakeAuthNotifier(const SupabaseAuthState()), WorkspaceSnapshot.ready([owner('m1', 'Old name'), owner('m2', 'Other club')]));
      addTearDown(h.container.dispose);
      await h.start(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      final before = h.router;
      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true);
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
      expect(h.place, '/workspaces');
      expect(identical(h.router, before), isTrue, reason: 'signing in rebuilt the router');
    });

    testWidgets('signing in before the vendor row has been looked up still takes them to their workspaces (only "signed in" changed)', (tester) async {
      final h = Harness(FakeAuthNotifier(const SupabaseAuthState()), WorkspaceSnapshot.ready([owner('m1', 'Old name'), owner('m2', 'Other club')]));
      addTearDown(h.container.dispose);
      await h.start(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser()); // vendorChecked: false
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
    });

    testWidgets('a workspace that is taken away still sends the person back to the list (access is re-checked on every change)', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();

      h.setWorkspaces(WorkspaceSnapshot.ready([owner('m2', 'Other club'), owner('m3', 'Third club')]));
      await tester.pumpAndSettle();

      expect(h.place, '/workspaces');
      expect(find.byType(WorkspaceSelectorScreen), findsOneWidget);
    });

    testWidgets('losing every workspace still sends the person to "Set up your business"', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();

      h.setWorkspaces(const WorkspaceSnapshot.ready([]));
      await tester.pumpAndSettle();

      expect(find.byType(NoWorkspaceScreen), findsOneWidget);
    });

    testWidgets('the vendor row being looked up still moves a signed-in person with no business on, to "Set up your business"', (tester) async {
      final h = Harness(FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser())), const WorkspaceSnapshot.ready([]));
      addTearDown(h.container.dispose);
      await h.start(tester);
      expect(find.byType(LoginScreen), findsOneWidget, reason: 'nothing is decided until the vendor row has been looked up');

      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true);
      await tester.pumpAndSettle();

      expect(find.byType(NoWorkspaceScreen), findsOneWidget);
    });

    testWidgets('an unfinished account on a server without workspaces is still sent to finish setting up when its row arrives', (tester) async {
      final h = Harness(FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true)), const WorkspaceSnapshot.unavailable());
      addTearDown(h.container.dispose);
      await h.start(tester);
      expect(h.place, '/login');

      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: false), vendorChecked: true);
      await tester.pumpAndSettle();

      expect(h.place, startsWith('/onboarding/'));
    });

    testWidgets('several changes at once (token renewed, list refreshed) refresh the rules and leave the router alone', (tester) async {
      final h = signedInOwner();
      addTearDown(h.container.dispose);
      await h.start(tester);
      h.router.go('/w/m1/more');
      await tester.pumpAndSettle();
      final before = h.router;

      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true);
      h.setWorkspaces(WorkspaceSnapshot.ready([owner('m1', 'Renamed'), owner('m2', 'Other club')]));
      h.auth.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: true), vendorChecked: true);
      await tester.pumpAndSettle();

      expect(h.place, '/w/m1/more');
      expect(identical(h.router, before), isTrue);
    });
  });
}
