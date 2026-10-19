import 'package:bottles_up_vendor/features/analytics/providers/analytics_provider.dart';
import 'package:bottles_up_vendor/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Brief 15 Oct, section 33: a failed analytics request says so in plain words with Retry; it never prints the database's own text
/// ("Could not find a relationship between ...") and is never shown as zero revenue.
const _technical = 'PostgrestException(message: Could not find a relationship between \'inquiries\' and \'events\' in the schema cache, code: PGRST200)';

var asked = 0;

Widget host() => ProviderScope(
      overrides: [
        organizerAnalyticsProvider.overrideWith((ref) async {
          asked++;
          throw Exception(_technical);
        }),
        revenueBreakdownProvider.overrideWith((ref) async => throw Exception(_technical)),
        eventPerformanceInsightsProvider.overrideWith((ref) async => throw Exception(_technical)),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const AnalyticsDashboardScreen()),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => asked = 0);

  for (final tab in ['Overview', 'Revenue', 'Events', 'Inquiries']) {
    testWidgets('$tab: a failed request is plain, has Retry, and shows no technical text and no zero figures', (tester) async {
      await open(tester);
      if (tab != 'Overview') await openTab(tester, tab);
      expect(find.byKey(const Key('analytics-error')), findsOneWidget);
      expect(find.textContaining('We could not load'), findsOneWidget);
      expect(find.textContaining('relationship'), findsNothing);
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.textContaining('PGRST'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('\$0'), findsNothing, reason: 'a failure is not zero revenue');
    });
  }

  testWidgets('Retry asks again', (tester) async {
    await open(tester);
    final before = asked;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(asked, greaterThan(before));
  });
}
