import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The router reads the auth provider, which needs a Supabase client. Point it at
    // a dummy local address with in-memory storage and no session, so nothing touches
    // the network or the device.
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

  group('Router Smoke Tests', () {
    test('Router provider can be created', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      expect(router, isNotNull);
      expect(router.routerDelegate, isNotNull);
    });

    test('Router has login route configured', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      expect(router.routeInformationParser, isNotNull);
      expect(router.routeInformationProvider, isNotNull);
    });

    testWidgets('A signed-out user is shown the login screen', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: container.read(routerProvider)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Whatever the starting URL, with no session the redirect must end on /login.
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
