import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../../core/ui/glass_kit.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  static const _items = [
    GlassNavItem(
      icon: Ionicons.home_outline,
      activeIcon: Ionicons.home,
      label: 'Dashboard',
    ),
    GlassNavItem(
      icon: Ionicons.calendar_outline,
      activeIcon: Ionicons.calendar,
      label: 'Events',
    ),
    GlassNavItem(
      icon: Ionicons.stats_chart_outline,
      activeIcon: Ionicons.stats_chart,
      label: 'Analytics',
    ),
    GlassNavItem(
      icon: Ionicons.business_outline,
      activeIcon: Ionicons.business,
      label: 'Venues',
    ),
    GlassNavItem(
      icon: Ionicons.menu_outline,
      activeIcon: Ionicons.menu,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    return Scaffold(
      extendBody: true, // body flows behind the floating glass nav
      body: child,
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTabTapped(context, index),
        items: _items,
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/events')) return 1;
    if (location.startsWith('/analytics')) return 2;
    if (location.startsWith('/venues') || location.startsWith('/clubs')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/more')) return 4;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard');
      case 1: context.go('/events');
      case 2: context.go('/analytics');
      case 3: context.go('/clubs');
      case 4: context.go('/profile');
    }
  }
}
