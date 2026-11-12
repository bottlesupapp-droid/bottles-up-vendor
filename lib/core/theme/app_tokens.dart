import 'package:flutter/material.dart';

/// The design tokens of BottlesUp Business: colours, corner radii and spacing.
///
/// They come from the Figma Make design "BottlesUp Business App" (read from the prototype's own stylesheet, so they are the designer's values, not
/// an estimate): a warm near-black, one orange, soft neutral greys, a green and an amber for status, 20-point corners.
///
/// Widgets read them with `context.bu`. When a widget is shown under a plain `ThemeData` (most widget tests), `context.bu` answers with
/// [BuTokens.dark], so nothing needs the extension to be registered to work.
@immutable
class BuTokens extends ThemeExtension<BuTokens> {
  const BuTokens({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.raised,
    required this.line,
    required this.hairline,
    required this.muted,
    required this.soft,
    required this.ink,
    required this.orange,
    required this.orangeSoft,
    required this.orangeWash,
    required this.green,
    required this.amber,
    required this.red,
  });

  /// The page behind everything.
  final Color bg;

  /// Cards, inputs, bars.
  final Color panel;

  /// A step above [panel]: a pressed row, a selected segment's neighbour, an icon tile.
  final Color panel2;

  /// The most raised surface: the selected segment, a toggle's track.
  final Color raised;

  /// Dividers and the outline of inputs and secondary buttons.
  final Color line;

  /// A barely-there edge on cards (white at 5.5%).
  final Color hairline;

  /// Secondary text, captions, unselected icons.
  final Color muted;

  /// Body text on a card, labels.
  final Color soft;

  /// Headings and primary text.
  final Color ink;

  final Color orange;
  final Color orangeSoft;

  /// Orange at 12%: the fill of a selected or highlighted thing.
  final Color orangeWash;

  final Color green;
  final Color amber;

  /// Errors and destructive actions. (The design has no red of its own; this one sits with its orange.)
  final Color red;

  /// The tokens of the dark look, which is the only look the app has for now.
  static const BuTokens dark = BuTokens(
    bg: Color(0xFF090909),
    panel: Color(0xFF151514),
    panel2: Color(0xFF1C1B1A),
    raised: Color(0xFF2A2826),
    line: Color(0xFF292826),
    hairline: Color(0x0EFFFFFF),
    muted: Color(0xFF999894),
    soft: Color(0xFFC8C6C1),
    ink: Color(0xFFF5F4F1),
    orange: Color(0xFFFF5A2F),
    orangeSoft: Color(0xFFFF7A45),
    orangeWash: Color(0x1FFF5A2F),
    green: Color(0xFF59D7A2),
    amber: Color(0xFFFFB258),
    red: Color(0xFFFF6B6B),
  );

  @override
  BuTokens copyWith({
    Color? bg,
    Color? panel,
    Color? panel2,
    Color? raised,
    Color? line,
    Color? hairline,
    Color? muted,
    Color? soft,
    Color? ink,
    Color? orange,
    Color? orangeSoft,
    Color? orangeWash,
    Color? green,
    Color? amber,
    Color? red,
  }) =>
      BuTokens(
        bg: bg ?? this.bg,
        panel: panel ?? this.panel,
        panel2: panel2 ?? this.panel2,
        raised: raised ?? this.raised,
        line: line ?? this.line,
        hairline: hairline ?? this.hairline,
        muted: muted ?? this.muted,
        soft: soft ?? this.soft,
        ink: ink ?? this.ink,
        orange: orange ?? this.orange,
        orangeSoft: orangeSoft ?? this.orangeSoft,
        orangeWash: orangeWash ?? this.orangeWash,
        green: green ?? this.green,
        amber: amber ?? this.amber,
        red: red ?? this.red,
      );

  @override
  BuTokens lerp(ThemeExtension<BuTokens>? other, double t) {
    if (other is! BuTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BuTokens(
      bg: mix(bg, other.bg),
      panel: mix(panel, other.panel),
      panel2: mix(panel2, other.panel2),
      raised: mix(raised, other.raised),
      line: mix(line, other.line),
      hairline: mix(hairline, other.hairline),
      muted: mix(muted, other.muted),
      soft: mix(soft, other.soft),
      ink: mix(ink, other.ink),
      orange: mix(orange, other.orange),
      orangeSoft: mix(orangeSoft, other.orangeSoft),
      orangeWash: mix(orangeWash, other.orangeWash),
      green: mix(green, other.green),
      amber: mix(amber, other.amber),
      red: mix(red, other.red),
    );
  }
}

extension BuContext on BuildContext {
  /// The design tokens in force here. Falls back to the dark ones under a plain `ThemeData`.
  BuTokens get bu => Theme.of(this).extension<BuTokens>() ?? BuTokens.dark;
}

/// Corner radii, in logical pixels.
abstract final class BuRadius {
  /// Cards and list groups.
  static const double card = 20;

  /// The big card at the top of a home screen.
  static const double hero = 24;

  /// Inputs and buttons.
  static const double control = 14;

  /// Icon tiles inside a row.
  static const double tile = 12;

  /// Pills, progress bars, toggles.
  static const double pill = 99;

  /// The floating bottom bar.
  static const double bar = 24;

  /// Bottom sheets and dialogs.
  static const double sheet = 28;
}

/// Spacing, in logical pixels. Screens are laid out on a 4-point grid with a 20-point margin.
abstract final class BuSpace {
  static const double page = 20;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
