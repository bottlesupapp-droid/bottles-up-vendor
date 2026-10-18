import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/no_workspace_screen.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_load_failed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth.dart';

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _items[key];
  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

late FakeAuthNotifier auth;
late List<WorkspaceSnapshot> answers; // one per request, the last one repeats
late int requests;

Widget app() {
  auth = FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true));
  requests = 0;
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      fakeAuth(auth),
      workspaceSnapshotProvider.overrideWith((ref) async {
        final i = requests < answers.length ? requests : answers.length - 1;
        requests++;
        return answers[i];
      }),
    ],
    child: Consumer(builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider), theme: ThemeData.dark())),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      authOptions: FlutterAuthClientOptions(autoRefreshToken: false, localStorage: const EmptyLocalStorage(), pkceAsyncStorage: _MemoryAsyncStorage()),
    );
  });

  testWidgets('a failed workspace request shows "We could not load your workspace" with Retry, not the setup page', (tester) async {
    answers = [const WorkspaceSnapshot.error('PostgrestException: relation "site_memberships" does not exist')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceLoadFailedScreen), findsOneWidget);
    expect(find.text('We could not load your workspace'), findsOneWidget);
    expect(find.byKey(const Key('workspace-retry')), findsOneWidget);
    expect(find.byType(NoWorkspaceScreen), findsNothing);
    expect(find.text('Set up your business'), findsNothing);
    expect(find.byKey(const Key('sign-out-button')), findsOneWidget);
  });

  testWidgets('the technical reason is never shown', (tester) async {
    answers = [const WorkspaceSnapshot.error('PostgrestException: relation "site_memberships" does not exist')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Postgrest'), findsNothing);
    expect(find.textContaining('relation'), findsNothing);
    expect(find.textContaining('site_memberships'), findsNothing);
  });

  testWidgets('Retry asks again, and once the answer is "no business" the person is offered setup, not before', (tester) async {
    answers = [const WorkspaceSnapshot.error('offline'), const WorkspaceSnapshot.ready([])];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(NoWorkspaceScreen), findsNothing);

    await tester.tap(find.byKey(const Key('workspace-retry')));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.byType(NoWorkspaceScreen), findsOneWidget);
    expect(find.byType(WorkspaceLoadFailedScreen), findsNothing);
  });

  testWidgets('Retry that fails again stays on the failure page, and can be tried again', (tester) async {
    answers = [const WorkspaceSnapshot.error('offline')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workspace-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-retry')));
    await tester.pumpAndSettle();

    expect(requests, 3);
    expect(find.byType(WorkspaceLoadFailedScreen), findsOneWidget);
    expect(find.byKey(const Key('workspace-retry')), findsOneWidget);
  });

  testWidgets('Sign out is there when the request keeps failing', (tester) async {
    answers = [const WorkspaceSnapshot.error('offline')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign-out-button')));
    await tester.pump();
    expect(auth.signOuts, 1);
  });

  test('the route and its path are the ones the routing rule uses', () {
    expect(WorkspaceRoutes.workspaceError, '/workspace-error');
  });
}
