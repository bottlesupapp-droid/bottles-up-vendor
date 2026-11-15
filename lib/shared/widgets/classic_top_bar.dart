import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/bu_kit.dart';
import '../../features/auth/providers/supabase_auth_provider.dart';

/// "Owner", "Organizer", ...: the account's role as a person would say it.
String classicRoleLabel(String? role) {
  switch (role) {
    case 'venue_owner':
    case 'owner':
      return 'Owner';
    case 'organizer':
      return 'Organizer';
    case 'promoter':
      return 'Promoter';
    case 'manager':
      return 'Manager';
    default:
      return 'Team';
  }
}

/// The bar at the top of every classic screen, as in the design: the brand mark, "BottlesUp" with the business and role under it, and the profile button.
/// It always says who you are acting as (the same idea as the workspace bar).
class ClassicTopBar extends ConsumerWidget {
  const ClassicTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final vendor = ref.watch(currentVendorUserProvider);
    final business = (vendor?.businessName ?? '').trim();
    final line = '${business.isEmpty ? 'Your business' : business} · ${classicRoleLabel(vendor?.role)}';
    return Container(
      key: const Key('classic-top-bar'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 12, BuSpace.page, 12),
      decoration: BoxDecoration(
        color: bu.bg.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          const BuLogoMark(size: 38),
          const SizedBox(width: BuSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BottlesUp', style: theme.textTheme.titleSmall?.copyWith(fontSize: 17, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text(line, key: const Key('classic-top-bar-line'), style: theme.textTheme.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Material(
            color: bu.panel,
            borderRadius: BorderRadius.circular(BuRadius.control),
            child: InkWell(
              key: const Key('classic-profile-button'),
              borderRadius: BorderRadius.circular(BuRadius.control),
              onTap: () => context.go('/profile'),
              child: Semantics(
                button: true,
                label: 'Your profile',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(BuRadius.control), border: Border.all(color: bu.hairline)),
                  child: Icon(Ionicons.person_outline, size: 20, color: bu.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
