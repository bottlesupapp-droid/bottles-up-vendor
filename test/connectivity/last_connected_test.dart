import 'package:bottles_up_vendor/core/connectivity/connection_banner.dart';
import 'package:bottles_up_vendor/core/connectivity/connection_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// "Show last sync time and pending actions" (brief section 2). While the phone cannot reach the server the banner says when it last could, and that nothing is waiting to be sent: the app
// holds no action back, so nothing is ever confirmed without the server (brief: "Do not mark an offline payment, admission, or booking as confirmed without the required server confirmation").

void main() {
  group('the last time the server was reached', () {
    final t1 = DateTime(2026, 10, 9, 21, 40);
    final t2 = DateTime(2026, 10, 9, 21, 55);

    test('a success notes the time; a failure keeps the last one', () {
      var s = afterCheck(const NetworkStatus(online: true), reachable: true, at: t1);
      expect(s.lastReachedAt, t1);
      s = afterCheck(s, reachable: false, at: t2);
      expect(s.lastReachedAt, t1, reason: 'a failed check does not move it');
      s = afterCheck(s, reachable: false);
      expect((s.online, s.lastReachedAt), (false, t1));
      s = afterCheck(s, reachable: true, at: t2);
      expect((s.online, s.lastReachedAt), (true, t2));
    });

    test('it is unknown until a check has succeeded', () {
      final s = afterCheck(afterCheck(const NetworkStatus(online: true), reachable: false), reachable: false);
      expect(s.lastReachedAt, isNull);
    });

    test('the monitor notes the time of each successful check, from its clock', () async {
      var now = t1;
      var reach = true;
      final m = ConnectionMonitor(() async => reach, autoStart: false, clock: () => now);
      await m.check();
      expect(m.state.lastReachedAt, t1);
      now = t2;
      reach = false;
      await m.check();
      await m.check();
      expect((m.state.online, m.state.lastReachedAt), (false, t1));
      m.dispose();
    });
  });

  group('the words', () {
    test('today it is the time; another day it is the day and the time; never reached says so', () {
      final now = DateTime(2026, 10, 9, 22);
      expect(lastConnectedLine(DateTime(2026, 10, 9, 21, 40), now), 'Last connected at 21:40');
      expect(lastConnectedLine(DateTime(2026, 10, 8, 23, 5), now), 'Last connected Oct 8, 23:05');
      expect(lastConnectedLine(DateTime(2025, 10, 9, 21, 40), now), 'Last connected Oct 9, 21:40', reason: 'the same date a year ago is not today');
      expect(lastConnectedLine(DateTime(2026, 9, 9, 21, 40), now), 'Last connected Sep 9, 21:40', reason: 'the same day of another month is not today');
      expect(lastConnectedLine(DateTime(2026, 10, 8, 21, 40), now), 'Last connected Oct 8, 21:40', reason: 'the day before is not today');
      expect(lastConnectedLine(null, now), 'Not connected since the app was opened');
    });

    test('nothing is waiting to be sent, because the app holds nothing back', () {
      expect(nothingWaitingLine, 'Nothing is waiting to be sent');
    });
  });

  group('in the banner', () {
    Future<void> show(WidgetTester tester, NetworkStatus status, DateTime now) async {
      await tester.pumpWidget(
        ProviderScope(overrides: [connectionMonitorProvider.overrideWith((ref) => _Fixed(status))], child: MaterialApp(home: Scaffold(body: ConnectionBanner(clock: () => now)))),
      );
      await tester.pump();
    }

    testWidgets('offline: the message, when it last connected, and that nothing is waiting', (tester) async {
      await show(tester, NetworkStatus(online: false, failures: 2, lastReachedAt: DateTime(2026, 10, 9, 21, 40)), DateTime(2026, 10, 9, 22));
      expect(find.byKey(const Key('connection-banner-text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('connection-banner-sync'))).data, 'Last connected at 21:40 · Nothing is waiting to be sent');
    });

    testWidgets('offline from the start: it says it has not connected since the app was opened', (tester) async {
      await show(tester, const NetworkStatus(online: false, failures: 2), DateTime(2026, 10, 9, 22));
      expect(tester.widget<Text>(find.byKey(const Key('connection-banner-sync'))).data, 'Not connected since the app was opened · Nothing is waiting to be sent');
    });

    testWidgets('online: nothing is shown at all', (tester) async {
      await show(tester, NetworkStatus(online: true, lastReachedAt: DateTime(2026, 10, 9, 21, 40)), DateTime(2026, 10, 9, 22));
      expect(find.byKey(const Key('connection-banner')), findsNothing);
      expect(find.byKey(const Key('connection-banner-sync')), findsNothing);
    });
  });
}

class _Fixed extends ConnectionMonitor {
  _Fixed(NetworkStatus status) : super(() async => true, autoStart: false) {
    state = status;
  }
}
