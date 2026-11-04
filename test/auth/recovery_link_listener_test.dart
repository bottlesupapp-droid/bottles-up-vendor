import 'dart:async';

import 'package:bottles_up_vendor/core/router/app_router.dart';
import 'package:bottles_up_vendor/features/auth/services/recovery_link_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c';

class _FakeSource implements RecoveryLinkSource {
  Uri? initial;
  final controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get links => controller.stream;
}

void main() {
  late _FakeSource source;
  late GoRouter router;
  late List<String> visited;

  Future<void> open(WidgetTester tester) async {
    visited = [];
    router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (context, state) => const Text('START')),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            visited.add(state.uri.toString());
            return const Text('NEW PASSWORD');
          },
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recoveryLinkSourceProvider.overrideWithValue(source),
        routerProvider.overrideWithValue(router),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => RecoveryLinkListener(child: child ?? const SizedBox.shrink()),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> arrive(WidgetTester tester, String link) async {
    source.controller.add(Uri.parse(link));
    await tester.pumpAndSettle();
  }

  setUp(() => source = _FakeSource());

  testWidgets('a reset link that arrives while the app is open goes to the new-password screen, with its token', (tester) async {
    await open(tester);
    await arrive(tester, 'bottlesupbusiness://app/reset-password?token_hash=$hash&type=recovery');
    expect(find.text('NEW PASSWORD'), findsOneWidget);
    expect(visited.single, '/reset-password?token_hash=$hash&type=recovery');
  });

  testWidgets('a reset link that started the app is opened too', (tester) async {
    source.initial = Uri.parse('bottlesupbusiness://app/reset-password?token_hash=$hash&type=recovery');
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('NEW PASSWORD'), findsOneWidget);
  });

  testWidgets('a dead link goes to the "expired" version of the screen', (tester) async {
    await open(tester);
    await arrive(tester, 'bottlesupbusiness://app/reset-password?error=access_denied');
    expect(visited.single, '/reset-password?expired=1');
  });

  testWidgets('a link that is not about resetting a password is ignored', (tester) async {
    await open(tester);
    await arrive(tester, 'bottlesupbusiness://app/login');
    await arrive(tester, 'https://www.bottlesupapp.com/accept-invite?token=abc');
    expect(find.text('START'), findsOneWidget);
    expect(visited, isEmpty);
  });

  testWidgets('an error on the link stream does not crash the app', (tester) async {
    await open(tester);
    source.controller.addError(Exception('platform channel went away'));
    await tester.pumpAndSettle();
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('it stops listening when it is removed', (tester) async {
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    expect(source.controller.hasListener, isFalse);
  });
}
