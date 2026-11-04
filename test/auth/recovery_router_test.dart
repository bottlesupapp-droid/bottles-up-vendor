import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/providers/password_recovery_provider.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/forgot_password_screen.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/auth/screens/reset_code_screen.dart';
import 'package:bottles_up_vendor/features/auth/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../workspace/fake_auth.dart';
import 'recovery_support.dart';

const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c';

/// In-memory PKCE storage, so the test never touches the device's preferences.
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The router reads the auth provider, which needs a Supabase client: a dummy local address, in-memory storage, no session.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      authOptions: FlutterAuthClientOptions(autoRefreshToken: false, localStorage: const EmptyLocalStorage(), pkceAsyncStorage: _MemoryAsyncStorage()),
    );
  });

  late RecoveryHarness h;

  setUp(() => h = RecoveryHarness());

  Future<void> visit(WidgetTester tester, String location, {bool signedIn = false}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      passwordRecoveryServiceProvider.overrideWithValue(h.service),
      if (signedIn) ...[
        isAuthenticatedProvider.overrideWithValue(true),
        currentVendorUserProvider.overrideWithValue(vendorRow(onboardingCompleted: true)),
      ],
    ]);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pump(const Duration(milliseconds: 100));
    router.go(location);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a signed-out person can open the forgot-password, code and new-password screens', (tester) async {
    await visit(tester, '/forgot-password');
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    await visit(tester, '/reset-code?email=sam@example.com');
    expect(find.byType(ResetCodeScreen), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);

    await visit(tester, '/reset-password?expired=1');
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('This reset has expired'), findsOneWidget);
  });

  testWidgets('a person who is already signed in as a vendor is NOT sent to the dashboard when they open a reset link', (tester) async {
    await visit(tester, '/reset-password?expired=1', signedIn: true);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.text('This reset has expired'), findsOneWidget);
  });

  testWidgets('nor from the code screen', (tester) async {
    await visit(tester, '/reset-code?email=sam@example.com', signedIn: true);
    expect(find.byType(ResetCodeScreen), findsOneWidget);
  });

  testWidgets('a token in the address reaches the screen and is spent once', (tester) async {
    h.auth.session = false;
    await visit(tester, '/reset-password?token_hash=$hash&type=recovery');
    expect(h.auth.calls, ['token:$hash']);
    expect(find.byKey(const Key('reset-new-password')), findsOneWidget);
  });

  testWidgets('a token that is not the shape of ours is never sent anywhere: the screen says the link is no good', (tester) async {
    h.auth.session = false;
    await visit(tester, '/reset-password?token_hash=short&type=recovery');
    expect(h.auth.calls, isEmpty);
    expect(find.text('This reset has expired'), findsOneWidget);
  });

  testWidgets('a token without type=recovery is not used either', (tester) async {
    h.auth.session = false;
    await visit(tester, '/reset-password?token_hash=$hash&type=signup');
    expect(h.auth.calls, isEmpty);
    expect(find.text('This reset has expired'), findsOneWidget);
  });
}
