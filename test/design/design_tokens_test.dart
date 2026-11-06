import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The values in BuTokens are the Figma design's own (read from the prototype's stylesheet), so they are pinned here one by one: a colour that drifts
// is a change to the brand, and should be a decision, not an accident.
void main() {
  group('the dark tokens are the design\'s', () {
    const t = BuTokens.dark;

    test('surfaces', () {
      expect(t.bg, const Color(0xFF090909));
      expect(t.panel, const Color(0xFF151514));
      expect(t.panel2, const Color(0xFF1C1B1A));
      expect(t.raised, const Color(0xFF2A2826));
      expect(t.line, const Color(0xFF292826));
    });

    test('text', () {
      expect(t.ink, const Color(0xFFF5F4F1));
      expect(t.soft, const Color(0xFFC8C6C1));
      expect(t.muted, const Color(0xFF999894));
    });

    test('the one orange, its lighter twin, and its 12% wash', () {
      expect(t.orange, const Color(0xFFFF5A2F));
      expect(t.orangeSoft, const Color(0xFFFF7A45));
      expect(t.orangeWash, const Color(0x1FFF5A2F));
    });

    test('status colours', () {
      expect(t.green, const Color(0xFF59D7A2));
      expect(t.amber, const Color(0xFFFFB258));
    });

    test('the text on every surface is readable: at least 4.5 : 1 (WCAG AA) for ink, soft and muted on the panel and the page', () {
      double luminance(Color c) => c.computeLuminance();
      double contrast(Color a, Color b) {
        final l1 = luminance(a), l2 = luminance(b);
        final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final surface in [t.bg, t.panel, t.panel2]) {
        for (final text in [t.ink, t.soft, t.muted]) {
          expect(contrast(text, surface), greaterThanOrEqualTo(4.5), reason: '$text on $surface');
        }
      }
      // Orange text (links, selected tab) on the page and on a card.
      expect(contrast(t.orangeSoft, t.bg), greaterThanOrEqualTo(4.5));
      expect(contrast(t.orangeSoft, t.panel), greaterThanOrEqualTo(4.5));
      // White on the orange of a primary button.
      expect(contrast(Colors.white, t.orange), greaterThanOrEqualTo(3.0), reason: 'large button text, WCAG AA for large text');
    });
  });

  group('radii and spacing', () {
    test('the design\'s corners', () {
      expect(BuRadius.card, 20);
      expect(BuRadius.hero, 24);
      expect(BuRadius.control, 14);
      expect(BuRadius.tile, 12);
      expect(BuRadius.bar, 24);
      expect(BuRadius.sheet, 28);
    });

    test('a 4-point grid with a 20-point page margin', () {
      expect(BuSpace.page, 20);
      for (final step in [BuSpace.xs, BuSpace.s, BuSpace.m, BuSpace.l, BuSpace.xl, BuSpace.xxl]) {
        expect(step % 4, 0);
      }
    });
  });

  group('BuTokens as a theme extension', () {
    test('copyWith changes only what it is told to', () {
      final changed = BuTokens.dark.copyWith(orange: Colors.blue);
      expect(changed.orange, Colors.blue);
      expect(changed.bg, BuTokens.dark.bg);
      expect(changed.green, BuTokens.dark.green);
    });

    test('lerp meets both ends, and ignores something that is not tokens', () {
      final other = BuTokens.dark.copyWith(bg: Colors.white);
      expect(BuTokens.dark.lerp(other, 0).bg, BuTokens.dark.bg);
      expect(BuTokens.dark.lerp(other, 1).bg, Colors.white);
      expect(BuTokens.dark.lerp(null, 0.5), same(BuTokens.dark));
    });
  });

  group('context.bu', () {
    testWidgets('answers with the dark tokens under a plain ThemeData, so a widget needs no setup in a test', (tester) async {
      late BuTokens seen;
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Builder(builder: (context) {
        seen = context.bu;
        return const SizedBox();
      })));
      expect(seen, same(BuTokens.dark));
    });

    testWidgets('answers with the registered tokens under the app\'s theme', (tester) async {
      late BuTokens seen;
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Builder(builder: (context) {
        seen = context.bu;
        return const SizedBox();
      })));
      expect(seen.orange, BuTokens.dark.orange);
      expect(Theme.of(tester.element(find.byType(SizedBox))).extension<BuTokens>(), isNotNull);
    });
  });
}
