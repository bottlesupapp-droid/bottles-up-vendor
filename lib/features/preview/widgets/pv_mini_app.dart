import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/ui/glass_kit.dart';
import '../preview_config.dart';
import 'pv_kit.dart';

/// One tab of a sample role app.
class PvTab {
  const PvTab({required this.label, required this.icon, required this.activeIcon, required this.builder});

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}

/// A whole role made of sample pages: its name and where it works (the bar at the top), and its tabs (the bar at the bottom).
class PvMiniAppConfig {
  const PvMiniAppConfig({required this.id, required this.role, required this.org, required this.scope, required this.tabs});

  final String id;
  final String role;
  final String org;
  final String scope;
  final List<PvTab> tabs;
}

/// Leaves a sample screen: back to the list it was opened from.
void pvLeave(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  GoRouter.maybeOf(context)?.go(PreviewRoutes.gallery);
}

/// The frame of a sample role app: the same two bars as a real workspace (who you are acting as; the tabs), with "Sample" in the top one.
class PvMiniApp extends StatefulWidget {
  const PvMiniApp({super.key, required this.config, this.initialTab = 0});

  final PvMiniAppConfig config;
  final int initialTab;

  @override
  State<PvMiniApp> createState() => _PvMiniAppState();
}

class _PvMiniAppState extends State<PvMiniApp> {
  late int _index = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final theme = Theme.of(context);
    final c = widget.config;
    return Scaffold(
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              key: const Key('pv-context-bar'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(BuSpace.page, 12, BuSpace.m, 12),
              decoration: BoxDecoration(color: bu.bg.withValues(alpha: 0.92), border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
              child: Row(
                children: [
                  const BuLogoMark(size: 38),
                  const SizedBox(width: BuSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.role} · ${c.org}', style: theme.textTheme.titleSmall?.copyWith(fontSize: 15, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const BuStatusPill('Sample', tone: BuTone.attention),
                            const SizedBox(width: BuSpace.s),
                            Expanded(child: Text(c.scope, style: theme.textTheme.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('pv-close'),
                    tooltip: 'Close the sample',
                    onPressed: () => pvLeave(context),
                    style: IconButton.styleFrom(
                      backgroundColor: bu.panel,
                      foregroundColor: bu.ink,
                      fixedSize: const Size(44, 44),
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: bu.line)),
                    ),
                    icon: const Icon(Ionicons.close, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PvMiniAppScope(
                child: IndexedStack(
                  index: _index,
                  children: [for (final t in c.tabs) Builder(builder: t.builder)],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [for (final t in c.tabs) GlassNavItem(icon: t.icon, activeIcon: t.activeIcon, label: t.label)],
      ),
    );
  }
}
