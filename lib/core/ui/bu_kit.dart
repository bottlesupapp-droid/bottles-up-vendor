import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../theme/app_tokens.dart';

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
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// An orange edge and a faint orange glow: the thing that wants a look (the workspace used last, a featured card).
  final bool highlight;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final radius = BorderRadius.circular(BuRadius.card);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient:
            highlight
                ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: const Alignment(0.6, 0),
                  colors: [bu.orange.withValues(alpha: 0.10), bu.panel],
                )
                : null,
        color: highlight ? null : bu.panel,
        border: Border.all(
          color: highlight ? bu.orange.withValues(alpha: 0.28) : bu.hairline,
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
        child: InkWell(
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
    return InkWell(
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

/// A count shown at the right of a row: "3" in a soft orange disc.
class BuCountBadge extends StatelessWidget {
  const BuCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Semantics(
      label: '$count',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: bu.orangeWash,
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
            ).textTheme.labelMedium?.copyWith(color: bu.orangeSoft),
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
