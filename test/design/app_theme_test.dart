import 'dart:io';

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _t = BuTokens.dark;

void main() {
  final theme = AppTheme.darkTheme;

  group('the dark theme', () {
    test('is the design: dark, Material 3, near-black page, one orange', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, _t.bg);
      expect(theme.colorScheme.primary, _t.orange);
      expect(theme.colorScheme.onSurface, _t.ink);
      expect(theme.colorScheme.onSurfaceVariant, _t.muted);
      expect(theme.colorScheme.outline, _t.line);
    });

    test('has no leftover teal: the old theme tinted a selected chip teal, which has no place in the brand', () {
      const oldTeal = Color(0xFF03DAC6);
      final colors = theme.colorScheme;
      for (final c in [colors.secondary, colors.secondaryContainer, colors.tertiary, colors.primaryContainer]) {
        expect(c, isNot(oldTeal));
      }
      expect(colors.secondaryContainer, _t.raised, reason: 'a selected thing is a raised dark surface, or an orange wash');
    });

    test('registers the design tokens, so widgets can read them with context.bu', () {
      expect(theme.extension<BuTokens>(), isNotNull);
    });

    test('uses the bundled Inter everywhere, so text never waits for a download', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.titleLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.labelSmall?.fontFamily, 'Inter');
      expect(AppTheme.fontFamily, 'Inter');
    });

    test('the font is really in the app: declared in pubspec.yaml, present on disk, and nothing in lib fetches a Google font', () {
      expect(File('assets/fonts/Inter.ttf').existsSync(), isTrue);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Inter'));
      expect(pubspec, contains('asset: assets/fonts/Inter.ttf'));
      final fetching = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).where((f) => f.readAsStringSync().contains('GoogleFonts.'));
      expect(fetching, isEmpty, reason: 'google_fonts downloads a font over the network on first use');
    });
  });

  group('type scale', () {
    final text = theme.textTheme;

    test('headings are ink, tight and semi-bold; body is soft; captions are muted', () {
      expect(text.displaySmall?.fontSize, 30);
      expect(text.displaySmall?.fontWeight, FontWeight.w600);
      expect(text.displaySmall?.letterSpacing, lessThan(0), reason: 'the design tightens large headings');
      expect(text.displaySmall?.color, _t.ink);
      expect(text.bodyMedium?.color, _t.soft);
      expect(text.bodySmall?.color, _t.muted);
    });

    test('sizes step down in order, so a title is never smaller than the body under it', () {
      final sizes = [text.headlineLarge, text.headlineMedium, text.headlineSmall, text.titleLarge, text.titleMedium, text.titleSmall, text.bodyMedium, text.bodySmall].map((s) => s!.fontSize!).toList();
      expect(sizes, orderedEquals([...sizes]..sort((a, b) => b.compareTo(a))));
    });

    test('nothing is smaller than 10 points', () {
      for (final style in [text.labelSmall, text.bodySmall, text.labelMedium]) {
        expect(style!.fontSize, greaterThanOrEqualTo(10));
      }
    });
  });

  group('controls', () {
    test('a text field is a filled dark panel with 14-point corners and an orange focus ring', () {
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, _t.panel);
      final focused = input.focusedBorder as OutlineInputBorder;
      expect(focused.borderSide.color, _t.orange);
      expect((input.enabledBorder as OutlineInputBorder).borderRadius, BorderRadius.circular(BuRadius.control));
      expect((input.errorBorder as OutlineInputBorder).borderSide.color, _t.red);
    });

    test('filled and elevated buttons are the orange primary, at least 52 points tall, with 14-point corners', () {
      for (final style in [theme.filledButtonTheme.style!, theme.elevatedButtonTheme.style!]) {
        expect(style.backgroundColor!.resolve({}), _t.orange);
        expect(style.foregroundColor!.resolve({}), Colors.white);
        expect(style.minimumSize!.resolve({})!.height, 52);
        expect((style.shape!.resolve({}) as RoundedRectangleBorder).borderRadius, BorderRadius.circular(BuRadius.control));
        expect(style.backgroundColor!.resolve({WidgetState.disabled}), _t.raised, reason: 'a disabled button is plainly dark, not a faded orange');
      }
    });

    test('an outlined button is dark with a soft edge, and a text button is the lighter orange', () {
      expect(theme.outlinedButtonTheme.style!.side!.resolve({})!.color, _t.line);
      expect(theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}), _t.ink);
      expect(theme.textButtonTheme.style!.foregroundColor!.resolve({}), _t.orangeSoft);
    });

    test('a chip is outlined, and selected is an orange wash with orange text', () {
      final chip = theme.chipTheme;
      expect(chip.backgroundColor, Colors.transparent);
      expect(chip.selectedColor, _t.orangeWash);
      expect(chip.secondaryLabelStyle?.color, _t.orangeSoft);
      expect(chip.side?.color, _t.line);
    });

    test('a segmented button selects to the raised surface', () {
      final style = theme.segmentedButtonTheme.style!;
      expect(style.backgroundColor!.resolve({WidgetState.selected}), _t.raised);
      expect(style.backgroundColor!.resolve({}), _t.panel);
      expect(style.foregroundColor!.resolve({WidgetState.selected}), _t.ink);
    });

    test('switches, checkboxes and radios are orange when on', () {
      expect(theme.switchTheme.trackColor!.resolve({WidgetState.selected}), _t.orange);
      expect(theme.checkboxTheme.fillColor!.resolve({WidgetState.selected}), _t.orange);
      expect(theme.radioTheme.fillColor!.resolve({WidgetState.selected}), _t.orange);
    });

    test('progress is orange on a dark track', () {
      expect(theme.progressIndicatorTheme.color, _t.orange);
      expect(theme.progressIndicatorTheme.linearTrackColor, _t.line);
    });
  });

  group('surfaces', () {
    test('a card is the panel with a hairline edge and 20-point corners', () {
      final card = theme.cardTheme;
      expect(card.color, _t.panel);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(BuRadius.card));
      expect(shape.side.color, _t.hairline);
      expect(card.elevation, 0);
    });

    test('dialogs and sheets are the panel with 28-point corners', () {
      expect(theme.dialogTheme.backgroundColor, _t.panel);
      expect((theme.dialogTheme.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(BuRadius.sheet));
      expect(theme.bottomSheetTheme.backgroundColor, _t.panel);
      expect((theme.bottomSheetTheme.shape as RoundedRectangleBorder).borderRadius, const BorderRadius.vertical(top: Radius.circular(BuRadius.sheet)));
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
    });

    test('a snack bar floats on a raised surface', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.backgroundColor, _t.raised);
    });

    test('the app bar is flat and the page colour, never tinted by scrolling', () {
      expect(theme.appBarTheme.backgroundColor, _t.bg);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    });
  });

  group('shared decorations and colours', () {
    test('status colours are the design\'s green and amber, and a red that sits with the orange', () {
      expect(AppTheme.successColor, _t.green);
      expect(AppTheme.warningColor, _t.amber);
      expect(AppTheme.errorColor, _t.red);
    });

    test('the card decoration used by 40 screens is the same card as the theme\'s', () {
      final d = AppTheme.darkCardDecoration;
      expect(d.color, _t.panel);
      expect(d.borderRadius, BorderRadius.circular(BuRadius.card));
      expect((d.border as Border).top.color, _t.hairline);
    });

    test('the container decoration is one step down from a card', () {
      final d = AppTheme.darkContainerDecoration;
      expect(d.color, _t.panel2);
      expect(d.borderRadius, BorderRadius.circular(BuRadius.control));
    });
  });
}
