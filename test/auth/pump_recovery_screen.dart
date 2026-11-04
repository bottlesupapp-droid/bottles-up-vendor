import 'package:bottles_up_vendor/features/auth/providers/password_recovery_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'recovery_support.dart';

/// Shows [screen] at `/start` inside a router that has a labelled page for every place the reset screens send the person, so a test can see where
/// they ended up. [harness] stands in for the real reset flow.
Future<GoRouter> pumpRecoveryScreen(
  WidgetTester tester,
  Widget screen, {
  required RecoveryHarness harness,
  List<Override> overrides = const [],
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Page<void> page(String label) => NoTransitionPage<void>(child: Scaffold(body: Center(child: Text(label))));
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => screen),
      GoRoute(path: '/reset-password', pageBuilder: (context, state) => page('NEW PASSWORD PAGE')),
      GoRoute(path: '/login', pageBuilder: (context, state) => page('LOGIN PAGE')),
      GoRoute(path: '/forgot-password', pageBuilder: (context, state) => page('FORGOT PAGE')),
      GoRoute(path: '/reset-code', pageBuilder: (context, state) => page('CODE PAGE ${state.uri.queryParameters['email']}')),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [passwordRecoveryServiceProvider.overrideWithValue(harness.service), ...overrides],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  return router;
}
