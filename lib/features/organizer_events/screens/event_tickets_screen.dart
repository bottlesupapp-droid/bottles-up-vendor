import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/date_time_picker.dart';
import '../../owner/widgets/setup_common.dart' show confirmRemove;
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/event_tickets_rules.dart';
import '../logic/organizer_events_rules.dart';
import '../providers/organizer_events_providers.dart';
import '../services/organizer_events_service.dart';
import 'tier_form_screen.dart';

/// The ticket types of one event: what each costs, how many there are and have sold, and when sales open and close; add one, change one, remove one that
/// nobody has an order for. The database decides what is allowed (a sold type's name and price are fixed, an event that has ended is closed); this only says
/// it first, in plain words.
class EventTicketsScreen extends ConsumerStatefulWidget {
  const EventTicketsScreen({
    super.key,
    required this.orgId,
    required this.event,
    this.pickDateTime = pickDateAndTime,
    this.clock = DateTime.now,
  });

  final String orgId;
  final OrgEvent event;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<EventTicketsScreen> createState() => _EventTicketsScreenState();
}

class _EventTicketsScreenState extends ConsumerState<EventTicketsScreen> {
  ({String orgId, String eventId}) get _key => (
    orgId: widget.orgId,
    eventId: widget.event.eventId,
  );

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openForm(OrgTier? tier, List<OrgTier> all) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => TierFormScreen(
              orgId: widget.orgId,
              event: widget.event,
              tier: tier,
              others: all,
              pickDateTime: widget.pickDateTime,
              clock: widget.clock,
            ),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(organizerTiersProvider(_key));
    _say(tier == null ? 'Ticket type added.' : 'Ticket type saved.');
  }

  Future<void> _remove(OrgTier t) async {
    final yes = await confirmRemove(
      context,
      title: 'Remove ${t.name}?',
      body: 'The ticket type is deleted. This cannot be undone.',
    );
    if (!yes || !mounted) return;
    try {
      await ref
          .read(organizerTiersServiceProvider)
          .remove(widget.orgId, t.tierId);
      if (!mounted) return;
      ref.invalidate(organizerTiersProvider(_key));
      _say('Ticket type removed.');
    } on OrganizerEventsActionException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final now = widget.clock();
    final closed = ticketsLocked(widget.event, now);
    final tiers = ref.watch(organizerTiersProvider(_key));
    return Scaffold(
      appBar: AppBar(title: Text('Tickets: ${widget.event.title}')),
      body: tiers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final e =
              error is OrganizerEventsLoadException
                  ? error
                  : const OrganizerEventsLoadException(
                    unavailable: false,
                    accessEnded: false,
                  );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(BuSpace.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.unavailable
                        ? 'Tickets are not set up on this server yet.'
                        : e.accessEnded
                        ? e.message
                        : 'The ticket types could not be loaded. Check your connection and try again.',
                    key: const Key('tickets-error'),
                    textAlign: TextAlign.center,
                  ),
                  if (!e.unavailable) ...[
                    const SizedBox(height: BuSpace.m),
                    OutlinedButton(
                      key: const Key('tickets-retry'),
                      onPressed:
                          () => ref.invalidate(organizerTiersProvider(_key)),
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        data: (list) {
          final full = list.length >= TierLimits.perEvent;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              BuSpace.page,
              BuSpace.l,
              BuSpace.page,
              BuSpace.xl,
            ),
            children: [
              Text(
                closed
                    ? 'This event has ended, so its tickets can no longer be changed.'
                    : widget.event.isDraft
                    ? 'Set up what you sell. Guests see these once the BottlesUp team publishes the event.'
                    : 'These are on sale now. You can add ticket types and raise quantities; a type that has sold keeps its name and price.',
                key: const Key('tickets-intro'),
                style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted),
              ),
              const SizedBox(height: BuSpace.l),
              if (!closed)
                FilledButton.icon(
                  key: const Key('add-tier'),
                  onPressed: full ? null : () => _openForm(null, list),
                  icon: const Icon(Ionicons.add, size: 18),
                  label: const Text('Add ticket type'),
                ),
              if (!closed && full)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'An event can have at most ${TierLimits.perEvent} ticket types.',
                    key: const Key('tiers-full'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (list.isEmpty)
                BuCard(
                  key: const Key('no-tiers'),
                  margin: const EdgeInsets.only(top: BuSpace.l),
                  padding: const EdgeInsets.all(BuSpace.xl),
                  child: Text(
                    closed
                        ? 'No ticket types were set up for this event.'
                        : 'No ticket types yet. Add one to start selling.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final t in list)
                BuCard(
                  key: Key('tier-${t.tierId}'),
                  margin: const EdgeInsets.only(top: BuSpace.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              key: Key('tier-name-${t.tierId}'),
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTierPrice(t.priceCents),
                            key: Key('tier-price-${t.tierId}'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.soldCount} of ${t.capacity} sold · ${t.left} left',
                        key: Key('tier-sold-${t.tierId}'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        saleSummary(t, now),
                        key: Key('tier-sales-${t.tierId}'),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (t.hasSold || t.requiresAccessCode) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (t.hasSold)
                              DeskChip(
                                key: Key('tier-locked-${t.tierId}'),
                                text: 'Sold: name and price fixed',
                                color: bu.amber,
                              ),
                            if (t.requiresAccessCode)
                              DeskChip(
                                key: Key('tier-code-${t.tierId}'),
                                text: 'Needs an access code',
                                color: bu.orangeSoft,
                              ),
                          ],
                        ),
                      ],
                      if (!closed)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              key: Key('edit-tier-${t.tierId}'),
                              onPressed: () => _openForm(t, list),
                              child: const Text('Change'),
                            ),
                            if (!t.hasOrders)
                              TextButton(
                                key: Key('remove-tier-${t.tierId}'),
                                style: TextButton.styleFrom(
                                  foregroundColor: bu.red,
                                ),
                                onPressed: () => _remove(t),
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                      if (!closed && t.hasOrders)
                        Text(
                          'People have bought or started to buy this, so it cannot be removed. To stop selling it, change it and set when sales end.',
                          key: Key('tier-cannot-remove-${t.tierId}'),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
