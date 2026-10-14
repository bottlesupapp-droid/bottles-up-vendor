import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../workspace/models/role_navigation.dart';
import '../../workspace/models/workspace.dart';
import '../providers/owner_providers.dart';
import '../services/owner_service.dart';
import '../widgets/add_venue_dialog.dart';
import '../widgets/venue_setup_list.dart';
import '../widgets/venue_status_chip.dart';

/// Opens a venue. Replaced in tests; in the app it pushes the venue's own page onto the workspace's navigation.
typedef OpenVenue = void Function(BuildContext context, String membershipId, String venueId);

void openVenueInRouter(BuildContext context, String membershipId, String venueId) {
  context.push(workspaceVenuePath(membershipId, venueId));
}

/// Venues (owner): every venue of the business with how far it is set up, and a way to add one. Tapping a venue opens its
/// bookings, setup checklist and booking link. Claiming a venue that is already on BottlesUp, editing floor plans and the menu,
/// and taking a venue live are not done here yet.
class OwnerVenuesScreen extends ConsumerStatefulWidget {
  const OwnerVenuesScreen({super.key, required this.workspace, this.onOpenVenue = openVenueInRouter});

  final Workspace workspace;
  final OpenVenue onOpenVenue;

  @override
  ConsumerState<OwnerVenuesScreen> createState() => _OwnerVenuesScreenState();
}

class _OwnerVenuesScreenState extends ConsumerState<OwnerVenuesScreen> {
  bool _adding = false;

  Future<void> _add() async {
    final name = await showDialog<String>(context: context, builder: (_) => const AddVenueDialog());
    if (name == null || !mounted) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(ownerServiceProvider).createVenue(widget.workspace.orgId, name);
      ref.invalidate(ownerVenuesProvider(widget.workspace.orgId));
      messenger.showSnackBar(SnackBar(content: Text('$name added.')));
    } on OwnerActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orgId = widget.workspace.orgId;
    final venues = ref.watch(ownerVenuesProvider(orgId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerVenuesProvider(orgId));
        try {
          await ref.read(ownerVenuesProvider(orgId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Venues', style: theme.textTheme.headlineSmall),
          Text(widget.workspace.orgName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          venues.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = error is OwnerLoadException ? error : const OwnerLoadException(unavailable: false, accessEnded: false);
              return Column(
                children: [
                  Text(e.message, key: const Key('venues-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(key: const Key('venues-retry'), onPressed: () => ref.invalidate(ownerVenuesProvider(orgId)), child: const Text('Try again')),
                    ),
                ],
              );
            },
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list.isEmpty)
                  Container(
                    key: const Key('no-venues'),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(14)),
                    child: Text('No venues yet. Add your first venue to start setting it up.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                  ),
                for (final v in list)
                  Card(
                    key: Key('venue-${v.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onOpenVenue(context, widget.workspace.membershipId, v.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(v.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                VenueStatusChip(status: v.status),
                              ],
                            ),
                            if (v.address != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(v.address!, style: theme.textTheme.bodySmall)),
                            const SizedBox(height: 10),
                            SetupProgress(venueId: v.id),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('add-venue'),
                  onPressed: _adding ? null : _add,
                  child: Text(_adding ? 'Adding…' : 'Add a venue'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Claiming a venue that is already on BottlesUp is done on the website for now.',
                  key: const Key('venues-footnote'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
