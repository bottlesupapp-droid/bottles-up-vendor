import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/connectivity/connection_banner.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/bu_coming_soon.dart';
import '../../core/ui/glass_kit.dart';
import 'classic_top_bar.dart';

/// The frame around the classic screens (an account that has no workspace). It follows the design: the top bar that says who you are, then the five tabs
/// Overview, Venues, Tonight, Reports and More. Events live under More, as in the design; their routes are unchanged.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  static const _items = [
    GlassNavItem(icon: Ionicons.home_outline, activeIcon: Ionicons.home, label: 'Overview'),
    GlassNavItem(icon: Ionicons.business_outline, activeIcon: Ionicons.business, label: 'Venues'),
    GlassNavItem(icon: Ionicons.moon_outline, activeIcon: Ionicons.moon, label: 'Tonight'),
    GlassNavItem(icon: Ionicons.stats_chart_outline, activeIcon: Ionicons.stats_chart, label: 'Reports'),
    GlassNavItem(icon: Ionicons.menu_outline, activeIcon: Ionicons.menu, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    return Scaffold(
      // The page ends where the floating bar begins. It used to flow behind the bar (extendBody), which left the last line of a list, buttons such as "Delete Account" and the
      // last card under the bar.
      extendBody: false,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // The brand bar belongs to the five tabs; a page opened from a tab has its own header with a back button, as in the design.
                if (_isTab(context)) const ClassicTopBar(),
                const ConnectionBanner(),
                Expanded(child: child),
              ],
            ),
          ),
          // The design's round Messages button, on the five tabs only (never over a form or a page with a button of its own). Messages are not built: it says so.
          if (_isTab(context))
            const Positioned(right: BuSpace.page, bottom: BuSpace.l, child: _MessagesButton()),
        ],
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTabTapped(context, index),
        items: _items,
      ),
    );
  }

  static const _tabRoots = ['/dashboard', '/clubs', '/tonight', '/analytics', '/profile'];

  bool _isTab(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return _tabRoots.contains(path);
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/venues') || location.startsWith('/clubs')) return 1;
    if (location.startsWith('/tonight')) return 2;
    if (location.startsWith('/analytics') || location.startsWith('/earnings')) return 3;
    // Events, bookings, inventory, profile: all reached from More.
    if (location.startsWith('/profile') || location.startsWith('/more') || location.startsWith('/events') || location.startsWith('/bookings') || location.startsWith('/inventory')) return 4;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard');
      case 1: context.go('/clubs');
      case 2: context.go('/tonight');
      case 3: context.go('/analytics');
      case 4: context.go('/profile');
    }
  }
}

class _MessagesButton extends StatelessWidget {
  const _MessagesButton();

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Semantics(
      button: true,
      label: 'Messages, coming soon',
      child: Material(
        color: bu.orange,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: bu.orange.withValues(alpha: 0.4),
        child: InkWell(
          key: const Key('classic-messages-button'),
          customBorder: const CircleBorder(),
          onTap: () => showComingSoon(context, title: 'Messages', text: 'Chat with your team and your guests in one inbox, right from the app.'),
          child: const SizedBox(width: 56, height: 56, child: Icon(Ionicons.chatbubble_outline, color: Colors.white, size: 24)),
        ),
      ),
    );
  }
}
