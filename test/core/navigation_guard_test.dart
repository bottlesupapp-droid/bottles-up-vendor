import 'package:bottles_up_vendor/core/router/app_router.dart' show CupertinoTransitionPage, pageTransitionDuration;
import 'package:bottles_up_vendor/core/router/guarded_router.dart';
import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/core/ui/bu_tap_guard.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
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

/// Opens /a, lets it settle, and goes back to the home page: the state of someone who tapped a row and came back.
Future<void> _openAndGoBack(WidgetTester tester, GuardedGoRouter router) async {
  router.push('/a');
  await tester.pumpAndSettle();
  router.pop();
  await tester.pumpAndSettle();
  expect(_depth(router), 1);
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
      final router = await _start(tester, clock, []);
      for (var i = 0; i < 3; i++) {
        router.push('/a');
        clock.advance(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
    });

    testWidgets('rule 1: a page is never pushed on top of itself, however long ago it opened (a slow page is longer than any timer)', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.push('/a');
      await tester.pumpAndSettle();
      clock.advance(const Duration(hours: 1));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
      expect(built, ['a']);
    });

    testWidgets('rule 1 knows a different query is a different place, and the same query in another order is the same place', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a?x=1&y=2');
      await tester.pumpAndSettle();
      router.push('/a?y=2&x=1');
      await tester.pumpAndSettle();
      expect(_depth(router), 2, reason: 'the same place, asked for in another order');
      clock.advance(const Duration(seconds: 2));
      router.push('/a?x=1');
      await tester.pumpAndSettle();
      expect(_depth(router), 3, reason: 'a different query is a different place');
      clock.advance(const Duration(seconds: 2));
      router.push('/a?x=1&y=2');
      await tester.pumpAndSettle();
      expect(_depth(router), 4, reason: 'on top is now ?x=1, so ?x=1&y=2 is another place');
    });

    testWidgets('rule 1 compares the path too: another page with the same (empty) query is not held back', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a');
      await tester.pumpAndSettle();
      clock.advance(const Duration(seconds: 2));
      router.push('/b');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('rule 1 compares the values: the same key with another value is another place', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a?x=1');
      await tester.pumpAndSettle();
      clock.advance(const Duration(seconds: 2));
      router.push('/a?x=2');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('rule 1 compares repeated keys: ?x=1&x=2 and ?x=1 are different places, and ?x=1 again is the same', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      router.push('/a?x=1&x=2');
      await tester.pumpAndSettle();
      clock.advance(const Duration(seconds: 2));
      router.push('/a?x=1');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
      clock.advance(const Duration(seconds: 2));
      router.push('/a?x=1');
      await tester.pumpAndSettle();
      expect(_depth(router), 3);
    });

    testWidgets('after going back, the same page can be opened again once the window has passed', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      await _openAndGoBack(tester, router);
      clock.advance(const Duration(milliseconds: 700));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
      expect(built, ['a', 'a']);
    });

    testWidgets('rule 2: going back and tapping straight away is still the same tap (inside the window)', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      await _openAndGoBack(tester, router);
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 1);
    });

    testWidgets('the window is 600 ms: 599 ms is still the same tap, 600 ms is a new one', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      await _openAndGoBack(tester, router);
      clock.advance(const Duration(milliseconds: 599));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 1);
      clock.advance(const Duration(milliseconds: 1)); // 600 ms since the push that was let through
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
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

    testWidgets('pushReplacement is guarded by rule 2: a repeated replace is ignored (done at once), then allowed after the window', (tester) async {
      final clock = _Clock();
      final built = <String>[];
      final router = await _start(tester, clock, built);
      router.pushReplacement<String>('/a');
      // A replace that happens only completes when its page is closed; an ignored one is already done.
      var ignored = false;
      router.pushReplacement<String>('/a').then((_) => ignored = true);
      await tester.pump();
      expect(ignored, isTrue, reason: 'the repeat was ignored');
      await tester.pumpAndSettle();
      expect(built, ['a']);
      clock.advance(const Duration(milliseconds: 700));
      var ignoredLater = false;
      router.pushReplacement<String>('/a').then((_) => ignoredLater = true);
      await tester.pump();
      expect(ignoredLater, isFalse, reason: 'after the window the same replace really happens (replacing a page with itself is how it reloads: rule 1 does not apply to it)');
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
      // Not awaited: a push that really happened only completes when its page is closed, and a test that waits for that never ends. An ignored one is already done.
      var done = false;
      String? result = 'not set';
      router.push<String>('/a').then((v) {
        result = v;
        done = true;
      });
      await tester.pump();
      expect(done, isTrue, reason: 'the ignored push completed straight away');
      expect(result, isNull);
    });

    testWidgets('a clock that moves backwards never holds anyone back', (tester) async {
      final clock = _Clock();
      final router = await _start(tester, clock, []);
      await _openAndGoBack(tester, router);
      clock.advance(const Duration(hours: -1));
      router.push('/a');
      await tester.pumpAndSettle();
      expect(_depth(router), 2);
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
      clock.advance(const Duration(milliseconds: 349));
      expect(g.take(), isFalse);
      clock.advance(const Duration(milliseconds: 1));
      expect(g.take(), isTrue);
    });

    test('the window is a little over Flutter\'s own double-tap time (300 ms), so an accidental second tap is held back and a deliberate one is not', () {
      expect(BuTapGuard().window, const Duration(milliseconds: 350));
      expect(BuTapGuard().window, greaterThan(kDoubleTapTimeout));
    });

    test('a tap that was held back does not extend the wait', () {
      final clock = _Clock();
      final g = BuTapGuard(now: clock.call);
      expect(g.take(), isTrue);
      clock.advance(const Duration(milliseconds: 200));
      expect(g.take(), isFalse);
      clock.advance(const Duration(milliseconds: 150)); // 350 ms after the tap that went through
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
      clock.advance(const Duration(milliseconds: 350));
      await tester.tap(find.text('go'));
      expect(taps, 2);
    });

    testWidgets('it keeps the rounded corners of the ripple it was given', (tester) async {
      await tester.pumpWidget(host(BuGuardedInkWell(onTap: () {}, borderRadius: BorderRadius.circular(18), child: const SizedBox(width: 80, height: 40, child: Text('go')))));
      expect(tester.widget<InkWell>(find.byType(InkWell)).borderRadius, BorderRadius.circular(18));
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

    testWidgets('time is the app\'s clock, so a test moves it with pump: a tap a moment later goes through', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BuGuardedInkWell(onTap: () => taps++, child: const SizedBox(width: 80, height: 40, child: Text('go')))));
      await tester.tap(find.text('go'));
      await tester.tap(find.text('go'));
      expect(taps, 1, reason: 'the same instant');
      await tester.pump(const Duration(milliseconds: 349));
      await tester.tap(find.text('go'));
      expect(taps, 1, reason: '349 ms later is still the same double tap');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tap(find.text('go'));
      expect(taps, 2, reason: '350 ms after the tap that went through');
    });
  });

  group('the kit rows use it', () {
    Widget host(Widget child) => MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: ListView(children: [child])));

    testWidgets('BuListRow: a double tap runs the action once, a tap a moment later runs it again', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(BuListRow(key: const Key('row'), title: 'Settings', onTap: () => taps++)));
      await tester.tap(find.byKey(const Key('row')));
      await tester.tap(find.byKey(const Key('row')));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('row')));
      expect(taps, 2);
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

    testWidgets('a plain button (not from the kit) that pushes a page is covered by the router, even when the page is slow and the second tap comes long after', (tester) async {
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
      clock.advance(const Duration(seconds: 3)); // the person waits, then taps again: no timer would cover this
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
