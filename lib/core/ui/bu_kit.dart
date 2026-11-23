import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../theme/app_tokens.dart';
import 'bu_tap_guard.dart';

// The BottlesUp Business component kit: the small, reusable pieces the screens are built from, in the look of the Figma design (dark panels, one orange,
// "eyebrow" labels over large headings, icon tiles, soft status pills). Screens use these instead of drawing their own boxes, so every screen
// moves together when the design moves. Colours come from `context.bu` (see app_tokens.dart); nothing here is hard-coded to a screen.

/// The brand mark: the champagne bottle on an orange tile (the app's launcher icon, cropped to the bottle).
class BuLogoMark extends StatelessWidget {
  const BuLogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Semantics(
      label: 'BottlesUp',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.3),
          child: OverflowBox(
            maxWidth: size * 1.75,
            maxHeight: size * 1.75,
            child: Image.asset(
              'assets/images/launcher_icon.jpeg',
              width: size * 1.75,
              height: size * 1.75,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              // If the picture cannot be read the tile is still the brand's orange.
              errorBuilder: (_, __, ___) => ColoredBox(color: bu.orange),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small orange capitals above a heading: "WELCOME", "NEEDS ATTENTION", "ACTIVE LOUNGE".
class BuEyebrow extends StatelessWidget {
  const BuEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? context.bu.orange,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    );
  }
}

/// The top of a screen: an eyebrow, a large heading, and an optional line of explanation. Reads as one heading to a screen reader.
class BuPageHeader extends StatelessWidget {
  const BuPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.intro,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? intro;

  /// Something at the right of the heading, for example a "Tonight" button or a live indicator.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    BuEyebrow(eyebrow!),
                    const SizedBox(height: 6),
                  ],
                  Semantics(
                    header: true,
                    child: Text(title, style: text.displaySmall),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (intro != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              intro!,
              style: text.bodyMedium?.copyWith(color: context.bu.muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// A section's heading inside a screen: an eyebrow, a title, and an optional "View all" at the right.
class BuSectionHeader extends StatelessWidget {
  const BuSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                BuEyebrow(eyebrow!),
                const SizedBox(height: 4),
              ],
              Semantics(
                header: true,
                child: Text(title, style: text.titleLarge),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              actionLabel!,
              style: text.labelMedium?.copyWith(color: context.bu.orangeSoft),
            ),
          ),
      ],
    );
  }
}

/// A card: the design's dark panel with a barely-there edge. Tappable when [onTap] is given (with the press feedback a card should have).
class BuCard extends StatelessWidget {
  const BuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BuSpace.l),
    this.onTap,
    this.highlight = false,
    this.accent,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// An orange edge and a faint orange glow: the thing that wants a look (the workspace used last, a featured card).
  final bool highlight;

  /// A colour other than orange for that edge and glow (a red one for an urgent alert). Giving one highlights the card.
  final Color? accent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final radius = BorderRadius.circular(BuRadius.card);
    final lit = highlight || accent != null;
    final glow = accent ?? bu.orange;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient:
            lit
                ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: const Alignment(0.6, 0),
                  colors: [glow.withValues(alpha: 0.10), bu.panel],
                )
                : null,
        color: lit ? null : bu.panel,
        border: Border.all(
          color: lit ? glow.withValues(alpha: 0.28) : bu.hairline,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: BuGuardedInkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A rounded tile holding an icon: the left edge of a list row.
class BuIconTile extends StatelessWidget {
  const BuIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.color,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? bu.orangeWash,
        borderRadius: BorderRadius.circular(BuRadius.tile),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? bu.orangeSoft),
    );
  }
}

/// One row of a list: an icon tile, a title, a line under it, and something at the right (a count, a status, or by default a chevron).
/// A whole row is one tap target and reads as one item to a screen reader.
class BuListRow extends StatelessWidget {
  const BuListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.maxSubtitleLines = 2,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Replaces the icon tile (for a row that has an initials tile or a photo).
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final int maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final lead = leading ?? (icon == null ? null : BuIconTile(icon: icon!));
    return BuGuardedInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BuSpace.l,
            vertical: BuSpace.m + 2,
          ),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: BuSpace.m + 2)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(color: bu.muted),
                        maxLines: maxSubtitleLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: BuSpace.s),
                trailing!,
              ],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: BuSpace.xs),
                Icon(Ionicons.chevron_forward, size: 16, color: bu.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The kinds of status a pill can show. Colour is never the only signal: the pill always carries a word.
enum BuTone { neutral, good, attention, bad, brand }

/// A small word in a soft outline: "Live", "Draft", "2 to review".
class BuStatusPill extends StatelessWidget {
  const BuStatusPill(this.label, {super.key, this.tone = BuTone.neutral});

  final String label;
  final BuTone tone;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final color = switch (tone) {
      BuTone.neutral => bu.muted,
      BuTone.good => bu.green,
      BuTone.attention => bu.amber,
      BuTone.bad => bu.red,
      BuTone.brand => bu.orangeSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BuRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// A count shown at the right of a row: "3" in a soft disc. The tone says what the number means: brand (the default, orange), attention (amber: a number
/// that needs a person), good, bad, or neutral (a plain count that asks nothing of anyone).
class BuCountBadge extends StatelessWidget {
  const BuCountBadge(this.count, {super.key, this.tone = BuTone.brand});

  final int count;
  final BuTone tone;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final color = switch (tone) {
      BuTone.neutral => bu.muted,
      BuTone.good => bu.green,
      BuTone.attention => bu.amber,
      BuTone.bad => bu.red,
      BuTone.brand => bu.orangeSoft,
    };
    return Semantics(
      label: '$count',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color:
              tone == BuTone.neutral
                  ? bu.panel2
                  : color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(BuRadius.pill),
        ),
        // Centred but shrink-wrapped: a Container with an `alignment` would fill all the width a column offers it.
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// A group of rows in one card with a hairline between them.
class BuListCard extends StatelessWidget {
  const BuListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return BuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: bu.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The page background: the design's near-black with a soft orange glow in the top-right corner. Put it behind a whole screen (sign-in, the
/// workspace list, a home screen); it paints only, so it never takes a tap.
class BuBackdrop extends StatelessWidget {
  const BuBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bu.bg,
        gradient: RadialGradient(
          center: const Alignment(0.75, -1.1),
          radius: 0.95,
          colors: [
            bu.orange.withValues(alpha: 0.13),
            bu.orange.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// The wordmark: the brand mark with "BottlesUp" and a small "BUSINESS" under it, as at the top of the design's sign-in screen.
class BuWordmark extends StatelessWidget {
  const BuWordmark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BuLogoMark(size: size),
        const SizedBox(width: BuSpace.m),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BottlesUp',
              style: text.titleMedium?.copyWith(
                fontSize: 17,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'BUSINESS',
              style: text.labelSmall?.copyWith(
                color: bu.muted,
                fontSize: 9.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A ring that fills as [value] goes from 0 to 1, with a big word in the middle and a small one under it: "42%" over "arrived".
class BuRing extends StatelessWidget {
  const BuRing({
    super.key,
    required this.value,
    required this.center,
    this.caption,
    this.size = 96,
    this.stroke = 8,
  });

  /// 0 to 1. Anything outside is held to that range.
  final double value;
  final String center;
  final String? caption;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: caption == null ? center : '$center $caption',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: value.clamp(0.0, 1.0),
            track: Colors.white.withValues(alpha: 0.10),
            fill: bu.orangeSoft,
            stroke: stroke,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  center,
                  style: text.titleLarge?.copyWith(
                    fontSize: size * 0.24,
                    letterSpacing: -0.6,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: text.labelSmall?.copyWith(
                      color: bu.muted,
                      fontSize: size * 0.11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.stroke,
  });

  final double value;
  final Color track;
  final Color fill;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 6.2831853, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(
        arc,
        -1.5707963,
        6.2831853 * value,
        false,
        base..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.stroke != stroke;
}

/// The big card at the top of a home screen: an eyebrow, a headline, a line under it, and something at the right (usually a [BuRing]). A warm glow in
/// its corner, so it is the first thing the eye finds.
class BuHeroCard extends StatelessWidget {
  const BuHeroCard({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(BuRadius.hero);
    // Its own item for a screen reader: the headline, the line under it and the ring are read together, apart from what is around the card.
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: bu.orange.withValues(alpha: 0.18)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment(0.6, 0.9),
              colors: [Color(0xFF302019), Color(0xFF171513)],
              stops: [0, 0.72],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.7, -0.5),
                        radius: 0.8,
                        colors: [
                          const Color(0x47FF9853),
                          const Color(0x00FF9853),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(BuSpace.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eyebrow != null) ...[
                            BuEyebrow(eyebrow!),
                            const SizedBox(height: BuSpace.s),
                          ],
                          Text(
                            title,
                            style: text.titleLarge?.copyWith(
                              fontSize: 22,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: BuSpace.s),
                            Text(
                              subtitle!,
                              style: text.bodyMedium?.copyWith(color: bu.soft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: BuSpace.l),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One figure on a card: the number big, and what it counts under it. The number is the first text in the tile, the label the second.
class BuMetricTile extends StatelessWidget {
  const BuMetricTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.hint,
  });

  final String value;
  final String label;
  final Color? valueColor;

  /// A small line under the label ("Checked in at the venue"). The label stays the second text and the hint is the third.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    // One item for a screen reader: "12, Guests expected".
    return Semantics(
      container: true,
      child: BuCard(
        padding: const EdgeInsets.all(BuSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: text.headlineMedium?.copyWith(color: valueColor ?? bu.ink),
            ),
            const SizedBox(height: BuSpace.xs),
            Text(label, style: text.bodySmall?.copyWith(color: bu.muted)),
            if (hint != null)
              Text(hint!, style: text.bodySmall?.copyWith(color: bu.muted.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// One figure with its name above and a line under it, as on the design's Overview: the label at the top left, a small trend pill at the top right (or a
/// chevron when the tile opens something), the number big, and what it counts in a muted line.
class BuStatTile extends StatelessWidget {
  const BuStatTile({super.key, required this.label, required this.value, this.note, this.trend, this.trendTone = BuTone.good, this.onTap});

  final String label;
  final String value;
  final String? note;

  /// "+12%": shown in a soft pill at the top right. Without one, a tile that opens something shows a chevron.
  final String? trend;
  final BuTone trendTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    // One item for a screen reader: "Bookings, 19, 114 guests at tables".
    return Semantics(
      container: true,
      button: onTap != null,
      child: BuCard(
        onTap: onTap,
        padding: const EdgeInsets.all(BuSpace.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 106),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (trend != null)
                    _TrendPill(trend!, trendTone)
                  else if (onTap != null)
                    Icon(Ionicons.chevron_forward, size: 15, color: bu.muted),
                ],
              ),
              const SizedBox(height: BuSpace.m),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: text.headlineMedium?.copyWith(fontSize: 27, letterSpacing: -1.2))),
              if (note != null) ...[
                const SizedBox(height: 3),
                Text(note!, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill(this.text, this.tone);

  final String text;
  final BuTone tone;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final color = switch (tone) {
      BuTone.good => bu.green,
      BuTone.attention => bu.amber,
      BuTone.bad => bu.red,
      BuTone.brand => bu.orangeSoft,
      BuTone.neutral => bu.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// A venue in one line: its initials in a warm tile, its name, a line under it, and a dot for how it is doing (green: open, amber: not live yet).
class BuMiniVenue extends StatelessWidget {
  const BuMiniVenue({super.key, required this.name, required this.line, this.live = false, this.onTap});

  final String name;
  final String line;
  final bool live;
  final VoidCallback? onTap;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(BuSpace.m),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF392219), Color(0xFF211816)])),
            child: Text(initialsOf(name), style: text.labelLarge?.copyWith(color: bu.orangeSoft, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: BuSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall?.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(line, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: BuSpace.s),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: live ? bu.green : bu.amber, boxShadow: [BoxShadow(color: (live ? bu.green : bu.amber).withValues(alpha: 0.12), spreadRadius: 4)]),
          ),
        ],
      ),
    );
  }
}

/// The top of a page you open from a list, as the design draws it: a rounded back button, a small orange eyebrow and the page's title, and something at the
/// right (a status). The page itself sits under it with the usual side margin.
class BuDetailHeader extends StatelessWidget {
  const BuDetailHeader({super.key, required this.eyebrow, required this.title, this.onBack, this.trailing});

  final String eyebrow;
  final String title;

  /// Where the back button goes. Without it the button pops the route.
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final canGoBack = onBack != null || Navigator.of(context).canPop();
    return Row(
      children: [
        if (canGoBack) ...[
        Semantics(
          button: true,
          label: 'Go back',
          child: InkWell(
            key: const Key('detail-back'),
            borderRadius: BorderRadius.circular(BuRadius.control),
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bu.panel, borderRadius: BorderRadius.circular(BuRadius.control), border: Border.all(color: bu.line)),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: bu.soft),
            ),
          ),
        ),
        const SizedBox(width: BuSpace.m),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BuEyebrow(eyebrow), const SizedBox(height: 2), Semantics(header: true, child: Text(title, style: text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis))],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: BuSpace.s), trailing!],
      ],
    );
  }
}

/// A row of pill tabs that scrolls sideways, as the design draws a page's sections: the chosen one is light on dark, the others dark. [tabKeyPrefix] gives each tab
/// the key `prefix-label`.
class BuPillTabs extends StatelessWidget {
  const BuPillTabs({super.key, required this.labels, required this.selected, required this.onSelected, this.tabKeyPrefix = 'tab', this.soon = const {}});

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final String tabKeyPrefix;

  /// Labels that are designed but not built: they carry a small dot so nobody is surprised by what they open.
  final Set<String> soon;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    Widget tab(String label) {
      final on = label == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: Key('$tabKeyPrefix-$label'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => onSelected(label),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? bu.ink : bu.panel, borderRadius: BorderRadius.circular(22), border: on ? null : Border.all(color: bu.hairline)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: text.labelLarge?.copyWith(color: on ? bu.bg : bu.ink, fontWeight: FontWeight.w600)),
                if (soon.contains(label)) ...[
                  const SizedBox(width: 6),
                  Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? bu.bg : bu.orange)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // A plain row in a sideways scroll, so every tab exists (a few tabs, no need to build them lazily) and a screen reader can reach them all.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(children: [for (var i = 0; i < labels.length; i++) ...[if (i > 0) const SizedBox(width: 6), tab(labels[i])]]),
      ),
    );
  }
}

/// The app bar of a page you open from a list, in the design's look: [BuDetailHeader] in a bar. Takes the place of `AppBar(title: ...)`: the same title and the same
/// action buttons, with the design's back button and an eyebrow over the title.
class BuDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BuDetailAppBar({super.key, required this.title, required this.eyebrow, this.actions = const []});

  final String title;
  final String eyebrow;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.s),
        child: SizedBox(
          height: 56,
          child: BuDetailHeader(eyebrow: eyebrow, title: title, trailing: actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions)),
        ),
      ),
    );
  }
}
