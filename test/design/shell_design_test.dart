import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/core/ui/glass_kit.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/widgets/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

const _owner = Workspace(membershipId: 'm1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
final _door = Workspace(
  membershipId: 'm2', orgId: 'p', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.door, eventId: 'e1', eventTitle: 'Promoter Night',
  accessEndAt: DateTime.utc(2026, 11, 8, 4),
);

const _items = [
  GlassNavItem(icon: Ionicons.home_outline, activeIcon: Ionicons.home, label: 'Overview'),
  GlassNavItem(icon: Ionicons.business_outline, activeIcon: Ionicons.business, label: 'Venues'),
  GlassNavItem(icon: Ionicons.moon_outline, activeIcon: Ionicons.moon, label: 'Tonight'),
  GlassNavItem(icon: Ionicons.document_text_outline, activeIcon: Ionicons.document_text, label: 'Reports'),
  GlassNavItem(icon: Ionicons.menu_outline, activeIcon: Ionicons.menu, label: 'More'),
];

Future<void> phone(WidgetTester tester, Widget child, {Size size = const Size(393, 852)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child))));
  await tester.pump();
}

void main() {
  group('the top bar says who and where you are', () {
    Widget bar(Workspace w, {bool canSwitch = true, VoidCallback? onSwitch}) => Align(
          alignment: Alignment.topCenter,
          child: WorkspaceContextBar(workspace: w, canSwitch: canSwitch, onSwitch: onSwitch ?? () {}, onSignOut: () {}),
        );

    testWidgets('has the brand mark, then role and organisation, then the venue', (tester) async {
      await phone(tester, bar(_owner));
      expect(find.byKey(const Key('workspace-context-bar')), findsOneWidget);
      expect(find.byType(BuLogoMark), findsOneWidget);
      expect(find.text('Owner · Club Co'), findsOneWidget);
      expect(find.text('All venues'), findsOneWidget);
    });

    testWidgets('a time-limited shift says when access ends', (tester) async {
      await phone(tester, bar(_door));
      expect(find.text('Door staff · Night Events'), findsOneWidget);
      expect(find.textContaining('access until'), findsOneWidget);
    });

    testWidgets('the switch button appears only when there is something to switch to, and works', (tester) async {
      var switched = 0;
      await phone(tester, bar(_owner, onSwitch: () => switched++));
      await tester.tap(find.byKey(const Key('switch-workspace')));
      expect(switched, 1);

      await phone(tester, bar(_owner, canSwitch: false));
      expect(find.byKey(const Key('switch-workspace')), findsNothing);
      expect(find.byKey(const Key('account-menu')), findsOneWidget, reason: 'everyone can sign out');
    });

    testWidgets('both buttons on the bar are at least 44 points: easy to hit with a thumb', (tester) async {
      await phone(tester, bar(_owner));
      expect(tester.getSize(find.byKey(const Key('switch-workspace'))).shortestSide, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byKey(const Key('account-menu'))).shortestSide, greaterThanOrEqualTo(44));
    });

    testWidgets('a very long organisation name is cut with an ellipsis, not allowed to push the buttons off the screen', (tester) async {
      final long = Workspace(membershipId: 'm3', orgId: 'o', orgName: 'The Extraordinarily Long Hospitality Group Of Toronto Limited', orgKind: 'venue_owner', role: WorkspaceRole.owner);
      await phone(tester, bar(long));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('account-menu'))).right, lessThanOrEqualTo(393));
      expect(tester.widget<Text>(find.textContaining('Extraordinarily')).overflow, TextOverflow.ellipsis);
    });

    testWidgets('the account menu still offers Sign out', (tester) async {
      await phone(tester, bar(_owner));
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-sign-out')), findsOneWidget);
    });
  });

  group('the floating bottom bar', () {
    testWidgets('shows one tab per section with its label', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: _items));
      for (final item in _items) {
        expect(find.text(item.label), findsOneWidget);
      }
    });

    testWidgets('the current tab shows its filled icon and the others their outline', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 2, onTap: (_) {}, items: _items));
      expect(find.byIcon(Ionicons.moon), findsOneWidget);
      expect(find.byIcon(Ionicons.moon_outline), findsNothing);
      expect(find.byIcon(Ionicons.home_outline), findsOneWidget);
      expect(find.byIcon(Ionicons.home), findsNothing);
    });

    testWidgets('the current tab is orange and the others grey', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 1, onTap: (_) {}, items: _items));
      expect(tester.widget<Icon>(find.byIcon(Ionicons.business)).color, BuTokens.dark.orangeSoft);
      expect(tester.widget<Icon>(find.byIcon(Ionicons.home_outline)).color, isNot(BuTokens.dark.orangeSoft));
    });

    testWidgets('a tap reports the index of the tab', (tester) async {
      final taps = <int>[];
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: taps.add, items: _items));
      await tester.tap(find.text('Reports'));
      await tester.tap(find.text('Overview'));
      await tester.tap(find.byIcon(Ionicons.menu_outline));
      expect(taps, [3, 0, 4]);
    });

    testWidgets('a screen reader hears each tab as a button, and which one is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await phone(tester, GlassBottomNavBar(currentIndex: 1, onTap: (_) {}, items: _items));
      expect(tester.getSemantics(find.text('Venues')), matchesSemantics(label: 'Venues', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true, isFocusable: false));
      expect(tester.getSemantics(find.text('Reports')), matchesSemantics(label: 'Reports', isButton: true, hasSelectedState: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('is 76 points of pill above the home indicator, and the whole widget runs to the bottom of the screen', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: _items));
      final box = tester.getRect(find.byType(GlassBottomNavBar));
      expect(box.bottom, closeTo(852, 0.5));
      final pill = tester.getRect(find.descendant(of: find.byType(GlassBottomNavBar), matching: find.byType(BackdropFilter)));
      expect(pill.height, 76);
      expect(852 - pill.bottom, 34 + 12, reason: 'the home-indicator strip plus the 12-point gap of the design');
    });

    testWidgets('on a wide screen the pill stays 570 points wide and centred instead of stretching edge to edge', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: _items), size: const Size(1024, 768));
      final pill = tester.getRect(find.descendant(of: find.byType(GlassBottomNavBar), matching: find.byType(BackdropFilter)));
      expect(pill.width, 570);
      expect(pill.center.dx, closeTo(512, 0.5));
    });

    testWidgets('its labels use the theme\'s font, not whatever the phone defaults to', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: _items));
      expect(tester.widget<Text>(find.text('Venues')).style?.fontFamily ?? DefaultTextStyle.of(tester.element(find.text('Venues'))).style.fontFamily, 'Inter');
    });

    testWidgets('four tabs (a role with four sections) share the width evenly', (tester) async {
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: _items.take(4).toList()));
      final widths = [for (final i in _items.take(4)) tester.getSize(find.ancestor(of: find.text(i.label), matching: find.byType(AnimatedContainer)).first).width];
      expect(widths.toSet().length, 1);
    });

    testWidgets('a long label is cut with an ellipsis instead of overflowing its tab', (tester) async {
      final items = [..._items.take(4), const GlassNavItem(icon: Ionicons.menu_outline, activeIcon: Ionicons.menu, label: 'A very long section name')];
      await phone(tester, GlassBottomNavBar(currentIndex: 0, onTap: (_) {}, items: items));
      expect(tester.takeException(), isNull);
    });
  });
}
