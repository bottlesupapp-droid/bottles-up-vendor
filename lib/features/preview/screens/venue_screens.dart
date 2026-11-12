import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';
import 'inbox_screens.dart';

/// Tools for a venue owner or manager that the design has and the app does not: what is behind the Overview numbers, the failed-payout
/// state, a Messages centre (customers, team, requests), a booking's passes, pre-orders and refund, and the venue's own events (one-time and
/// weekly). Sample screens (see `preview_config.dart`); the layout follows the prototype's `OwnerStats.tsx`, `Owner.tsx`, `Messages.tsx`,
/// `Guests.tsx` and `VenueOps.tsx`.

// ───────────────────────── What is behind the Overview numbers ─────────────────────────

class OverviewNumbersPage extends StatefulWidget {
  const OverviewNumbersPage({super.key, this.initial = 'Expected'});

  final String initial;

  @override
  State<OverviewNumbersPage> createState() => _OverviewNumbersPageState();
}

class _OverviewNumbersPageState extends State<OverviewNumbersPage> {
  late String _view = widget.initial;
  String _sales = 'Breakdown';

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Overview numbers',
      child: PvPage(
        eyebrow: 'Nova Room · Saturday, 24 August',
        title: _view,
        intro: 'Tap a number on the Overview to see what it is made of.',
        children: [
          PvFilterChips(labels: const ['Expected', 'Arrived', 'Sales'], initial: _view, onChanged: (v) => setState(() => _view = v)),
          pvGap,
          if (_view == 'Expected') ..._expected(),
          if (_view == 'Arrived') ..._arrived(context),
          if (_view == 'Sales') ..._sales_(),
        ],
      ),
    );
  }

  List<Widget> _expected() => const [
        PvHero(eyebrow: 'People expected', title: '186', subtitle: 'Table guests, the guest list and tickets, each person once.'),
        SizedBox(height: BuSpace.l),
        PvLines([
          ('Table reservations', '104 guests · 18 bookings'),
          ('Tickets sold', '50 · 6 also on a table'),
          ('Guest list', '38 names'),
          ('Not included', 'Cancelled and refunded passes, walk-ins'),
          ('Total', '186 people'),
        ], strongLast: true),
      ];

  List<Widget> _arrived(BuildContext context) => const [
        PvHero(eyebrow: 'Checked in', title: '96 of 186', subtitle: '52% of the people expected.', trailing: BuRing(value: 96 / 186, center: '52%', caption: 'arrived')),
        SizedBox(height: BuSpace.l),
        PvSection(title: 'By hour', children: [PvBars(values: [14, 31, 51], labels: ['7–8 PM', '8–9 PM', '9–10 PM'])]),
        PvLines([
          ('Checked in', '96 of 186 expected (52%)'),
          ('Main entrance', '79'),
          ('VIP entrance', '17'),
          ('Walk-ins', '9 · included above'),
          ('Last check-in', '9:42 PM'),
        ]),
      ];

  List<Widget> _sales_() => [
        const PvHero(eyebrow: 'Sales so far tonight', title: '\$4,340', subtitle: '+6.1% on last Saturday at this time.'),
        pvGap,
        PvFilterChips(labels: const ['Breakdown', 'Payouts'], initial: _sales, onChanged: (v) => setState(() => _sales = v)),
        pvGap,
        if (_sales == 'Breakdown') ...const [
          PvSection(title: 'Where it came from', children: [PvLines([('Card', '\$3,180'), ('Cash', '\$560'), ('Prepaid bookings', '\$600')])]),
          PvSection(title: 'From gross to earnings', children: [
            PvLines([
              ('Gross sales', '\$4,340.00'),
              ('Refunds', '− \$150.00'),
              ('Card processing (2.9%)', '− \$92.22'),
              ('Platform fee (3% of prepaid)', '− \$18.00'),
              ('Earnings', '\$4,079.78'),
            ], strongLast: true),
          ]),
        ] else ...const [
          PvSection(title: 'Payouts', children: [
            PvLines([('Next payout', 'Thu, 22 August'), ('Sent to', 'Bank account ending 4021'), ('Last payout', '\$9,420.00 · Tue, 20 August')]),
            PvNote('Payouts are made by BottlesUp after each closed night.'),
          ]),
        ],
      ];
}

// ───────────────────────── A payout that did not go through ─────────────────────────

/// A failed payout is the scariest moment for an owner, so the card says exactly what happened, that the money is safe, and the one thing
/// to do next.
class PayoutIssuePage extends StatefulWidget {
  const PayoutIssuePage({super.key});

  @override
  State<PayoutIssuePage> createState() => _PayoutIssuePageState();
}

class _PayoutIssuePageState extends State<PayoutIssuePage> {
  String _state = 'failed';
  String _last4 = '4021';

  void _bankForm() {
    showPvSheet(
      context,
      eyebrow: 'Payout account',
      title: 'Update bank account',
      child: Column(
        children: [
          const PvField('Account holder', value: 'Northstar Hospitality Inc.'),
          const PvField('Transit number', hint: '5 digits'),
          const PvField('Institution number', hint: '3 digits'),
          const PvField('Account number', hint: '6 to 17 digits'),
          FilledButton(
            key: const Key('save-bank'),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _last4 = '7733';
                _state = 'sent';
              });
            },
            child: const Text('Save and send the payout again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvStandalone(
      title: 'Payments',
      child: PvPage(
        eyebrow: 'Northstar Hospitality',
        title: 'Payments',
        children: [
          if (_state == 'sent')
            BuCard(
              key: const Key('payout-sent'),
              accent: bu.green,
              child: Row(
                children: [
                  BuIconTile(icon: Ionicons.checkmark, color: bu.green, background: bu.green.withValues(alpha: 0.12)),
                  const SizedBox(width: BuSpace.m),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('\$9,420 sent to bank ending $_last4', style: text.titleSmall), Text('Arrives by Thursday, 22 August. Nothing else to do.', style: text.bodySmall?.copyWith(color: bu.muted))])),
                ],
              ),
            )
          else
            BuCard(
              key: const Key('payout-failed'),
              accent: bu.amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BuIconTile(icon: Ionicons.warning_outline, color: bu.amber, background: bu.amber.withValues(alpha: 0.12)),
                      const SizedBox(width: BuSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Payout of \$9,420 didn't go through", style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text('Tue, Aug 20 · Your bank returned it because the account ending $_last4 is closed.', style: text.bodySmall?.copyWith(color: bu.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BuSpace.m),
                  Row(children: [Icon(Ionicons.lock_closed_outline, size: 14, color: bu.green), const SizedBox(width: 6), Expanded(child: Text("Your money is safe. It's held in your BottlesUp balance until you choose where it goes.", style: text.bodySmall))]),
                  const SizedBox(height: BuSpace.l),
                  FilledButton(key: const Key('fix-bank'), onPressed: _bankForm, child: const Text('Fix bank details')),
                  const SizedBox(height: BuSpace.s),
                  OutlinedButton(onPressed: _support, child: const Text('Contact support')),
                ],
              ),
            ),
          pvGap,
          PvSection(title: 'Recent payouts', children: [
            PvList([
              PvRowData('Payout PO-20824', subtitle: 'Tue, Aug 20 · \$9,420', icon: Ionicons.cash_outline, pill: _state == 'sent' ? 'Sent' : 'Failed', tone: _state == 'sent' ? BuTone.good : BuTone.attention),
              const PvRowData('Payout PO-20711', subtitle: 'Tue, Aug 13 · \$8,150', icon: Ionicons.cash_outline, pill: 'Paid', tone: BuTone.good),
              const PvRowData('Payout PO-20602', subtitle: 'Tue, Aug 6 · \$7,980', icon: Ionicons.cash_outline, pill: 'Paid', tone: BuTone.good),
            ]),
          ]),
          const PvNote('The app already shows payouts, read only. Fixing the bank account from the app is what this adds.'),
        ],
      ),
    );
  }

  void _support() {
    showPvSheet(
      context,
      eyebrow: 'Support',
      title: 'Payout help',
      child: const PvLines([('Payout', 'PO-20824 · \$9,420'), ('Reason', 'Account closed (bank code R02)'), ('Typical reply', 'Under 1 hour, 24/7')]),
    );
  }
}

// ───────────────────────── Messages centre ─────────────────────────

class MessagesCenterPage extends StatefulWidget {
  const MessagesCenterPage({super.key});

  @override
  State<MessagesCenterPage> createState() => _MessagesCenterPageState();
}

class _MessagesCenterPageState extends State<MessagesCenterPage> {
  String _tab = 'Customers';

  static const _customers = [
    ('Maya Chen', 'Table enquiry · Sat, 24 Aug', 'Can we move to a bigger table for 8?', 1),
    ('Jordan Ellis', 'Booking · Table 12', 'Thanks! Is the minimum spend per table?', 0),
    ('Priya Shah', 'Guest · Neon Garden', 'Do you allow a birthday cake?', 2),
  ];
  static const _team = [
    ('Door team', 'Group · 6 members', 'Jamie: VIP list is final.', 0),
    ('Servers: main floor', 'Group · 9 members', 'Sam: Table 4 wants the next round.', 3),
    ('Jordan Blake', 'Manager · direct', 'Can you cover the early shift?', 0),
  ];

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final rows = _tab == 'Customers' ? _customers : _team;
    return PvStandalone(
      title: 'Messages',
      child: PvPage(
        eyebrow: 'Nova Room',
        title: 'Messages',
        children: [
          PvFilterChips(labels: const ['Customers', 'Team', 'Requests'], counts: const {'Customers': 3, 'Team': 3, 'Requests': 2}, initial: _tab, onChanged: (v) => setState(() => _tab = v)),
          const SizedBox(height: BuSpace.m),
          Text(
            switch (_tab) {
              'Customers' => 'Guests, table enquiries and bookings.',
              'Team' => 'Staff and managers. Only invited members can read these.',
              _ => 'Help, bottle signs and refunds your staff are asking for.',
            },
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted),
          ),
          pvGap,
          if (_tab == 'Requests')
            PvList(const [
              PvRowData('Ask for a change', subtitle: 'Sam asked to swap table 4 and 6 · 12 min ago', icon: Ionicons.swap_horizontal_outline, pill: 'Help', tone: BuTone.attention),
              PvRowData('Bottle sign: "Happy 30th Maya"', subtitle: 'Table 12 · waiting for approval', icon: Ionicons.create_outline, pill: 'Sign', tone: BuTone.brand),
              PvRowData('Refund request', subtitle: 'Priya Shah · \$180 deposit · 1 h ago', icon: Ionicons.arrow_undo_outline, pill: 'Refund', tone: BuTone.attention),
            ])
          else
            PvList([
              for (final r in rows)
                PvRowData(
                  r.$1,
                  subtitle: '${r.$2}\n${r.$3}',
                  initials: r.$1.substring(0, 2),
                  badge: r.$4 > 0 ? r.$4 : null,
                  onTap: (c) => pvOpen<void>(c, PvChatPage(title: r.$1, subtitle: r.$2, messages: [PvChatMessage(false, r.$3, '9:12 PM', who: r.$1.split(' ').first), const PvChatMessage(true, 'On it. Back to you in a minute.', '9:14 PM')])),
                ),
            ]),
        ],
      ),
    );
  }
}

// ───────────────────────── A booking's passes, pre-orders and refund ─────────────────────────

class BookingExtrasPage extends StatelessWidget {
  const BookingExtrasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Booking',
      child: PvPage(
        eyebrow: 'Maya Chen · Table 12',
        title: 'Booking details',
        trailing: const BuStatusPill('Confirmed', tone: BuTone.good),
        children: [
          const PvLines([('Date', 'Sat, 24 Aug · 9:00 PM'), ('Guests', '6'), ('Deposit', '\$500 paid by card'), ('Minimum spend', '\$1,500')]),
          pvGap,
          PvSection(eyebrow: 'Guests', title: 'Passes', actionLabel: 'Resend all', onAction: () => pvNotConnected(context), children: [
            PvList(const [
              PvRowData('Maya Chen', subtitle: 'Host · pass claimed', initials: 'MC', pill: 'Claimed', tone: BuTone.good),
              PvRowData('Jordan Ellis', subtitle: 'Pass claimed', initials: 'JE', pill: 'Claimed', tone: BuTone.good),
              PvRowData('Priya Shah', subtitle: 'Pass claimed', initials: 'PS', pill: 'Claimed', tone: BuTone.good),
              PvRowData('sam@example.com', subtitle: 'Invited · not claimed yet', initials: 'SA', pill: 'Invited', tone: BuTone.attention),
            ]),
          ]),
          PvSection(eyebrow: 'Before they arrive', title: 'Pre-orders', children: [
            const PvLines([('Grey Goose × 1', '\$280'), ('Moët & Chandon × 2', '\$360'), ('Mixers and ice', 'Included'), ('Pre-order total', '\$640')], strongLast: true),
          ]),
          PvSection(eyebrow: 'Bottle sign', title: 'Sign', children: [
            PvList(const [PvRowData('"Happy 30th Maya"', subtitle: 'Approved by the manager', icon: Ionicons.create_outline, pill: 'Approved', tone: BuTone.good)]),
            const SizedBox(height: BuSpace.s),
            const PvSecondary('Ask for a change'),
          ]),
          PvSection(eyebrow: 'Refunds', title: 'Cancel this booking', children: [
            const PvLines([('Policy', 'Full deposit back up to 48 hours before'), ('If cancelled now', '\$500 refunded to the card')]),
            const SizedBox(height: BuSpace.m),
            PvSecondary('Cancel booking', icon: Ionicons.close_circle_outline, onPressed: (c) => _cancel(c)),
          ]),
        ],
      ),
    );
  }

  static void _cancel(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'Maya Chen · Table 12',
      title: 'Cancel booking',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PvFilterChips(labels: ['Guest asked', 'Table unavailable', 'Double booked', 'Other']),
          SizedBox(height: BuSpace.l),
          PvLines([('Refund to the guest', '\$500'), ('Guests told', 'Maya and 3 others')]),
          PvNote('The guest and everyone with a pass is told by email.'),
          PvPrimary('Cancel booking and refund'),
        ],
      ),
    );
  }
}

// ───────────────────────── The venue's own events ─────────────────────────

class VenueEventsPage extends StatefulWidget {
  const VenueEventsPage({super.key});

  @override
  State<VenueEventsPage> createState() => _VenueEventsPageState();
}

class _VenueEventsPageState extends State<VenueEventsPage> {
  String _when = 'Upcoming';

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Venue events',
      child: PvPage(
        eyebrow: 'Nova Room',
        title: 'Events',
        trailing: FilledButton(onPressed: () => _create(context), child: const Text('Create event')),
        children: [
          PvFilterChips(labels: const ['Upcoming', 'Past'], initial: _when, onChanged: (v) => setState(() => _when = v)),
          pvGap,
          if (_when == 'Upcoming')
            PvList([
              PvRowData('Nova Saturdays', subtitle: 'Every Saturday · 9 PM – 2 AM · 8 dates', icon: Ionicons.repeat_outline, pill: 'Weekly', tone: BuTone.brand, onTap: (c) => _dates(c)),
              PvRowData('Neon Garden (Midnight Social)', subtitle: 'Sat, 31 Aug · organizer event', icon: Ionicons.calendar_outline, pill: 'Published', tone: BuTone.good),
              PvRowData('Halloween Takeover', subtitle: 'Thu, 31 Oct · one-time', icon: Ionicons.calendar_outline, pill: 'Draft'),
            ])
          else
            PvList(const [
              PvRowData('Spring Social', subtitle: 'Sat, 20 Jul · 210 of 220 sold', icon: Ionicons.calendar_outline, pill: 'Completed', tone: BuTone.good),
              PvRowData('Nova Saturdays', subtitle: '14 dates held', icon: Ionicons.repeat_outline, pill: 'Series'),
            ]),
          const PvNote('The app has events for organizers. This is the venue creating its own, one-time or weekly.'),
        ],
      ),
    );
  }

  void _dates(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'Nova Saturdays',
      title: 'Sat, 24 Aug',
      child: const Column(
        children: [
          PvLines([('Tickets', '112 of 300 sold'), ('Guest list', '38 names'), ('Tables', '18 booked'), ('Staff', '12 on shift'), ('Report', 'Closes after the night')]),
          SizedBox(height: BuSpace.l),
          PvFilterChips(labels: ['Sat, 24 Aug', 'Sat, 31 Aug', 'Sat, 7 Sep']),
        ],
      ),
    );
  }

  void _create(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'New event',
      title: 'Create an event',
      child: const Column(
        children: [
          PvField('Event name', hint: 'e.g. Nova Saturdays'),
          PvFilterChips(labels: ['One-time', 'Weekly']),
          SizedBox(height: BuSpace.m),
          PvField('Event date', hint: 'Date'),
          PvField('Doors', value: '9:00 PM'),
          PvField('Ends', value: '2:00 AM'),
          PvPrimary('Create event'),
        ],
      ),
    );
  }
}
