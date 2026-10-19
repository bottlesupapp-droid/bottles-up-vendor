import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/screens/tonight_screen.dart';
import '../../workspace/models/workspace.dart';
import '../providers/owner_providers.dart';
import '../services/owner_service.dart';

/// Tonight (owner): run tonight at ONE of the owner's venues (brief, sections 6 and 7: "Owners open a venue for operations"). It is the
/// manager's Tonight for the venue picked here: what needs attention, the floor, orders, payments to check, closing the night. The database
/// treats an owner of the business as a manager of each of its venues, so nothing new is allowed; with one venue it opens straight away.
class OwnerTonightScreen extends ConsumerStatefulWidget {
  const OwnerTonightScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;

  @override
  ConsumerState<OwnerTonightScreen> createState() => _OwnerTonightScreenState();
}

class _OwnerTonightScreenState extends ConsumerState<OwnerTonightScreen> {
  String? _venueId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orgId = widget.workspace.orgId;
    final venues = ref.watch(ownerVenuesProvider(orgId));

    return venues.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final e = error is OwnerLoadException ? error : const OwnerLoadException(unavailable: false, accessEnded: false);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.message, key: const Key('owner-tonight-error'), textAlign: TextAlign.center),
                if (!e.unavailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(key: const Key('owner-tonight-retry'), onPressed: () => ref.invalidate(ownerVenuesProvider(orgId)), child: const Text('Try again')),
                ],
              ],
            ),
          ),
        );
      },
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No venues yet. Add a venue on the Venues tab, then run the night from here.',
                key: const Key('owner-tonight-empty'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          );
        }
        final chosen = list.firstWhere((v) => v.id == _venueId, orElse: () => list.first);
        return Column(
          children: [
            if (list.length > 1)
              SizedBox(
                height: 56,
                child: ListView(
                  key: const Key('owner-tonight-venues'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    for (final v in list)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('owner-tonight-venue-${v.id}'),
                          label: Text(v.name),
                          selected: v.id == chosen.id,
                          onSelected: (_) => setState(() => _venueId = v.id),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              // A different venue is a fresh screen, so nothing in progress for one venue (a close, a form) can leak into another.
              child: TonightScreen(key: ValueKey('tonight-${chosen.id}'), workspace: widget.workspace.atVenue(chosen.id, chosen.name), clock: widget.clock),
            ),
          ],
        );
      },
    );
  }
}
