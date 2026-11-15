import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/widgets/classic_top_bar.dart' show classicRoleLabel;
import '../../auth/providers/supabase_auth_provider.dart';
import '../../venues/providers/venues_provider.dart';

/// Business details, from what the account has: the business name, e-mail and phone it signed up with, and its venues. Nothing is invented. A line the account has not filled in
/// says so and opens Edit profile; the venues' opening hours are designed and not built, so they say "Coming soon".
class BusinessDetailsScreen extends ConsumerWidget {
  const BusinessDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentVendorUserProvider);
    final venues = ref.watch(myVenuesProvider).valueOrNull ?? const <Venue>[];
    final businessName = (user?.businessName ?? '').trim();
    final phone = (user?.phone ?? '').trim();
    final email = (user?.email ?? '').trim();
    void edit() => context.push('/profile/edit');

    Widget fact(String key, IconData icon, String label, String value, {required bool filled}) => BuListRow(
      key: Key(key),
      icon: icon,
      title: label,
      subtitle: filled ? value : 'Not added yet',
      trailing: filled ? null : Text('Add', style: text.labelLarge?.copyWith(color: bu.orange, fontWeight: FontWeight.w700)),
      showChevron: !filled,
      onTap: filled ? null : edit,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Account', title: 'Business Details'),
      body: ListView(
        key: const Key('business-list'),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        children: [
          BuCard(
            key: const Key('business-card'),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(BuRadius.control + 2),
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF392219), Color(0xFF211816)]),
                    image: (user?.logoUrl ?? '').isNotEmpty ? DecorationImage(image: NetworkImage(user!.logoUrl!), fit: BoxFit.cover, onError: (e, s) {}) : null,
                  ),
                  child:
                      (user?.logoUrl ?? '').isNotEmpty
                          ? null
                          : Text(
                            BuMiniVenue.initialsOf(businessName.isNotEmpty ? businessName : (email.isNotEmpty ? email : '?')),
                            style: text.titleMedium?.copyWith(color: bu.orangeSoft, fontWeight: FontWeight.w800),
                          ),
                ),
                const SizedBox(width: BuSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName.isNotEmpty ? businessName : 'Add your business name',
                        key: const Key('business-name-title'),
                        style: text.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(user == null ? 'Loading' : classicRoleLabel(user.role), style: text.bodySmall?.copyWith(color: bu.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BuSpace.xl),
          const BuEyebrow('Business information'),
          const SizedBox(height: BuSpace.s),
          BuListCard(
            children: [
              fact('business-name', Ionicons.business_outline, 'Business name', businessName, filled: businessName.isNotEmpty),
              fact('business-email', Ionicons.mail_outline, 'Business email', email, filled: email.isNotEmpty),
              fact('business-phone', Ionicons.call_outline, 'Business phone', phone, filled: phone.isNotEmpty),
            ],
          ),
          const SizedBox(height: BuSpace.xl),
          BuSectionHeader(eyebrow: 'Where guests go', title: 'Your venues', actionLabel: 'Add', onAction: () => context.push('/clubs/create')),
          const SizedBox(height: BuSpace.m),
          if (venues.isEmpty)
            BuCard(key: const Key('business-no-venues'), child: Text('No venues yet. Add one and it appears here with its address.', style: text.bodyMedium?.copyWith(color: bu.muted)))
          else
            Column(
              key: const Key('business-venues'),
              children: [
                for (final v in venues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BuSpace.s),
                    child: BuMiniVenue(
                      name: v.name,
                      line: (v.fullAddress ?? '').trim().isEmpty ? 'No address yet' : v.fullAddress!,
                      live: v.status == VenueStatus.active,
                      onTap: () => context.push('/clubs/${v.id}'),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: BuSpace.xl),
          const BuEyebrow('Opening hours'),
          const SizedBox(height: BuSpace.s),
          BuListCard(
            children: [
              BuListRow(
                key: const Key('business-hours-soon'),
                icon: Ionicons.time_outline,
                title: 'Opening hours',
                subtitle: 'The days and times each venue is open',
                trailing: const BuComingSoonPill(),
                showChevron: false,
                onTap: () => showComingSoon(context, title: 'Opening hours', text: 'Set the days and times each venue is open, so guests see them on its page.'),
              ),
            ],
          ),
          const SizedBox(height: BuSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(key: const Key('business-edit'), onPressed: edit, icon: const Icon(Ionicons.create_outline), label: const Text('Edit business details')),
          ),
        ],
      ),
    );
  }
}
