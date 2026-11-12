import 'dart:io';
import 'dart:ui' as ui;

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _bu = BuTokens.dark;

Future<void> show(WidgetTester tester, Widget child, {Size size = const Size(393, 852)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pump();
}

Color _textColor(WidgetTester tester, Finder f) => tester.widget<Text>(f).style!.color!;

/// The colour of one pixel of what [key] draws, read back from the picture itself.
Future<Color> _pixel(WidgetTester tester, GlobalKey key, Offset at) async {
  final color = await tester.runAsync(() async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (at.dy.round() * image.width + at.dx.round()) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  });
  return color!;
}

bool _isTheFill(Color c) => (c.r - _bu.orangeSoft.r).abs() < 0.02 && (c.g - _bu.orangeSoft.g).abs() < 0.02 && (c.b - _bu.orangeSoft.b).abs() < 0.02;

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  group('BuCountBadge tones', () {
    testWidgets('the number takes the colour of what it means, and a plain count stays grey', (tester) async {
      await show(tester, const Column(children: [
        BuCountBadge(1, key: Key('brand')),
        BuCountBadge(2, key: Key('attention'), tone: BuTone.attention),
        BuCountBadge(3, key: Key('good'), tone: BuTone.good),
        BuCountBadge(4, key: Key('bad'), tone: BuTone.bad),
        BuCountBadge(5, key: Key('neutral'), tone: BuTone.neutral),
      ]));
      expect(_textColor(tester, find.text('1')), _bu.orangeSoft);
      expect(_textColor(tester, find.text('2')), _bu.amber);
      expect(_textColor(tester, find.text('3')), _bu.green);
      expect(_textColor(tester, find.text('4')), _bu.red);
      expect(_textColor(tester, find.text('5')), _bu.muted);
    });

    testWidgets('a coloured count sits on a faint wash of its own colour; a plain one on a neutral panel', (tester) async {
      await show(tester, const Column(children: [BuCountBadge(2, tone: BuTone.attention), BuCountBadge(5, tone: BuTone.neutral)]));
      BoxDecoration behind(String text) =>
          tester.widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(behind('2').color, _bu.amber.withValues(alpha: 0.13));
      expect(behind('5').color, _bu.panel2);
    });

    testWidgets('says its number to a screen reader, once', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const BuCountBadge(7, tone: BuTone.attention));
      expect(find.bySemanticsLabel('7'), findsOneWidget);
      handle.dispose();
    });
  });

  group('BuRing', () {
    final key = GlobalKey();
    // A 100 point ring with an 8 point stroke: the middle of the stroke is 46 points from the centre.
    Future<void> ring(WidgetTester tester, double value) => show(
          tester,
          Center(
            child: RepaintBoundary(key: key, child: Container(color: _bu.bg, child: BuRing(value: value, center: '50%', caption: 'arrived', size: 100))),
          ),
        );
    const threeOClock = Offset(96, 50), sixOClock = Offset(50, 96), nineOClock = Offset(4, 50), twelveOClock = Offset(50, 4);

    testWidgets('fills clockwise from the top, as far as the value says', (tester) async {
      await ring(tester, 0.6);
      expect(_isTheFill(await _pixel(tester, key, threeOClock)), isTrue, reason: '3 o\'clock is inside the first 60%');
      expect(_isTheFill(await _pixel(tester, key, sixOClock)), isTrue, reason: '6 o\'clock is inside the first 60%');
      expect(_isTheFill(await _pixel(tester, key, nineOClock)), isFalse, reason: '9 o\'clock is past 60%');
    });

    testWidgets('a quarter stops at three o\'clock, and the rest of the ring is only the faint track', (tester) async {
      await ring(tester, 0.3);
      expect(_isTheFill(await _pixel(tester, key, threeOClock)), isTrue);
      expect(_isTheFill(await _pixel(tester, key, sixOClock)), isFalse);
      final track = await _pixel(tester, key, nineOClock);
      expect(track, isNot(_bu.bg), reason: 'the track is drawn, not left empty');
      expect(track.a, 1.0);
    });

    testWidgets('zero draws no fill at all, not even a dot at the top', (tester) async {
      await ring(tester, 0);
      for (final at in [twelveOClock, threeOClock, sixOClock, nineOClock]) {
        expect(_isTheFill(await _pixel(tester, key, at)), isFalse, reason: '$at');
      }
    });

    testWidgets('a full ring is filled all the way round', (tester) async {
      await ring(tester, 1);
      for (final at in [twelveOClock, threeOClock, sixOClock, nineOClock]) {
        expect(_isTheFill(await _pixel(tester, key, at)), isTrue, reason: '$at');
      }
    });

    testWidgets('a value past the ends is held to them: more than 1 is a full ring, less than 0 is an empty one', (tester) async {
      await ring(tester, 4);
      expect(_isTheFill(await _pixel(tester, key, nineOClock)), isTrue);
      await ring(tester, -0.5);
      expect(_isTheFill(await _pixel(tester, key, nineOClock)), isFalse);
      expect(_isTheFill(await _pixel(tester, key, threeOClock)), isFalse);
    });

    testWidgets('shows its big word and its small one, and a screen reader hears them together once', (tester) async {
      final handle = tester.ensureSemantics();
      await ring(tester, 0.5);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('arrived'), findsOneWidget);
      expect(find.bySemanticsLabel('50% arrived'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without a small word it is only the big one', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const BuRing(value: 0.2, center: '2 of 10'));
      expect(find.bySemanticsLabel('2 of 10'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('is the size it is asked to be', (tester) async {
      await show(tester, const Center(child: BuRing(value: 0.5, center: '1', size: 120)));
      expect(tester.getSize(find.byType(BuRing)), const Size(120, 120));
    });
  });

  group('BuHeroCard', () {
    testWidgets('shows the eyebrow (in capitals), the headline, the line under it and what is at the right', (tester) async {
      await show(tester, const BuHeroCard(eyebrow: 'Tonight', title: '12 guests expected', subtitle: '2 of 4 bookings have arrived', trailing: Text('RIGHT')));
      expect(find.text('TONIGHT'), findsOneWidget);
      expect(find.text('12 guests expected'), findsOneWidget);
      expect(find.text('2 of 4 bookings have arrived'), findsOneWidget);
      expect(find.text('RIGHT'), findsOneWidget);
    });

    testWidgets('the eyebrow, the line and the right side are optional', (tester) async {
      await show(tester, const BuHeroCard(title: 'Only a headline'));
      expect(find.text('Only a headline'), findsOneWidget);
      expect(find.byType(BuEyebrow), findsNothing);
    });

    testWidgets('the headline keeps to the left and what is at the right keeps its own room', (tester) async {
      await show(tester, const BuHeroCard(eyebrow: 'Tonight', title: 'A long headline that needs more than one line to say', trailing: SizedBox(width: 96, height: 96, key: Key('side'))));
      final side = tester.getRect(find.byKey(const Key('side')));
      final title = tester.getRect(find.text('A long headline that needs more than one line to say'));
      expect(title.right, lessThanOrEqualTo(side.left), reason: 'the headline wraps before it reaches the right side');
      expect(tester.takeException(), isNull);
    });

    testWidgets('has the hero\'s large rounded corners and an orange-tinted edge', (tester) async {
      await show(tester, const BuHeroCard(title: 'x'));
      final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(BuHeroCard), matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.circular(BuRadius.hero));
      final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(BuHeroCard), matching: find.byType(DecoratedBox)).first);
      expect(((box.decoration as BoxDecoration).border! as Border).top.color, _bu.orange.withValues(alpha: 0.18));
    });

    testWidgets('is one item for a screen reader, everything in it read together and apart from what is around it', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const Column(children: [
        Text('Before'),
        BuHeroCard(eyebrow: 'Tonight', title: '12 guests expected', subtitle: '2 of 4 bookings have arrived', trailing: BuRing(value: 0.5, center: '50%', caption: 'arrived')),
        Text('After'),
      ]));
      expect(tester.getSemantics(find.byType(BuHeroCard)).label, 'TONIGHT\n12 guests expected\n2 of 4 bookings have arrived\n50% arrived');
      handle.dispose();
    });

    testWidgets('does not take a tap away from what is inside it', (tester) async {
      var taps = 0;
      await show(tester, BuHeroCard(title: 'x', trailing: TextButton(onPressed: () => taps++, child: const Text('Go'))));
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });
  });

  group('BuMetricTile', () {
    testWidgets('the number is the first text in the tile and what it counts is the last', (tester) async {
      await show(tester, const BuMetricTile(value: '12', label: 'Guests expected'));
      final texts = tester.widgetList<Text>(find.descendant(of: find.byType(BuMetricTile), matching: find.byType(Text))).toList();
      expect(texts.map((t) => t.data), ['12', 'Guests expected']);
    });

    testWidgets('the number is in the ink colour unless it is given another, and the label is muted', (tester) async {
      await show(tester, const Column(children: [
        BuMetricTile(value: '3', label: 'Plain'),
        BuMetricTile(value: '4', label: 'Coloured', valueColor: Color(0xFFFFB258)),
      ]));
      expect(_textColor(tester, find.text('3')), _bu.ink);
      expect(_textColor(tester, find.text('4')), const Color(0xFFFFB258));
      expect(_textColor(tester, find.text('Plain')), _bu.muted);
    });

    testWidgets('is one item for a screen reader: the number, then what it counts', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, const Column(children: [Text('Before'), BuMetricTile(value: '12', label: 'Guests expected'), Text('After')]));
      expect(tester.getSemantics(find.byType(BuMetricTile)).label, '12\nGuests expected');
      handle.dispose();
    });

    testWidgets('two side by side share the width, and are as tall as their content, no taller', (tester) async {
      await show(tester, const Row(children: [
        Expanded(child: BuMetricTile(value: '4', label: 'Confirmed bookings')),
        SizedBox(width: 12),
        Expanded(child: BuMetricTile(value: '12', label: 'Guests expected')),
      ]));
      final a = tester.getRect(find.byType(BuMetricTile).first);
      final b = tester.getRect(find.byType(BuMetricTile).last);
      expect(a.width, b.width);
      expect(a.height, lessThan(100));
    });
  });
}
