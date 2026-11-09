import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';

/// Tools for event organizers that the design has and the app does not: the overview with a branded banner, analytics, opportunities (roles
/// to post, applicants to shortlist), the public profile, posts and highlights, the flyer tool, and repeating events with promo codes.
/// Sample screens (see `preview_config.dart`); the layout follows the prototype's `Organizer.tsx`, `OrgTools.tsx`, `OrgProfile.tsx`, `EventParts.tsx`.

// ───────────────────────── Overview with the banner ─────────────────────────

class OrganizerOverviewPage extends StatelessWidget {
  const OrganizerOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvStandalone(
      title: 'Overview',
      child: PvPage(
        eyebrow: 'Midnight Social · private',
        title: 'Overview',
        trailing: FilledButton(onPressed: () => pvNotConnected(context), child: const Text('New event')),
        children: [
          // The branded banner: what guests see at the top of the organizer's page, built from the next events.
          Container(
            padding: const EdgeInsets.all(BuSpace.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BuRadius.hero),
              gradient: LinearGradient(colors: [bu.orange, const Color(0xFF2A0F0A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MIDNIGHT SOCIAL', style: text.labelSmall?.copyWith(color: Colors.white70, letterSpacing: 1.4)),
                const SizedBox(height: BuSpace.s),
                Text('Neon Garden', style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Sat, 31 Aug · Nova Room', style: text.bodyMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: BuSpace.l),
                Row(
                  children: [
                    const BuStatusPill('Published', tone: BuTone.good),
                    const Spacer(),
                    TextButton(onPressed: () => pvNotConnected(context), child: const Text('Edit banner', style: TextStyle(color: Colors.white))),
                  ],
                ),
              ],
            ),
          ),
          pvGap,
          PvList(const [
            PvRowData('Events', subtitle: '6 events · 3 published', icon: Ionicons.calendar_outline),
            PvRowData('Analytics', subtitle: 'Views, sales and earnings', icon: Ionicons.stats_chart_outline),
            PvRowData('Opportunities', subtitle: '2 new applications', icon: Ionicons.sparkles_outline, badge: 2),
            PvRowData('Team', subtitle: 'Door staff and collaborators', icon: Ionicons.people_outline),
          ]),
          pvGap,
          PvSection(title: 'Upcoming events', children: [
            PvList(const [
              PvRowData('Neon Garden', subtitle: 'Sat, 31 Aug · Nova Room', icon: Ionicons.calendar_outline, pill: 'Published', tone: BuTone.good),
              PvRowData('Rooftop Frequencies', subtitle: 'Fri, 6 Sep · Sky Room', icon: Ionicons.calendar_outline, pill: 'Draft'),
              PvRowData('Afterdark Sessions', subtitle: 'Sat, 21 Sep · Venue needed', icon: Ionicons.calendar_outline, pill: 'Draft'),
            ]),
          ]),
          PvSection(eyebrow: 'Needs attention', title: 'Four things', children: [
            PvList(const [
              PvRowData('Nova Room asked for changes', subtitle: 'Neon Garden · Nova Room replied', icon: Ionicons.ticket_outline, pill: 'Reply', tone: BuTone.attention),
              PvRowData('Door team not confirmed', subtitle: '2 of 3 door staff accepted', icon: Ionicons.id_card_outline, pill: 'Waiting', tone: BuTone.attention),
              PvRowData('Afterdark Sessions needs a venue', subtitle: "Draft · can't be submitted yet", icon: Ionicons.business_outline, pill: 'Action', tone: BuTone.attention),
              PvRowData('2 new applications', subtitle: 'Photographer · Neon Garden', icon: Ionicons.sparkles_outline, pill: 'New', tone: BuTone.brand),
            ]),
          ]),
          PvSection(title: 'Bookings and sales', children: [
            const PvLines([('Tickets sold', '242 across 3 events on sale'), ('Tables booked', '6 of 10 · Neon Garden'), ('Gross sales', '\$6,840')]),
            const SizedBox(height: BuSpace.s),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => pvNotConnected(context), child: const Text('See analytics'))),
          ]),
        ],
      ),
    );
  }
}

// ───────────────────────── Analytics ─────────────────────────

class OrganizerAnalyticsPage extends StatefulWidget {
  const OrganizerAnalyticsPage({super.key});

  @override
  State<OrganizerAnalyticsPage> createState() => _OrganizerAnalyticsPageState();
}

class _OrganizerAnalyticsPageState extends State<OrganizerAnalyticsPage> {
  String _event = 'Neon Garden';
  String _range = '7 days';

  @override
  Widget build(BuildContext context) {
    final week = _range == '7 days';
    final sales = week ? <double>[8, 6, 11, 14, 17, 22, 31] : <double>[22, 31, 44, 87];
    final labels = week ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'] : const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    final none = _event != 'Neon Garden';
    return PvStandalone(
      title: 'Analytics',
      child: PvPage(
        eyebrow: 'Midnight Social · private',
        title: 'Analytics',
        children: [
          PvFilterChips(labels: const ['Neon Garden', 'Spring Social', 'Afterdark Sessions'], initial: _event, onChanged: (v) => setState(() => _event = v)),
          const SizedBox(height: BuSpace.s),
          PvFilterChips(labels: const ['7 days', '30 days'], initial: _range, onChanged: (v) => setState(() => _range = v)),
          pvGap,
          if (none)
            const PvEmpty(icon: Ionicons.stats_chart_outline, title: 'No data yet', text: 'Numbers appear once the event is on sale.')
          else ...[
            PvSection(title: 'Ticket sales', children: [PvBars(values: sales, labels: labels, caption: week ? '31 tickets sold on Sunday, the best day this week.' : '87 tickets sold in the last week.')]),
            const PvSection(title: 'From views to bookings', children: [
              PvLines([('Event views', '9,800'), ('Started checkout', '412'), ('Booked', '190')]),
              PvNote('1.9% of viewers booked. 184 tickets and 6 tables. Referral links brought \$1,420.'),
            ]),
            const PvSection(title: 'Money', children: [
              PvLines([('Gross sales', '\$6,840'), ('Refunds', '− \$210'), ('Platform fees', '− \$547'), ('Net earnings', '\$6,083')], strongLast: true),
            ]),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Opportunities ─────────────────────────

class _Applicant {
  _Applicant(this.name, this.note, this.status);

  final String name;
  final String note;
  String status;
}

class _Opp {
  _Opp(this.role, this.event, this.date, this.pay, this.open, this.applicants);

  final String role;
  final String event;
  final String date;
  final String pay;
  final bool open;
  final List<_Applicant> applicants;
}

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  final List<_Opp> _opps = [
    _Opp('Photographer', 'Neon Garden', 'Sat, 31 Aug', '\$250 flat', true, [
      _Applicant('Priya Shah', 'Shot 30+ club nights. Portfolio on Instagram.', 'New'),
      _Applicant('Leo Park', 'Event photographer, 6 years.', 'New'),
    ]),
    _Opp('Warm-up DJ', 'Rooftop Frequencies', 'Fri, 6 Sep', '\$400', true, [_Applicant('KAIRO', 'Afro house, 2 h warm-up sets.', 'Shortlisted')]),
    _Opp('Ambassador', 'Neon Garden', 'Aug 20 – Aug 31', '10% of referred sales', false, []),
  ];

  void _applicants(_Opp o) {
    showPvSheet(
      context,
      eyebrow: 'Private · ${o.event}',
      title: '${o.role} applicants',
      child: StatefulBuilder(
        builder: (context, setSheet) {
          if (o.applicants.isEmpty) return const Text('No applications yet.');
          return BuListCard(
            children: [
              for (final a in o.applicants)
                Padding(
                  padding: const EdgeInsets.all(BuSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Expanded(child: Text(a.name, style: Theme.of(context).textTheme.titleSmall)), BuStatusPill(a.status, tone: a.status == 'Shortlisted' ? BuTone.good : (a.status == 'Declined' ? BuTone.neutral : BuTone.brand))]),
                      const SizedBox(height: 4),
                      Text(a.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.bu.muted)),
                      if (a.status == 'New') ...[
                        const SizedBox(height: BuSpace.m),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(key: Key('decline-${a.name}'), onPressed: () { a.status = 'Declined'; setSheet(() {}); setState(() {}); }, child: const Text('Decline'))),
                            const SizedBox(width: BuSpace.m),
                            Expanded(child: FilledButton(key: Key('shortlist-${a.name}'), onPressed: () { a.status = 'Shortlisted'; setSheet(() {}); setState(() {}); }, child: const Text('Shortlist'))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _post() {
    showPvSheet(
      context,
      eyebrow: 'New opportunity',
      title: 'Post a role',
      child: const Column(
        children: [
          PvFilterChips(labels: ['DJ', 'Photographer', 'Videographer', 'Host', 'Ambassador', 'Other']),
          SizedBox(height: BuSpace.l),
          PvField('Event', value: 'Neon Garden'),
          PvField('Date', hint: 'e.g. Sat, 31 Aug'),
          PvField('Compensation (optional)', hint: 'e.g. \$300 flat'),
          PvPrimary('Post role'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Opportunities',
      child: PvPage(
        eyebrow: 'Shown on your public profile',
        title: 'Opportunities',
        trailing: FilledButton(onPressed: _post, child: const Text('Post a role')),
        children: [
          PvList([
            for (final o in _opps)
              PvRowData(
                '${o.role} · ${o.event}',
                subtitle: '${o.date} · ${o.pay} · ${o.open ? 'Open' : 'Closed'}',
                icon: Ionicons.sparkles_outline,
                badge: o.applicants.where((a) => a.status == 'New').isEmpty ? null : o.applicants.where((a) => a.status == 'New').length,
                onTap: (_) => _applicants(o),
              ),
          ]),
          const PvNote('Applications are private. Only you see who applied.'),
        ],
      ),
    );
  }
}

// ───────────────────────── Public profile ─────────────────────────

class OrganizerProfilePage extends StatelessWidget {
  const OrganizerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvStandalone(
      title: 'Organizer profile',
      child: PvPage(
        eyebrow: 'Live preview',
        title: 'Organizer profile',
        intro: 'What guests see in the BottlesUp app.',
        children: [
          BuCard(
            padding: const EdgeInsets.all(BuSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BuEyebrow('Guest view · BottlesUp app'),
                const SizedBox(height: BuSpace.m),
                Row(
                  children: [
                    const PvAvatar('MS', size: 60),
                    const SizedBox(width: BuSpace.l),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Midnight Social', style: text.titleLarge), Text('Toronto · 4.9 (212 reviews)', style: text.bodySmall?.copyWith(color: bu.muted))])),
                  ],
                ),
                const SizedBox(height: BuSpace.m),
                Text('Rooftop and warehouse nights across Toronto. Afro house, amapiano and good company.', style: text.bodyMedium?.copyWith(color: bu.soft)),
                const SizedBox(height: BuSpace.m),
                const Row(children: [Expanded(child: PvSecondary('Follow')), SizedBox(width: BuSpace.m), Expanded(child: PvSecondary('Message'))]),
              ],
            ),
          ),
          pvGap,
          PvSection(eyebrow: 'Public details', title: 'About you', children: const [
            PvField('Name', value: 'Midnight Social'),
            PvField('About', value: 'Rooftop and warehouse nights across Toronto.', maxLines: 3, hint: 'What kind of nights do you throw?'),
          ]),
          PvSection(eyebrow: 'Links', title: 'Where guests can find you', children: const [
            PvField('Instagram', value: '@midnightsocial'),
            PvField('Website', value: 'midnightsocial.ca'),
          ]),
          const PvSection(eyebrow: 'Visibility', title: 'What to show', children: [
            PvSwitchCard(title: 'Past events', subtitle: 'Show recaps and attendance from past nights', initial: true),
            SizedBox(height: BuSpace.s),
            PvSwitchCard(title: 'Reviews', subtitle: 'Show your rating and guest reviews', initial: true),
            SizedBox(height: BuSpace.s),
            PvSwitchCard(title: 'Messages from guests', subtitle: 'Let guests message you from your profile', initial: true),
          ]),
          const PvPrimary('Save profile'),
        ],
      ),
    );
  }
}

// ───────────────────────── Posts and highlights ─────────────────────────

class ContentManagerPage extends StatelessWidget {
  const ContentManagerPage({super.key});

  void _comments(BuildContext context, String caption) {
    showPvSheet(
      context,
      eyebrow: 'Comments',
      title: caption,
      child: PvList(const [
        PvRowData("Saturday can't come soon enough", subtitle: 'Maya Chen · 2h', initials: 'MC'),
        PvRowData('Booked the Halo Booth for my 30th 🎉', subtitle: 'Jordan Ellis · 5h', initials: 'JE'),
        PvRowData('Is there a dress code?', subtitle: 'Sofia Bell · 1d', initials: 'SB'),
        PvRowData('Cheap followers, DM me', subtitle: 'promo_acct · 1d · looks like spam', initials: 'PA', pill: 'Review', tone: BuTone.attention),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Posts & highlights',
      child: PvPage(
        eyebrow: 'Midnight Social',
        title: 'Posts & highlights',
        trailing: FilledButton(onPressed: () => _newPost(context), child: const Text('New post')),
        children: [
          PvSection(eyebrow: 'Story highlights', title: 'Highlights', actionLabel: 'New', onAction: () => pvNotConnected(context), children: [
            const Wrap(spacing: BuSpace.s, runSpacing: BuSpace.s, children: [BuStatusPill('Recaps · 8 stories'), BuStatusPill('Lineups · 5 stories'), BuStatusPill('Venues · 3 stories')]),
          ]),
          PvSection(eyebrow: 'Feed', title: 'Your posts', children: [
            PvList([
              PvRowData('Lineup reveal: Neon Garden', subtitle: '412 likes · 38 comments · posted 2 days ago', icon: Ionicons.image_outline, onTap: (c) => _comments(c, 'Lineup reveal: Neon Garden')),
              PvRowData('Spring Social recap', subtitle: '1,204 likes · 96 comments · posted 3 weeks ago', icon: Ionicons.videocam_outline, onTap: (c) => _comments(c, 'Spring Social recap')),
              PvRowData('Warehouse Sessions: tickets live', subtitle: '230 likes · 14 comments · posted 1 week ago', icon: Ionicons.image_outline, onTap: (c) => _comments(c, 'Warehouse Sessions: tickets live')),
            ]),
          ]),
          PvSection(eyebrow: 'Tips', title: 'Grow your following', children: [
            PvList(const [
              PvRowData('Post a lineup reveal', subtitle: 'Lineup posts get 2× more saves', icon: Ionicons.bulb_outline),
              PvRowData('Add a Recaps highlight', subtitle: 'Guests check recaps before buying', icon: Ionicons.bulb_outline),
              PvRowData('Finish your profile', subtitle: 'Complete profiles get more follows', icon: Ionicons.bulb_outline),
            ]),
          ]),
        ],
      ),
    );
  }

  void _newPost(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'New post',
      title: 'Share with your followers',
      child: const Column(children: [PvField('Caption', maxLines: 3, hint: 'Say something about the night'), PvSecondary('Add a photo or video', icon: Ionicons.image_outline), SizedBox(height: BuSpace.m), PvPrimary('Post')]),
    );
  }
}

// ───────────────────────── Flyer tool ─────────────────────────

class FlyerToolPage extends StatefulWidget {
  const FlyerToolPage({super.key});

  @override
  State<FlyerToolPage> createState() => _FlyerToolPageState();
}

class _FlyerToolPageState extends State<FlyerToolPage> {
  String _template = 'Bold';
  String _align = 'Left';
  final _title = TextEditingController(text: 'Neon Garden');
  final _line = TextEditingController(text: 'Sat, 31 Aug · 9 PM');
  final _venue = TextEditingController(text: 'Nova Room');

  static const Map<String, (Color, Color, Color)> _colors = {
    'Bold': (Color(0xFFFF5A2F), Color(0xFF2A0F0A), Colors.white),
    'Minimal': (Color(0xFFF2EFE9), Color(0xFFD9D3C7), Color(0xFF141414)),
    'Neon': (Color(0xFF14002B), Color(0xFFFF2D95), Colors.white),
  };

  @override
  void dispose() {
    _title.dispose();
    _line.dispose();
    _venue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (a, b, ink) = _colors[_template]!;
    final center = _align == 'Center';
    return PvStandalone(
      title: 'Flyer tool',
      child: PvPage(
        eyebrow: 'Neon Garden',
        title: 'Flyer',
        intro: 'Make a flyer for social media. Export it as a 1080 × 1350 image.',
        children: [
          PvFilterChips(labels: const ['Bold', 'Minimal', 'Neon'], initial: _template, onChanged: (v) => setState(() => _template = v)),
          pvGap,
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              key: const Key('flyer-preview'),
              padding: const EdgeInsets.all(BuSpace.xl),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(BuRadius.card), gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(_title.text.isEmpty ? 'Event name' : _title.text, textAlign: center ? TextAlign.center : TextAlign.start, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: BuSpace.s),
                  Text(_line.text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ink)),
                  Text(_venue.text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ink)),
                ],
              ),
            ),
          ),
          pvGap,
          TextField(controller: _title, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Event name')),
          const SizedBox(height: BuSpace.m),
          TextField(controller: _line, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Date and time')),
          const SizedBox(height: BuSpace.m),
          TextField(controller: _venue, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Venue')),
          pvGap,
          PvFilterChips(labels: const ['Left', 'Center'], initial: _align, onChanged: (v) => setState(() => _align = v)),
          pvGap,
          const PvSecondary('Use my own picture', icon: Ionicons.image_outline),
          const SizedBox(height: BuSpace.s),
          const PvPrimary('Export image', icon: Ionicons.download_outline),
        ],
      ),
    );
  }
}

// ───────────────────────── Repeating events and promo codes ─────────────────────────

class RepeatAndPromosPage extends StatefulWidget {
  const RepeatAndPromosPage({super.key});

  @override
  State<RepeatAndPromosPage> createState() => _RepeatAndPromosPageState();
}

class _RepeatAndPromosPageState extends State<RepeatAndPromosPage> {
  bool _repeat = true;
  String _every = 'Weekly';

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return PvStandalone(
      title: 'Repeats and promos',
      child: PvPage(
        eyebrow: 'Event builder',
        title: 'Repeats and promo codes',
        intro: 'Two parts of the event builder the app does not have yet. Tickets and tiers are already in the app.',
        children: [
          PvSection(eyebrow: 'Schedule', title: 'Repeating event', children: [
            BuCard(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: BuSpace.s + 2),
              child: Row(children: [const Expanded(child: Text('This event repeats')), Switch(key: const Key('repeat-switch'), value: _repeat, onChanged: (v) => setState(() => _repeat = v))]),
            ),
            if (_repeat) ...[
              const SizedBox(height: BuSpace.m),
              PvFilterChips(labels: const ['Weekly', 'Every 2 weeks', 'Monthly'], initial: _every, onChanged: (v) => setState(() => _every = v)),
              const SizedBox(height: BuSpace.m),
              const PvFilterChips(labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], initial: 'Sat'),
              const SizedBox(height: BuSpace.m),
              const PvField('Ends after', value: '8 events'),
              Text('Next dates: Sat 31 Aug, Sat 7 Sep, Sat 14 Sep, Sat 21 Sep and 4 more.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted)),
              const PvNote('Each date has its own tickets, guest list, tables, staff and report.'),
            ],
          ]),
          PvSection(
            eyebrow: 'Sales',
            title: 'Promo codes',
            actionLabel: 'Add code',
            onAction: () => showPvSheet(
              context,
              eyebrow: 'Promo code',
              title: 'Add a promo code',
              child: const Column(children: [
                PvField('Code', hint: 'e.g. GARDEN10'),
                PvFilterChips(labels: ['% off', '\$ off']),
                SizedBox(height: BuSpace.m),
                PvField('Amount', value: '10'),
                PvField('Uses allowed', value: '100'),
                PvField('Ends', hint: 'Date'),
                PvSwitchCard(title: 'Also applies to tables'),
                SizedBox(height: BuSpace.l),
                PvPrimary('Save code'),
              ]),
            ),
            children: [
              PvList(const [
                PvRowData('GARDEN10', subtitle: '10% off tickets · 24 of 100 used', icon: Ionicons.pricetag_outline, pill: 'Active', tone: BuTone.good),
                PvRowData('EARLYBIRD', subtitle: '\$5 off · 50 of 50 used', icon: Ionicons.pricetag_outline, pill: 'Used up'),
                PvRowData('CREW20', subtitle: '20% off · ambassadors only', icon: Ionicons.pricetag_outline, pill: 'Active', tone: BuTone.good),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
