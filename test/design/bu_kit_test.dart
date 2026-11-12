import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

Future<void> show(WidgetTester tester, Widget child, {Size size = const Size(393, 852)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pump();
}

void main() {
  group('BuLogoMark', () {
    testWidgets('is a square of the asked size, and a screen reader says "BottlesUp"', (tester) async {
      await show(tester, const BuLogoMark(size: 38));
      expect(tester.getSize(find.byType(BuLogoMark)), const Size(38, 38));
      expect(find.bySemanticsLabel('BottlesUp'), findsOneWidget);
    });

    testWidgets('draws the app\'s own logo picture', (tester) async {
      await show(tester, const BuLogoMark());
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/launcher_icon.jpeg');
    });

    testWidgets('if the picture cannot be read the tile is still the brand orange', (tester) async {
      await show(tester, const BuLogoMark());
      final image = tester.widget<Image>(find.byType(Image));
      final fallback = image.errorBuilder!(tester.element(find.byType(Image)), Object(), StackTrace.empty);
      expect(((fallback as ColoredBox).color), BuTokens.dark.orange);
    });
  });

  group('BuEyebrow', () {
    testWidgets('is upper case, orange, small and spaced out', (tester) async {
      await show(tester, const BuEyebrow('needs attention'));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'NEEDS ATTENTION');
      expect(text.style?.color, BuTokens.dark.orange);
      expect(text.style?.letterSpacing, greaterThan(1));
      expect(text.style?.fontSize, lessThanOrEqualTo(11));
    });

    testWidgets('can take another colour', (tester) async {
      await show(tester, const BuEyebrow('live', color: Colors.green));
      expect(tester.widget<Text>(find.byType(Text)).style?.color, Colors.green);
    });
  });

  group('BuPageHeader', () {
    testWidgets('shows eyebrow, title and intro, and the title is a header for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const BuPageHeader(eyebrow: 'Assigned access', title: 'Your workspaces', intro: 'Only roles assigned to you appear here.'));
      expect(find.text('ASSIGNED ACCESS'), findsOneWidget);
      expect(find.text('Your workspaces'), findsOneWidget);
      expect(find.text('Only roles assigned to you appear here.'), findsOneWidget);
      expect(tester.getSemantics(find.text('Your workspaces')), matchesSemantics(label: 'Your workspaces', isHeader: true, textDirection: TextDirection.ltr));
      handle.dispose();
    });

    testWidgets('with only a title there is no eyebrow and no intro', (tester) async {
      await show(tester, const BuPageHeader(title: 'More'));
      expect(find.byType(BuEyebrow), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a trailing widget sits at the right of the heading', (tester) async {
      await show(tester, const BuPageHeader(title: 'Tonight', trailing: Text('LIVE', key: Key('live'))));
      expect(tester.getTopRight(find.byKey(const Key('live'))).dx, greaterThan(tester.getTopRight(find.text('Tonight')).dx));
    });

    testWidgets('the title uses the big heading style of the theme', (tester) async {
      await show(tester, const BuPageHeader(title: 'Overview'));
      expect(tester.widget<Text>(find.text('Overview')).style?.fontSize, AppTheme.darkTheme.textTheme.displaySmall?.fontSize);
    });
  });

  group('BuSectionHeader', () {
    testWidgets('shows the title, and an action only when it has one', (tester) async {
      await show(tester, const BuSectionHeader(eyebrow: 'Needs attention', title: 'Stay ahead'));
      expect(find.text('Stay ahead'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('the title is a header for a screen reader, so a person can jump between sections', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const BuSectionHeader(eyebrow: 'Your venues', title: 'Tonight'));
      expect(tester.getSemantics(find.text('Tonight')), matchesSemantics(label: 'Tonight', isHeader: true, textDirection: TextDirection.ltr));
      handle.dispose();
    });

    testWidgets('the action can be pressed', (tester) async {
      var taps = 0;
      await show(tester, BuSectionHeader(title: 'Venues', actionLabel: 'View all', onAction: () => taps++));
      await tester.tap(find.text('View all'));
      expect(taps, 1);
    });

    testWidgets('the action is big enough to press (at least 40 points tall)', (tester) async {
      await show(tester, BuSectionHeader(title: 'Venues', actionLabel: 'View all', onAction: () {}));
      expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(40));
    });
  });

  group('BuCard', () {
    testWidgets('holds its child, and a tap reaches onTap', (tester) async {
      var taps = 0;
      await show(tester, BuCard(onTap: () => taps++, child: const Text('Card body')));
      await tester.tap(find.text('Card body'));
      expect(taps, 1);
    });

    testWidgets('without onTap it is not a button', (tester) async {
      await show(tester, const BuCard(child: Text('Plain')));
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('is the dark panel with the design\'s 20-point corners', (tester) async {
      await show(tester, const BuCard(child: Text('x')));
      final box = tester.widget<Container>(find.descendant(of: find.byType(BuCard), matching: find.byType(Container)).first).decoration as BoxDecoration;
      expect(box.color, BuTokens.dark.panel);
      expect(box.borderRadius, BorderRadius.circular(BuRadius.card));
    });

    testWidgets('highlight gives it an orange edge and a glow instead of a flat fill', (tester) async {
      await show(tester, const BuCard(highlight: true, child: Text('x')));
      final box = tester.widget<Container>(find.descendant(of: find.byType(BuCard), matching: find.byType(Container)).first).decoration as BoxDecoration;
      expect(box.gradient, isNotNull);
      expect(box.color, isNull);
      expect((box.border as Border).top.color.a, greaterThan(0.2));
    });
  });

  group('BuIconTile', () {
    testWidgets('is a rounded orange-wash tile with the icon inside', (tester) async {
      await show(tester, const BuIconTile(icon: Icons.home, size: 46));
      expect(tester.getSize(find.byType(BuIconTile)), const Size(46, 46));
      expect(tester.widget<Icon>(find.byIcon(Icons.home)).color, BuTokens.dark.orangeSoft);
    });
  });

  group('BuListRow', () {
    testWidgets('shows title and subtitle, and a chevron only when it can be tapped', (tester) async {
      await show(tester, const BuListRow(title: 'Team', subtitle: 'Staff and roles'));
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Staff and roles'), findsOneWidget);
      expect(find.byIcon(Ionicons.chevron_forward), findsNothing);
    });

    testWidgets('a tappable row has a chevron and one tap target for the whole row', (tester) async {
      var taps = 0;
      await show(tester, BuListRow(title: 'Team', subtitle: 'Staff and roles', icon: Icons.group, onTap: () => taps++));
      expect(find.byIcon(Ionicons.chevron_forward), findsOneWidget);
      await tester.tap(find.text('Staff and roles'));
      await tester.tap(find.byType(BuIconTile));
      expect(taps, 2);
    });

    testWidgets('showChevron: false hides the chevron even on a tappable row', (tester) async {
      await show(tester, BuListRow(title: 'Team', onTap: () {}, showChevron: false));
      expect(find.byIcon(Ionicons.chevron_forward), findsNothing);
    });

    testWidgets('a trailing widget replaces nothing: it sits before the chevron', (tester) async {
      await show(tester, BuListRow(title: 'Payments', trailing: const BuCountBadge(3), onTap: () {}));
      expect(find.byType(BuCountBadge), findsOneWidget);
    });

    testWidgets('a long subtitle is cut after the line limit instead of growing the row without end', (tester) async {
      await show(tester, BuListRow(title: 'T', subtitle: 'word ' * 200, maxSubtitleLines: 2, onTap: () {}));
      expect(tester.widget<Text>(find.textContaining('word')).maxLines, 2);
    });

    testWidgets('a custom leading widget replaces the icon tile', (tester) async {
      await show(tester, const BuListRow(title: 'Active Lounge', leading: Text('AL', key: Key('initials')), icon: Icons.home));
      expect(find.byKey(const Key('initials')), findsOneWidget);
      expect(find.byType(BuIconTile), findsNothing);
    });

    testWidgets('a row is tall enough to press (at least 56 points)', (tester) async {
      await show(tester, BuListRow(title: 'Team', onTap: () {}));
      expect(tester.getSize(find.byType(BuListRow)).height, greaterThanOrEqualTo(56));
    });
  });

  group('BuStatusPill', () {
    testWidgets('always carries a word, whatever its colour', (tester) async {
      await show(tester, Column(children: [for (final tone in BuTone.values) BuStatusPill('Status', tone: tone)]));
      expect(find.text('Status'), findsNWidgets(BuTone.values.length));
    });

    testWidgets('each tone has its own colour', (tester) async {
      await show(tester, Column(children: [for (final tone in BuTone.values) BuStatusPill('x', tone: tone)]));
      final colors = tester.widgetList<Text>(find.text('x')).map((t) => t.style!.color).toSet();
      expect(colors.length, BuTone.values.length);
    });

    testWidgets('good is green, attention is amber, bad is red', (tester) async {
      await show(tester, const Column(children: [BuStatusPill('Live', tone: BuTone.good), BuStatusPill('Late', tone: BuTone.attention), BuStatusPill('Failed', tone: BuTone.bad)]));
      expect(tester.widget<Text>(find.text('Live')).style?.color, BuTokens.dark.green);
      expect(tester.widget<Text>(find.text('Late')).style?.color, BuTokens.dark.amber);
      expect(tester.widget<Text>(find.text('Failed')).style?.color, BuTokens.dark.red);
    });
  });

  group('BuCountBadge', () {
    testWidgets('shows the number and says it to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const BuCountBadge(12));
      expect(find.text('12'), findsOneWidget);
      expect(find.bySemanticsLabel('12'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('stays a circle for one digit and widens for more', (tester) async {
      await show(tester, const Column(children: [BuCountBadge(3), BuCountBadge(1234)]));
      final one = tester.getSize(find.byType(BuCountBadge).first);
      final many = tester.getSize(find.byType(BuCountBadge).last);
      expect(one.width, one.height);
      expect(many.width, greaterThan(one.width));
    });
  });

  group('BuListCard', () {
    testWidgets('puts a hairline between rows and none before the first or after the last', (tester) async {
      await show(tester, const BuListCard(children: [BuListRow(title: 'A'), BuListRow(title: 'B'), BuListRow(title: 'C')]));
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('one row has no divider at all', (tester) async {
      await show(tester, const BuListCard(children: [BuListRow(title: 'Only')]));
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('BuBackdrop and BuWordmark', () {
    testWidgets('the backdrop shows its child and never takes a tap away from it', (tester) async {
      var taps = 0;
      await show(tester, SizedBox(height: 200, child: BuBackdrop(child: TextButton(onPressed: () => taps++, child: const Text('Tap')))));
      await tester.tap(find.text('Tap'));
      expect(taps, 1);
    });

    testWidgets('the wordmark says BottlesUp and BUSINESS next to the mark', (tester) async {
      await show(tester, const BuWordmark());
      expect(find.text('BottlesUp'), findsOneWidget);
      expect(find.text('BUSINESS'), findsOneWidget);
      expect(find.byType(BuLogoMark), findsOneWidget);
    });
  });
}
