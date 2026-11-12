import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
// ── Brand palette ─────────────────────────────────────────────────────────────
const Color _kOrange = Color(0xFFFF5A2F);
const Color _kOrangeGlow = Color(0x33FF5A2F);
const Color _kGlassBorder = Color(0x26FFFFFF);
const Color _kBg = Color(0xFF090909);

// ── GlassCard ─────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color? tintColor;
  final bool showBorder;
  final bool showGlow;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 20,
    this.tintColor,
    this.showBorder = true,
    this.showGlow = false,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ??
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.30);
    final glow = glowColor ?? _kOrangeGlow;

    Widget card = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                tint,
              ],
            ),
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(color: _kGlassBorder, width: 0.8)
                : null,
            boxShadow: showGlow
                ? [
                    BoxShadow(
                      color: glow,
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ── GlassMetricCard ───────────────────────────────────────────────────────────
/// Dashboard metric card with glass + accent glow.
class GlassMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final String? trend;
  final bool isAlert;
  final VoidCallback? onTap;

  const GlassMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.trend,
    this.isAlert = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                  _kBg.withValues(alpha: 0.60),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isAlert
                    ? theme.colorScheme.error.withValues(alpha: 0.35)
                    : color.withValues(alpha: 0.25),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Icon with glow
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.30),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    if (trend != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAlert
                                  ? theme.colorScheme.error
                                      .withValues(alpha: 0.12)
                                  : color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAlert
                                    ? theme.colorScheme.error
                                        .withValues(alpha: 0.30)
                                    : color.withValues(alpha: 0.30),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              trend!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isAlert
                                    ? theme.colorScheme.error
                                    : color,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w500,
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

// ── GlassBottomNavBar ────────────────────────────────────────
/// The floating bottom bar of every workspace: a glass pill with one tab per section and an orange glow on the current one.
/// The bar's own box runs to the bottom of the screen (it includes the home-indicator strip), so a page above it can end exactly where the pill begins.
class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 14, right: 14, bottom: bottom + 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.bar),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 76,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xE8191817),
                  borderRadius: BorderRadius.circular(BuRadius.bar),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 40, offset: const Offset(0, 16)),
                    BoxShadow(color: bu.orange.withValues(alpha: 0.05), blurRadius: 36, spreadRadius: 2),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _GlassNavItem(item: items[i], isSelected: i == currentIndex, onTap: () => onTap(i)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  final GlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  const _GlassNavItem({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final idle = const Color(0xFF777571);
    final color = isSelected ? bu.orangeSoft : idle;
    final base = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bu.orange.withValues(alpha: 0.20), bu.orange.withValues(alpha: 0.07)],
                  )
                : null,
            border: Border.all(color: isSelected ? bu.orange.withValues(alpha: 0.22) : Colors.transparent),
            boxShadow: isSelected ? [BoxShadow(color: bu.orange.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 5))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(isSelected ? item.activeIcon : item.icon, key: ValueKey(isSelected), color: color, size: 22),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: (base ?? const TextStyle()).copyWith(color: color, fontSize: 10.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, letterSpacing: 0),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GlassNavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ── AmbientGlowBackground ─────────────────────────────────────────────────────
class AmbientGlowBackground extends StatefulWidget {
  final Widget child;
  final bool animate;
  const AmbientGlowBackground(
      {super.key, required this.child, this.animate = true});

  @override
  State<AmbientGlowBackground> createState() =>
      _AmbientGlowBackgroundState();
}

class _AmbientGlowBackgroundState extends State<AmbientGlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 9));
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _kBg),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) =>
              CustomPaint(painter: _OrbPainter(_ctrl.value)),
        ),
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _orb(canvas, Offset(w * (0.7 + 0.12 * math.sin(t * math.pi)),
            h * (0.18 + 0.08 * math.cos(t * math.pi))),
        w * 0.55, const Color(0x20FF6B35), const Color(0x00FF6B35));

    _orb(canvas, Offset(w * (0.18 - 0.08 * math.sin(t * math.pi + 1.2)),
            h * (0.72 + 0.10 * math.cos(t * math.pi + 1.2))),
        w * 0.48, const Color(0x168B5CF6), const Color(0x008B5CF6));

    _orb(canvas, Offset(w * 0.50, h * (0.38 + 0.06 * math.sin(t * math.pi * 2))),
        w * 0.30, const Color(0x0BFFFFFF), const Color(0x00FFFFFF));
  }

  void _orb(Canvas c, Offset center, double r, Color inner, Color outer) {
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(colors: [inner, outer])
            .createShader(Rect.fromCircle(center: center, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter o) => o.t != t;
}

// ── GlassAppBar ───────────────────────────────────────────────────────────────
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const GlassAppBar(
      {super.key, required this.title, this.actions, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                _kBg.withValues(alpha: 0.60),
              ],
            ),
            border: Border(
              bottom:
                  BorderSide(color: _kGlassBorder, width: 0.5),
            ),
          ),
          child: AppBar(
            title: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: Colors.white)),
            leading: leading,
            actions: actions,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
      ),
    );
  }
}

// ── GlassSheet ────────────────────────────────────────────────────────────────
class GlassSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final double maxHeightFraction;

  const GlassSheet(
      {super.key,
      required this.child,
      this.title,
      this.maxHeightFraction = 0.85});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints:
              BoxConstraints(maxHeight: mq.size.height * maxHeightFraction),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1AFFFFFF), Color(0xCC0A0A0A)],
            ),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: _kGlassBorder, width: 0.8),
              left: BorderSide(color: _kGlassBorder, width: 0.5),
              right: BorderSide(color: _kGlassBorder, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 16),
                Text(title!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                Divider(
                    color: Colors.white.withValues(alpha: 0.10),
                    height: 24),
              ] else
                const SizedBox(height: 8),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GlowDivider ───────────────────────────────────────────────────────────────
class GlowDivider extends StatelessWidget {
  final double opacity;
  const GlowDivider({super.key, this.opacity = 0.3});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.transparent,
          _kOrange.withValues(alpha: opacity),
          Colors.transparent,
        ]),
      ),
    );
  }
}
