import 'package:bottles_up_vendor/core/router/app_router.dart' show CupertinoTransitionPage, pageTransitionDuration;
import 'package:bottles_up_vendor/core/router/guarded_router.dart';
import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/core/ui/bu_tap_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A clock the test moves by hand, so "within the window" and "after it" are exact.
class _Clock {
  DateTime now = DateTime(2026, 11, 20, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

int _depth(GoRouter r) => r.routerDelegate.currentConfiguration.matches.length;

GuardedGoRouter _router(_Clock clock, List<String> built) => GuardedGoRouter(
  initialLocation: '/',
  redirect: (context, state) => null,
  now: clock.call,
  routes: [
    GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('home'))),
    GoRoute(
      path: '/a',
      name: 'a',
      builder: (c, s) {
        built.add('a');
        return const Scaffold(body: Text('page a'));
      },
    ),
    GoRoute(
      path: '/b',
      name: 'b',
      builder: (c, s) {
        built.add('b');
        return const Scaffold(body: Text('page b'));
      },
    ),
  ],
);

Future<GuardedGoRouter> _start(WidgetTester tester, _Clock clock, List<String> built) async {
  final router = _router(clock, built);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('GuardedGoRouter: a page opens once however many times it was tapped', () {
    testWidgets('asking for the same page twice at once pushes it once', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.push('/a');
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2, reason: 'home + one copy of the page');
      expect(built, ['a']);
    });

    testWidgets('three quick taps are still one page', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      for (var i = 0; i < 3; i++) {
        router.push('/a');
        clock.advance(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
    });

    testWidgets('the same page again after the window is allowed (someone went back and tapped again)', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a');
      clock.advance(const Duration(milliseconds: 700));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('the window is 600 ms: 599 ms is still the same tap, 600 ms is a new one', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a');
      clock.advance(const Duration(milliseconds: 599));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
      clock.advance(const Duration(milliseconds: 1)); // 600 ms since the push that was let through
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('a different page is never held back', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a');
      router.push('/b');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('pushNamed is guarded too (it goes through push)', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.pushNamed('a');
      router.pushNamed('a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
      expect(built, ['a']);
    });

    testWidgets('pushReplacement is guarded: a repeated replace builds the page once', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.pushReplacement('/a');
      router.pushReplacement('/a');
      await tester.pumpAndSettle();
      expect(built, ['a']);
    });

    testWidgets('a push and then a replace of the same page are two different things, both happen', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.push('/a');
      await tester.pumpAndSettle();
      router.pushReplacement('/a');
      await tester.pumpAndSettle();
      expect(built, ['a', 'a'], reason: 'the replace built its own page; it was not mistaken for a repeat of the push');
      expect(_depth(router), 2);
    });

    testWidgets('a push that was ignored still completes, with null, so nobody waits for ever', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push<String>('/a');
      final second = router.push<String>('/a');
      expect(await second, isNull);
    });

    testWidgets('a clock that moves backwards never holds anyone back', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a');
      clock.advance(const Duration(hours: -1));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('going to a place is not guarded (it changes nothing when you are already there)', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.go('/a');
      router.go('/a');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/a');
      router.go('/b');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/b');
    });
  });

  group('BuTapGuard', () {
    test('the first tap goes through, the next within the window does not, the one after does', () {
      final clock = _Clock();
      final g = BuTapGuard(now: clock.call);
      expect(g.take(), isTrue);
      expect(g.take(), isFalse);
      clock.advance(const Duration(milliseconds: 499));
      expect(g.take(), isFalse);
      clock.advance(const Duration(milliseconds: 1));
      expect(g.take(), isTrue);
    });

    test('a tap that was held back does not extend the wait', () {
      final clock = _Clock();
      final g = BuTapGuard(now: clock.call);
      expect(g.take(), isTrue);
      clock.advance(const Duration(milliseconds: 300));
      expect(g.take(), isFalse);
      clock.advance(const Duration(milliseconds: 200)); // 500 ms after the tap that went through
      expect(g.take(), isTrue);
    });

    test('two guards do not affect each other', () {
      final clock = _Clock();
      final a = BuTapGuard(now: clock.call);
      final b = BuTapGuard(now: clock.call);
      expect(a.take(), isTrue);
      expect(b.take(), isTrue);
    });

    test('a clock that moves backwards never holds anyone back', () {
      final clock = _Clock();
      final g = BuTapGuard(now: clock.call);
      expect(g.take(), isTrue);
      clock.advance(const Duration(hours: -2));
      expect(g.take(), isTrue);
    });
  });

  group('BuGuardedInkWell', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('a double tap runs the action once; after the window it runs again', (tester) async {
      final clock = _Clock();
      var taps = 0;
      await tester.pumpWidget(host(BuGuardedInkWell(guard: BuTapGuard(now: clock.call), onTap: () => taps++, child: const SizedBox(width: 80, height: 40, child: Text('go')))));
      await tester.tap(find.text('go'));
      await tester.tap(find.text('go'));
      expect(taps, 1);
      clock.advance(const Duration(milliseconds: 500));
      await tester.tap(find.text('go'));
      expect(taps, 2);
    });

    testWidgets('with no action it is not tappable', (tester) async {
      await tester.pumpWidget(host(const BuGuardedInkWell(onTap: null, child: SizedBox(width: 80, height: 40, child: Text('go')))));
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.onTap, isNull);
    });

    testWidgets('two different rows are independent: tapping one then the other both run', (tester) async {
      final clock = _Clock();
      var a = 0, b = 0;
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BuGuardedInkWell(guard: BuTapGuard(now: clock.call), onTap: () => a++, child: const SizedBox(width: 80, height: 40, child: Text('one'))),
              BuGuardedInkWell(guard: BuTapGuard(now: clock.call), onTap: () => b++, child: const SizedBox(width: 80, height: 40, child: Text('two'))),
            ],
          ),
        ),
      );
      await tester.tap(find.text('one'));
      await tester.tap(find.text('two'));
      expect([a, b], [1, 1]);
    });
  });

  group('the kit rows use it', () {
    Widget host(Widget child) => MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: ListView(children: [child])));

    testWidgets('BuListRow: a double tap runs the action once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BuListRow(key: const Key('row'), title: 'Settings', onTap: () => taps++)));
      await tester.tap(find.byKey(const Key('row')));
      await tester.tap(find.byKey(const Key('row')));
      expect(taps, 1);
    });

    testWidgets('BuCard: a double tap runs the action once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BuCard(key: const Key('card'), onTap: () => taps++, child: const Text('card'))));
      await tester.tap(find.byKey(const Key('card')));
      await tester.tap(find.byKey(const Key('card')));
      expect(taps, 1);
    });

    testWidgets('BuMiniVenue and BuStatTile (built on BuCard) are guarded too', (tester) async {
      var venue = 0, stat = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              BuMiniVenue(key: const Key('venue'), name: 'Active Lounge', line: 'Toronto', onTap: () => venue++),
              BuStatTile(key: const Key('stat'), label: 'Bookings', value: '19', onTap: () => stat++),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('venue')));
      await tester.tap(find.byKey(const Key('venue')));
      await tester.tap(find.byKey(const Key('stat')));
      await tester.tap(find.byKey(const Key('stat')));
      expect([venue, stat], [1, 1]);
    });

    testWidgets('a row with no action still does nothing', (tester) async {
      await tester.pumpWidget(host(const BuListRow(key: Key('row'), title: 'Read only')));
      await tester.tap(find.byKey(const Key('row')));
      expect(tester.takeException(), isNull);
    });
  });

  group('tapping twice on a screen opens the page once (the whole path, through the router)', () {
    testWidgets('a kit row that pushes a page', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = GuardedGoRouter(
        initialLocation: '/',
        redirect: (context, state) => null,
        now: clock.call,
        routes: [
          GoRoute(
            path: '/',
            builder: (c, s) => Scaffold(body: ListView(children: [BuListRow(key: const Key('open'), title: 'Open', onTap: () => c.push('/a'))])),
          ),
          GoRoute(
            path: '/a',
            pageBuilder: (c, s) {
              built.add('a');
              return const CupertinoTransitionPage(name: 'a', child: Scaffold(body: Text('page a')));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open')));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(built, ['a']);
      expect(_depth(router), 2);
      // One back and we are home: there is no second copy underneath.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open')), findsOneWidget);
      expect(_depth(router), 1);
    });

    testWidgets('a plain button (not from the kit) that pushes a page is covered by the router', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = GuardedGoRouter(
        initialLocation: '/',
        redirect: (context, state) => null,
        now: clock.call,
        routes: [
          GoRoute(path: '/', builder: (c, s) => Scaffold(body: Center(child: TextButton(key: const Key('plain'), onPressed: () => c.push('/a'), child: const Text('Open'))))),
          GoRoute(
            path: '/a',
            pageBuilder: (c, s) {
              built.add('a');
              return const CupertinoTransitionPage(name: 'a', child: Scaffold(body: Text('page a')));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plain')));
      await tester.tap(find.byKey(const Key('plain')));
      await tester.pumpAndSettle();
      expect(built, ['a']);
      expect(_depth(router), 2);
    });
  });

  group('the page slide', () {
    test('is 280 ms and never creeps back above 300', () {
      expect(pageTransitionDuration, const Duration(milliseconds: 280));
      expect(pageTransitionDuration.inMilliseconds, lessThanOrEqualTo(300));
    });

    test('every page of the app uses it, both ways', () {
      const page = CupertinoTransitionPage(name: 'x', child: SizedBox());
      expect(page.transitionDuration, pageTransitionDuration);
      expect(page.reverseTransitionDuration, pageTransitionDuration);
    });
  });
}
