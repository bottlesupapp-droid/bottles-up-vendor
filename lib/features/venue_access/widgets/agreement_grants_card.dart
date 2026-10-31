import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/access_rules.dart';
import '../providers/venue_access_providers.dart';
import 'grant_tile.dart';

/// On an agreement's page: what the club shares with the organizer under it, one thing at a time. The club (when the agreement is active) has a switch for each; the organizer sees the same
/// list and cannot change it. Things the database cannot supply yet (bar sales, chat, settlement) can be allowed and say "not available yet". Nothing is shown where the server does not have
/// this yet.
class AgreementGrantsCard extends ConsumerStatefulWidget {
  const AgreementGrantsCard({super.key, required this.agreementId, required this.side});

  final String agreementId;

  /// 'venue' or 'organizer': the side the person is on.
  final String side;

  @override
  ConsumerState<AgreementGrantsCard> createState() => _AgreementGrantsCardState();
}

class _AgreementGrantsCardState extends ConsumerState<AgreementGrantsCard> {
  bool _busy = false;

  ({String agreementId, String side}) get _q => (agreementId: widget.agreementId, side: widget.side);

  Future<void> _set(AccessKey key, bool allowed) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref.read(venueAccessServiceProvider).setGrant(widget.agreementId, key, allowed);
      if (!changed) messenger.showSnackBar(SnackBar(content: Text(allowed ? 'It was already shared.' : 'It was already not shared.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(agreementGrantsProvider(_q));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ref.watch(agreementGrantsProvider(_q)).when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) {
            final failure = opsLoadFailureFor(error, 'what the club shares');
            if (failure.unavailable) return const SizedBox.shrink();
            return Card(
              key: const Key('grants-error-card'),
              child: ListTile(
                title: Text(failure.message, key: const Key('grants-error')),
                trailing: failure.accessEnded ? null : TextButton(key: const Key('grants-retry'), onPressed: () => ref.invalidate(agreementGrantsProvider(_q)), child: const Text('Try again')),
              ),
            );
          },
          data: (g) {
            if (!g.inForce) return const SizedBox.shrink();
            final club = g.canChange;
            return Card(
              key: const Key('grants-card'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club ? 'What you share with the organizer' : 'What the club shares with you', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      club
                          ? 'Choose what the organizer of this event may see. You can change it at any time; nothing is shared until you allow it.'
                          : 'The club decides what you may see about this event.',
                      key: const Key('grants-intro'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    for (final grant in g.grants)
                      if (club)
                        SwitchListTile(
                          key: Key('grant-${grant.key.value}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(grant.key.label),
                          subtitle: Text(grant.allowed && !grant.available ? '${grant.key.explanation} Not available yet: it will show once the app can supply it.' : grant.key.explanation),
                          value: grant.allowed,
                          onChanged: _busy ? null : (v) => _set(grant.key, v),
                        )
                      else
                        GrantLine(grant: grant, idPrefix: 'grant-state'),
                  ],
                ),
              ),
            );
          },
        );
  }
}
