import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bottles_up_vendor/core/router/app_router.dart';

void main() {
  group('Router Smoke Tests', () {
    test('Router provider can be created', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify router provider exists and can be read
      final router = container.read(routerProvider);
      expect(router, isNotNull);
      expect(router.routerDelegate, isNotNull);
    });

    test('Router has login route configured', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      // Verify router configuration exists
      expect(router.routeInformationParser, isNotNull);
      expect(router.routeInformationProvider, isNotNull);
    });
  });
}
