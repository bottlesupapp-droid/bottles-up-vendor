import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/features/analytics/providers/analytics_provider.dart';
import 'package:bottles_up_vendor/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:bottles_up_vendor/shared/models/analytics_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The Booking Trends line on Reports was a made-up rising line. It is now the account's real bookings of the last seven days, a day with none counted as 0.
void main() {
  group('bookingsPerDay', () {
    final now = DateTime(2026, 11, 15, 19, 30);
    BookingTrend t(int day, int bookings, {int month = 11}) => BookingTrend(date: DateTime(2026, month, day), bookings: bookings, revenue: 0);

    test('always seven days, oldest first, ending today', () {
      final days = bookingsPerDay(const [], now);
      expect(days.length, 7);
      expect(days.first.$1, DateTime(2026, 11, 9));
      expect(days.last.$1, DateTime(2026, 11, 15));
      expect(days.every((d) => d.$2 == 0), isTrue, reason: 'no bookings: all zero, nothing invented');
    });

    test('each booking lands on its own day; days with none are 0', () {
      final days = bookingsPerDay([t(15, 3), t(12, 1), t(9, 2)], now);
      expect(days.map((d) => d.$2).toList(), [2, 0, 0, 1, 0, 0, 3]);
    });

    test('bookings older than the seven days are left out', () {
      final days = bookingsPerDay([t(8, 9), t(31, 9, month: 10)], now);
      expect(days.fold<int>(0, (s, d) => s + d.$2), 0);
    });

    test('it crosses a month end correctly', () {
      final days = bookingsPerDay([t(30, 4, month: 10), t(2, 1)], DateTime(2026, 11, 3));
      expect(days.first.$1, DateTime(2026, 10, 28));
      expect(days.map((d) => d.$2).toList(), [0, 0, 4, 0, 0, 1, 0]);
    });

    test('the same day counted twice is added up', () {
      expect(bookingsPerDay([t(15, 2), t(15, 3)], now).last.$2, 5);
    });
  });

  group('Booking Trends card', () {
    OrganizerAnalytics data(List<BookingTrend> trends) => OrganizerAnalytics(totalBookings: trends.fold(0, (s, x) => s + x.bookings), bookingTrends: trends);

    Future<void> open(WidgetTester tester, OrganizerAnalytics d) async {
      tester.view.physicalSize = const Size(393 * 2, 2400 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizerAnalyticsProvider.overrideWith((ref) async => d),
            revenueBreakdownProvider.overrideWith((ref) async => throw Exception('x')),
            eventPerformanceInsightsProvider.overrideWith((ref) async => throw Exception('x')),
          ],
          child: MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: AnalyticsDashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('with no bookings in the week it says so, and never shows a rising line of made-up numbers', (tester) async {
      await open(tester, data(const []));
      expect(find.byKey(const Key('report-trend')), findsOneWidget);
      expect(find.text('No bookings in the last 7 days.'), findsOneWidget);
    });

    testWidgets('with bookings it says how many in the week', (tester) async {
      final now = DateTime.now();
      await open(
        tester,
        data([BookingTrend(date: DateTime(now.year, now.month, now.day), bookings: 3, revenue: 90), BookingTrend(date: DateTime(now.year, now.month, now.day - 2), bookings: 1, revenue: 30)]),
      );
      expect(find.text('4 bookings in the last 7 days.'), findsOneWidget);
    });
  });
}
