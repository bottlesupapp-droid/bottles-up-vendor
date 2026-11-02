import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/night/providers/night_providers.dart';
import 'package:bottles_up_vendor/features/night/screens/report_screen.dart';
import 'package:bottles_up_vendor/features/sales_source/logic/sales_source_rules.dart';
import 'package:bottles_up_vendor/features/sales_source/providers/sales_source_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../night/fake_night_backend.dart';
import 'fake_sales_backend.dart';

// The nightly report carries the night's sales by source (brief section 24): "Recorded sales" and "Venue-reported sales", each labelled, never added together, on the screen and in the PDF.
late FakeNightBackend night;
late FakeSalesBackend sales;
late List<Uint8List> shared;

DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      nightServiceProvider.overrideWithValue(night.service),
      salesSourceServiceProvider.overrideWithValue(sales.service),
      shareReportProvider.overrideWithValue((bytes, name) async => shared.add(bytes)),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ReportScreen(venueId: 'v1', venueName: 'Club A', clock: fridayNight))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    night = FakeNightBackend();
    sales = FakeSalesBackend(role: 'owner')..source = 'upload';
    shared = [];
  });

  testWidgets('a club on upload with a checked report shows both blocks, each with what it is, and how to read them', (tester) async {
    sales.seed(night: '2026-10-09', status: 'reviewed', includes: true, gross: 90000, discount: 5000, refund: 1000);
    await open(tester);
    expect(sales.calledWith('night_sales_sources').first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    expect(find.text('Recorded sales'), findsOneWidget);
    expect(find.text('Venue-reported sales'), findsOneWidget);
    expect(find.text('What BottlesUp recorded: table bookings, their bottles and the payments taken.'), findsOneWidget);
    expect(find.text('The club\'s own end-of-night report. It is not live bar sales.'), findsOneWidget);
    expect(find.text('Bar and other, without BottlesUp\'s'), findsOneWidget);
    expect(find.text('\$290.00'), findsOneWidget, reason: '840 less BottlesUp\'s 550');
    expect(find.text('Reading the sales'), findsOneWidget);
    expect(find.text('Closing report upload'), findsOneWidget);
    expect(find.text(sourcesFooter), findsOneWidget);
    expect(find.text('Total'), findsNothing, reason: 'the two are never added');
  });

  testWidgets('the sales come after the rest of the report, and the report itself is unchanged', (tester) async {
    sales.seed(night: '2026-10-09', status: 'reviewed');
    await open(tester);
    expect(tester.getTopLeft(find.byKey(const Key('report-section-0'))).dy, lessThan(tester.getTopLeft(find.text('Recorded sales')).dy));
    expect(find.byKey(const Key('report-title')), findsOneWidget);
    expect(find.textContaining('PRELIMINARY'), findsOneWidget);
  });

  testWidgets('a club on upload that sent nothing for the night says so', (tester) async {
    await open(tester);
    expect(find.text('Recorded sales'), findsOneWidget);
    expect(find.text(noReportYetText), findsOneWidget);
  });

  testWidgets('a club on BottlesUp entries has the recorded block and no venue-reported block', (tester) async {
    sales.source = 'entries';
    await open(tester);
    expect(find.text('Recorded sales'), findsOneWidget);
    expect(find.text('Venue-reported sales'), findsNothing);
    expect(find.text('BottlesUp entries'), findsOneWidget);
  });

  testWidgets('a report that waits for its check says so, and one that is smaller than what BottlesUp recorded says to check it', (tester) async {
    sales.seed(night: '2026-10-09', status: 'submitted', includes: true, gross: 30000, discount: 0, refund: 0);
    await open(tester);
    expect(find.text('Waiting to be checked'), findsOneWidget);
    expect(find.text('Check this report'), findsOneWidget);
    expect(find.text(smallerThanRecordedText), findsOneWidget);
  });

  testWidgets('someone who may not read the sales (security, a server) gets the report as it was', (tester) async {
    sales.role = 'stranger';
    night.role = 'security';
    await open(tester);
    expect(find.text('Recorded sales'), findsNothing);
    expect(find.text('Reading the sales'), findsNothing);
    expect(find.byKey(const Key('report-title')), findsOneWidget);
  });

  testWidgets('an old server that has no sales functions leaves the report as it was', (tester) async {
    sales.missing = true;
    await open(tester);
    expect(find.text('Recorded sales'), findsNothing);
    expect(find.byKey(const Key('report-title')), findsOneWidget);
  });

  testWidgets('the PDF carries the sales too: it is made from the same document, so it is bigger than the one without', (tester) async {
    sales.seed(night: '2026-10-09', status: 'reviewed', includes: true);
    await open(tester);
    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    sales.role = 'stranger';
    await open(tester);
    await tester.tap(find.byKey(const Key('report-share')));
    await tester.pumpAndSettle();
    expect(shared, hasLength(2));
    expect(shared[0].length, greaterThan(shared[1].length), reason: 'with the sales sections the PDF has more in it');
  });

  testWidgets('pulling to refresh asks for the sales again', (tester) async {
    sales.seed(night: '2026-10-09', status: 'reviewed');
    await open(tester);
    final before = sales.calledWith('night_sales_sources').length;
    // The same thing a pull does (a pull needs a quarter of this tall test screen's height): ask the refresh indicator to run.
    unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
    await tester.pumpAndSettle();
    expect(sales.calledWith('night_sales_sources').length, greaterThan(before));
  });
}
