import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../floor/screens/floor_screen.dart';
import '../../workspace/models/role_navigation.dart';
import '../../workspace/models/workspace_role.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../logic/owner_rules.dart';
import '../providers/owner_providers.dart';
import '../services/owner_service.dart';
import '../widgets/booking_link_card.dart';
import '../widgets/venue_setup_list.dart';
import '../widgets/venue_status_chip.dart';

/// One venue of an owner's business: its bookings, how far it is set up, and where guests book. Only the owner of the business
/// sees it, and only for a venue of that business; the database decides which venues those are.
class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.membershipId, required this.venueId, this.onBack});

  final String membershipId;
  final String venueId;

  /// Replaced in tests. By default: back to where the person came from, or to the Venues list.
  final VoidCallback? onBack;

  void _back(BuildContext context) {
    if (onBack != null) return onBack!();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(workspaceSectionPath(membershipId, 'venues'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider).byMembershipId(membershipId);
    if (workspace == null || workspace.role != WorkspaceRole.owner) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This venue is not part of your role.', key: Key('venue-not-yours'))));
    }

    final venues = ref.watch(ownerVenuesProvider(workspace.orgId));
    return venues.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error is OwnerLoadException ? error.message : ownerLoadMessage(unavailable: false, accessEnded: false), key: const Key('venue-error'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => _back(context), child: const Text('Back')),
            ],
          ),
        ),
      ),
      data: (list) {
        final venue = list.where((v) => v.id == venueId).firstOrNull;
        if (venue == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This venue is not part of your business.', key: Key('venue-not-found'), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(key: const Key('venue-back'), onPressed: () => _back(context), child: const Text('Back to venues')),
                ],
              ),
            ),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(key: const Key('venue-back'), tooltip: 'Back to venues', icon: const Icon(Icons.arrow_back), onPressed: () => _back(context)),
                    Expanded(child: Text(venue.name, key: const Key('venue-title'), style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    VenueStatusChip(status: venue.status),
                  ],
                ),
              ),
              const TabBar(tabs: [Tab(text: 'Bookings'), Tab(text: 'Setup'), Tab(text: 'Link')]),
              Expanded(
                child: TabBarView(
                  children: [
                    FloorScreen(venueId: venue.id, venueName: venue.name, showHeading: false),
                    VenueSetupList(venueId: venue.id, orgId: workspace.orgId),
                    BookingLinkCard(venue: venue),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
