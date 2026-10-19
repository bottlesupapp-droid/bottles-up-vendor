import 'dart:async';

import 'package:bottles_up_vendor/core/connectivity/connection_banner.dart';
import 'package:bottles_up_vendor/core/connectivity/connection_monitor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the rule', () {
    const start = NetworkStatus(online: true);

    test('one failed check is only a slow moment: nothing is said yet', () {
      final s = afterCheck(start, reachable: false);
      expect((s.online, s.failures), (true, 1));
    });

    test('two failed checks in a row mean offline', () {
      final s = afterCheck(afterCheck(start, reachable: false), reachable: false);
      expect((s.online, s.failures), (false, 2));
    });

    test('further failures stay offline and keep counting', () {
      var s = start;
      for (var i = 0; i < 5; i++) {
        s = afterCheck(s, reachable: false);
      }
      expect((s.online, s.failures), (false, 5));
    });

    test('one success is online at once and forgets the failures', () {
      final off = afterCheck(afterCheck(start, reachable: false), reachable: false);
      final s = afterCheck(off, reachable: true);
      expect((s.online, s.failures), (true, 0));
    });

    test('a success between two failures keeps the person online (they are not in a row)', () {
      var s = afterCheck(start, reachable: false);
      s = afterCheck(s, reachable: true);
      s = afterCheck(s, reachable: false);
      expect((s.online, s.failures), (true, 1));
    });

    test('the threshold is two', () {
      expect(failuresBeforeOffline, 2);
    });
  });

  group('the monitor', () {
    test('starts online and says nothing before the first check', () {
      final m = ConnectionMonitor(() async => true, autoStart: false);
      expect(m.state.online, isTrue);
      m.dispose();
    });

    test('a check that cannot reach the server counts as a failure; two make it offline', () async {
      final m = ConnectionMonitor(() async => false, autoStart: false);
      await m.check();
      expect(m.state.online, isTrue);
      await m.check();
      expect(m.state.online, isFalse);
      m.dispose();
    });

    test('a probe that throws is a failure, never a crash', () async {
      final m = ConnectionMonitor(() async => throw Exception('socket'), autoStart: false);
      await m.check();
      await m.check();
      expect(m.state.online, isFalse);
      m.dispose();
    });

    test('coming back is noticed by the next check', () async {
      var up = false;
      final m = ConnectionMonitor(() async => up, autoStart: false);
      await m.check();
      await m.check();
      expect(m.state.online, isFalse);
      up = true;
      await m.check();
      expect(m.state.online, isTrue);
      m.dispose();
    });

    test('a second check while one is running is ignored', () async {
      final gate = Completer<bool>();
      var calls = 0;
      final m = ConnectionMonitor(() {
        calls++;
        return gate.future;
      }, autoStart: false);
      final first = m.check();
      await m.check();
      expect(calls, 1);
      expect(m.state.checking, isTrue);
      gate.complete(true);
      await first;
      expect(m.state.checking, isFalse);
      m.dispose();
    });

    test('coming back to the app looks again straight away; going away does not', () async {
      var calls = 0;
      final m = ConnectionMonitor(() async {
        calls++;
        return true;
      }, autoStart: false);
      m.didChangeAppLifecycleState(AppLifecycleState.paused);
      m.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      m.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      m.dispose();
    });

    test('a check that finishes after the monitor is gone changes nothing and does not crash', () async {
      final gate = Completer<bool>();
      final m = ConnectionMonitor(() => gate.future, autoStart: false);
      final running = m.check();
      m.dispose();
      gate.complete(false);
      await running;
    });

    test('with auto start it checks on its own every interval, and stops when disposed', () {
      fakeAsync((async) {
        var calls = 0;
        final m = ConnectionMonitor(() async {
          calls++;
          return false;
        }, every: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 9));
        expect(calls, 0);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(calls, 2);
        expect(m.state.online, isFalse, reason: 'two failures in a row');
        m.dispose();
        async.elapse(const Duration(seconds: 60));
        expect(calls, 2, reason: 'no checks after dispose');
      });
    });

    test('the provider does not start any timer unless it is enabled', () {
      fakeAsync((async) {
        final c = ProviderContainer(overrides: [connectionProbeProvider.overrideWithValue(() async => false)]);
        c.read(connectionMonitorProvider);
        async.elapse(const Duration(minutes: 5));
        expect(c.read(connectionMonitorProvider).online, isTrue, reason: 'never probed');
        c.dispose();
      });
    });
  });

  group('the banner', () {
    Widget host(ConnectionMonitor monitor) => ProviderScope(
          overrides: [connectionMonitorProvider.overrideWith((ref) => monitor)],
          child: const MaterialApp(home: Scaffold(body: Column(children: [ConnectionBanner()]))),
        );

    testWidgets('says nothing while online', (tester) async {
      final m = ConnectionMonitor(() async => true, autoStart: false);
      await tester.pumpWidget(host(m));
      expect(find.byKey(const Key('connection-banner')), findsNothing);
    });

    testWidgets('says plainly that the person is offline, then goes away by itself when the connection is back', (tester) async {
      var up = false;
      final m = ConnectionMonitor(() async => up, autoStart: false);
      await tester.pumpWidget(host(m));
      await m.check();
      await m.check();
      await tester.pump();
      expect(find.text("You're offline. Nothing can be saved until the connection is back."), findsOneWidget);
      up = true;
      await tester.tap(find.byKey(const Key('connection-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('connection-banner')), findsNothing);
    });

    testWidgets('Try again checks right now, and the button waits while it checks', (tester) async {
      final gate = Completer<bool>();
      var calls = 0;
      final m = ConnectionMonitor(() {
        calls++;
        return calls <= 2 ? Future.value(false) : gate.future;
      }, autoStart: false);
      await tester.pumpWidget(host(m));
      await m.check();
      await m.check();
      await tester.pump();
      await tester.tap(find.byKey(const Key('connection-retry')));
      await tester.pump();
      expect(find.text('Checking…'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('connection-retry'))).onPressed, isNull);
      expect(calls, 3);
      gate.complete(false);
      await tester.pump();
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
