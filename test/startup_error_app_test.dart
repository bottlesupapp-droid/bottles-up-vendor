import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bottles_up_vendor/core/startup/startup_error_app.dart';

void main() {
  group('StartupErrorApp', () {
    testWidgets('tells the user what happened and offers a retry', (tester) async {
      await tester.pumpWidget(StartupErrorApp(onRetry: () async {}));

      expect(find.text("Couldn't start the app"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('does not leak error details to the user', (tester) async {
      await tester.pumpWidget(StartupErrorApp(onRetry: () async {}));

      // Only the two fixed, friendly messages; nothing derived from an exception.
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(texts, [
        "Couldn't start the app",
        'Check your internet connection and try again.',
        'Try again',
      ]);
    });

    testWidgets('Try again calls onRetry, and is disabled while it runs', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(StartupErrorApp(onRetry: () {
        calls++;
        return completer.future;
      }));

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(calls, 1);
      // Spinner replaces the label and the button cannot be tapped again.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

      completer.complete();
      await tester.pump();

      expect(find.text('Try again'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    });

    testWidgets('can be retried again after a retry that does nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(StartupErrorApp(onRetry: () async => calls++));

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(calls, 2);
    });
  });
}
