import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/no_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth.dart';

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

/// The REAL router (app_router.dart), with only the people and their workspaces made up.
Widget app({required SupabaseAuthState auth, required WorkspaceSnapshot snapshot}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      fakeAuth(FakeAuthNotifier(auth)),
      workspaceSnapshotProvider.overrideWith((ref) async => snapshot),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider), theme: ThemeData.dark()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );
  });

  testWidgets('somebody with no workspace and no classic dashboard lands on "Set up your business"', (tester) async {
    await tester.pumpWidget(app(
      auth: SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true),
      snapshot: const WorkspaceSnapshot.ready([]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoWorkspaceScreen), findsOneWidget);
    expect(find.text('Set up your business'), findsOneWidget);
  });

  testWidgets('...also when the website made them a vendors row they never finished (the old auto-created kind)', (tester) async {
    await tester.pumpWidget(app(
      auth: SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: false), vendorChecked: true),
      snapshot: const WorkspaceSnapshot.ready([]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoWorkspaceScreen), findsOneWidget); // not the classic onboarding
  });

  testWidgets('while their vendors row has not been looked up nothing is decided: the sign-in page stays', (tester) async {
    await tester.pumpWidget(app(
      auth: SupabaseAuthState(supabaseUser: supabaseUser()), // vendorChecked: false
      snapshot: const WorkspaceSnapshot.ready([]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoWorkspaceScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a signed-out visitor still gets the sign-in page', (tester) async {
    await tester.pumpWidget(app(auth: const SupabaseAuthState(), snapshot: const WorkspaceSnapshot.ready([])));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NoWorkspaceScreen), findsNothing);
  });
}
