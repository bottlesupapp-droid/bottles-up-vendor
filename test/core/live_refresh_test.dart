import 'dart:async';

import 'package:bottles_up_vendor/core/live/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A screen that looks again by itself, says when it last did, and says so plainly when a look fails. Every case here is something the floor would notice: a stale list that looks current, a phone
// that keeps polling in a pocket, a screen under another page that keeps asking, two looks running over each other.
int loads = 0;
bool failNext = false;
Completer<int>? hold;
DateTime now = DateTime(2026, 11, 2, 19, 15, 4);

final dataProvider = FutureProvider.autoDispose<int>((ref) async {
  loads++;
  if (hold != null) return hold!.future;
  if (failNext) throw Exception('network down');
  return loads;
});

Future<void> show(WidgetTester tester, {bool enabled = true, Duration every = const Duration(seconds: 20), Widget? over}) async {
  loads = 0;
  failNext = false;
  hold = null;
  now = DateTime(2026, 11, 2, 19, 15, 4);
  await tester.pumpWidget(ProviderScope(
    overrides: [liveRefreshEnabledProvider.overrideWithValue(enabled), liveRefreshIntervalProvider.overrideWithValue(every)],
    child: MaterialApp(
      home: Scaffold(
        body: LiveRefresh(
          clock: () => now,
          refresh: (ref) => ref.invalidate(dataProvider),
          watching: [dataProvider],
          child: Consumer(builder: (context, ref, _) => Text('value ${ref.watch(dataProvider).valueOrNull}')),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

String status(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('live-status'))).data!;

void main() {
  group('the status line', () {
    test('words', () {
      expect(liveStatusText(updated: null, failed: false), 'Updating…');
      expect(liveStatusText(updated: DateTime(2026, 11, 2, 19, 15, 4), failed: false), 'Updated 7:15:04 PM');
      expect(liveStatusText(updated: null, failed: true), "Couldn't refresh. Trying again.");
      expect(liveStatusText(updated: DateTime(2026, 11, 2, 9, 5, 0), failed: true), "Couldn't refresh. Showing what was current at 9:05:00 AM.");
    });

    testWidgets('says when the data arrived', (tester) async {
      await show(tester);
      expect(status(tester), 'Updated 7:15:04 PM');
      expect(find.text('value 1'), findsOneWidget);
    });
  });

  group('looking again', () {
    testWidgets('with the setting off (tests, previews) it never looks and starts no timer', (tester) async {
      await show(tester, enabled: false);
      await tester.pump(const Duration(minutes: 10));
      expect(loads, 1);
    });

    testWidgets('every interval, and the line moves to the new time', (tester) async {
      await show(tester);
      now = DateTime(2026, 11, 2, 19, 15, 24);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      await tester.pump();
      expect(loads, 2);
      expect(find.text('value 2'), findsOneWidget);
      expect(status(tester), 'Updated 7:15:24 PM');
      now = DateTime(2026, 11, 2, 19, 15, 44);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      await tester.pump();
      expect(loads, 3);
      expect(status(tester), 'Updated 7:15:44 PM');
    });

    testWidgets('it does not look before the interval is up', (tester) async {
      await show(tester);
      await tester.pump(const Duration(seconds: 19));
      expect(loads, 1);
    });

    testWidgets('a look that fails keeps what was shown, says so in words, and keeps the time of the last good look', (tester) async {
      await show(tester);
      failNext = true;
      now = DateTime(2026, 11, 2, 19, 15, 24);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      await tester.pump();
      expect(status(tester), "Couldn't refresh. Showing what was current at 7:15:04 PM.");
      final text = tester.widget<Text>(find.byKey(const Key('live-status')));
      expect(text.style?.color, Theme.of(tester.element(find.byKey(const Key('live-status')))).colorScheme.error);
      // and when the network is back, it says it is current again
      failNext = false;
      now = DateTime(2026, 11, 2, 19, 15, 44);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      await tester.pump();
      expect(status(tester), 'Updated 7:15:44 PM');
    });

    testWidgets('two looks never run over each other: a slow one is waited for', (tester) async {
      await show(tester);
      hold = Completer<int>();
      await tester.pump(const Duration(seconds: 20)); // starts a look that does not finish
      await tester.pump();
      expect(loads, 2);
      await tester.pump(const Duration(seconds: 60)); // three more ticks while it is still running
      expect(loads, 2, reason: 'a second look started while the first was still running');
      hold!.complete(99);
      await tester.pump();
      await tester.pump();
      expect(find.text('value 99'), findsOneWidget);
    });

    testWidgets('Refresh now looks once, straight away', (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const Key('live-refresh')));
      await tester.pump();
      await tester.pump();
      expect(loads, 2);
    });
  });

  group('when it must not look', () {
    testWidgets('while the app is in the background; it looks as soon as it is back', (tester) async {
      await show(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      expect(loads, 1, reason: 'a phone in a pocket kept asking');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(loads, 2, reason: 'back in front it should look at once');
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(loads, 3, reason: 'and carry on every interval');
    });

    testWidgets('while another page is open on top of it', (tester) async {
      await show(tester);
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('page on top')))));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 5));
      expect(loads, 1, reason: 'a screen under another page kept asking');
    });

    testWidgets('after the screen is gone', (tester) async {
      await show(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      expect(loads, 1);
    });
  });
}
