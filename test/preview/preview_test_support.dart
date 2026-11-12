import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/ui/glass_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared by the sample-screen tests: a tall phone showing a screen with the app's real theme, and taps that let the page transitions finish.
Future<void> show(WidgetTester tester, Widget screen, {double height = 4200}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: screen));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapText(WidgetTester tester, String text, {bool last = false}) async {
  final f = find.text(text);
  await tester.ensureVisible(last ? f.last : f.first);
  await tester.tap(last ? f.last : f.first);
  await tester.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String label) async {
  final f = find.descendant(of: find.byType(GlassBottomNavBar), matching: find.text(label));
  await tester.tap(f);
  await tester.pumpAndSettle();
}

