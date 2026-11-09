import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';
import '../widgets/pv_mini_app.dart';
import 'app_wide_screens.dart';

/// Ambassador (shares an organizer's events and earns commission on the tickets sold with their link) and Event Lead (leads the ambassadors of
/// an event). Sample screens (see `preview_config.dart`); the layout follows the prototype's `Roles.tsx`.

const _link = 'bottlesup.com/e/neon-garden?ref=ALEX20';

PvTab _tab(String label, IconData icon, IconData active, WidgetBuilder b) => PvTab(label: label, icon: icon, activeIcon: active, builder: b);

PvMiniAppConfig get ambassadorApp => PvMiniAppConfig(
      id: 'ambassador',
      role: 'Ambassador',
      org: 'Midnight Social',
      scope: 'Alex Morgan · referrals',
      tabs: [
        _tab('Home', Ionicons.home_outline, Ionicons.home, (_) => const _AmbassadorHome()),
        _tab('Events', Ionicons.calendar_outline, Ionicons.calendar, (_) => const _AssignedEvents(lead: false)),
        _tab('Share', Ionicons.share_social_outline, Ionicons.share_social, (_) => const _SharePage()),
        _tab('Earnings', Ionicons.cash_outline, Ionicons.cash, (_) => const _EarningsPage(team: false)),
        _tab('More', Ionicons.menu_outline, Ionicons.menu, (_) => const _RoleMore(role: 'Ambassador', place: 'Midnight Social · Ambassador', hours: "Flexible · events you're assigned to")),
      ],
    );

PvMiniAppConfig get eventLeadApp => PvMiniAppConfig(
      id: 'event-lead',
      role: 'Event Lead',
      org: 'Neon Garden',
      scope: 'Event team',
      tabs: [
        _tab('Overview', Ionicons.home_outline, Ionicons.home, (_) => const _LeadOverview()),
        _tab('Events', Ionicons.calendar_outline, Ionicons.calendar, (_) => const _AssignedEvents(lead: true)),
        _tab('Team', Ionicons.people_outline, Ionicons.people, (_) => const _LeadTeam()),
        _tab('Earnings', Ionicons.cash_outline, Ionicons.cash, (_) => const _EarningsPage(team: true)),
        _tab('More', Ionicons.menu_outline, Ionicons.menu, (_) => const _RoleMore(role: 'Event Lead', place: 'Neon Garden · Event Lead', hours: 'Event night: Sat, 31 August · 8:00 PM – 2:30 AM')),
      ],
    );

// ───────────────────────── Ambassador ─────────────────────────

class _AmbassadorHome extends StatelessWidget {
  const _AmbassadorHome();

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return PvPage(
      eyebrow: 'Ambassador',
      title: 'Performance',
      trailing: TextButton(onPressed: () => _shareSheet(context), child: Text('Share event', style: TextStyle(color: bu.orangeSoft))),
      children: [
        const PvHero(
          eyebrow: 'This month · sample',
          title: '\$428.00 confirmed',
          subtitle: 'From 50 referred ticket sales and 3 bookings.',
          trailing: BuRing(value: 50 / 70, center: '71%', caption: 'of target'),
        ),
        pvGap,
        const PvStatGrid([
          PvStat('1,284', 'Link visits', hint: '+18% this week'),
          PvStat('50', 'Ticket sales', hint: '3.9% conversion'),
          PvStat('71%', 'Target', hint: '50 of 70 sales'),
          PvStat('#3', 'Rank', hint: 'of 18 ambassadors'),
        ]),
        PvSection(eyebrow: 'Next event', title: 'Neon Garden', children: [
          PvList([
            PvRowData('Saturday, 31 August', subtitle: '184 sold · 7 days away', icon: Ionicons.calendar_outline, onTap: (c) => _eventSheet(c, 'Neon Garden')),
            const PvRowData('Your referral link', subtitle: '32 sales · \$256 confirmed', icon: Ionicons.share_social_outline),
          ]),
        ]),
      ],
    );
  }
}

const _eventSummary = <String, List<(String, String)>>{
  'Neon Garden': [('Date', 'Sat, 31 August'), ('Venue', 'Nova Room'), ('Tickets sold', '184 of 300'), ('Your referral sales', '32')],
  'Rooftop Frequencies': [('Date', 'Fri, 6 September'), ('Venue', 'Sky Room · partnership requested'), ('Status', 'Draft · sharing opens when it goes live')],
  'Afterdark Sessions': [('Date', 'Sat, 21 September'), ('Venue', 'Not chosen yet'), ('Status', 'Draft · sharing opens when tickets go on sale')],
};

void _eventSheet(BuildContext context, String name) {
  showPvSheet(
    context,
    eyebrow: 'Assigned event',
    title: name,
    child: Column(children: [
      PvLines(_eventSummary[name]!),
      if (name == 'Neon Garden') ...[pvGap, const _ShareOptions()],
    ]),
  );
}

void _shareSheet(BuildContext context) => showPvSheet(context, eyebrow: 'Neon Garden', title: 'Share event', child: const _ShareOptions());

class _ShareOptions extends StatelessWidget {
  const _ShareOptions();

  void _copy(BuildContext context, String value, String done) {
    Clipboard.setData(ClipboardData(text: value));
    pvNotConnected(context, done);
  }

  @override
  Widget build(BuildContext context) {
    return PvList([
      PvRowData('Copy link', subtitle: _link, icon: Ionicons.copy_outline, onTap: (c) => _copy(c, 'https://$_link', 'Referral link copied')),
      PvRowData('Copy message', subtitle: 'Ready to paste into a post or chat', icon: Ionicons.chatbubble_outline, onTap: (c) => _copy(c, 'Neon Garden is on Sat, 31 August at Nova Room. Get tickets with my code ALEX20: https://$_link', 'Message copied')),
      PvRowData('Copy code', subtitle: 'ALEX20', icon: Ionicons.ticket_outline, onTap: (c) => _copy(c, 'ALEX20', 'Code copied')),
    ]);
  }
}

class _AssignedEvents extends StatelessWidget {
  const _AssignedEvents({required this.lead});

  final bool lead;

  @override
  Widget build(BuildContext context) {
    return PvPage(
      eyebrow: lead ? 'Assigned' : 'Midnight Social',
      title: lead ? 'Events' : 'Assigned events',
      children: [
        PvList([
          PvRowData('Neon Garden', subtitle: lead ? '31 Aug · Published · 184 sold' : '31 Aug · 32 referral sales', icon: Ionicons.calendar_outline, onTap: (c) => _eventSheet(c, 'Neon Garden')),
          PvRowData('Rooftop Frequencies', subtitle: lead ? '6 Sep · Draft · partnership requested' : '6 Sep · Sharing opens when it goes live', icon: Ionicons.time_outline, onTap: (c) => _eventSheet(c, 'Rooftop Frequencies')),
          PvRowData('Afterdark Sessions', subtitle: lead ? '21 Sep · Draft' : '21 Sep · Sharing opens soon', icon: Ionicons.time_outline, onTap: (c) => _eventSheet(c, 'Afterdark Sessions')),
        ]),
      ],
    );
  }
}

class _SharePage extends StatelessWidget {
  const _SharePage();

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvPage(
      eyebrow: 'Neon Garden',
      title: 'Share',
      children: [
        BuCard(
          highlight: true,
          padding: const EdgeInsets.all(BuSpace.xl),
          child: Column(
            children: [
              const BuEyebrow('Your referral code'),
              const SizedBox(height: BuSpace.s),
              Text('ALEX20', style: text.displaySmall),
              const SizedBox(height: 4),
              Text(_link, style: text.bodySmall?.copyWith(color: bu.muted), textAlign: TextAlign.center),
              const SizedBox(height: BuSpace.l),
              const PvQr(),
              const SizedBox(height: BuSpace.xl),
              FilledButton.icon(
                onPressed: () => _shareSheet(context),
                icon: const Icon(Ionicons.share_social_outline, size: 18),
                label: const Text('Share event'),
              ),
              const SizedBox(height: BuSpace.s),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'https://$_link'));
                  pvNotConnected(context, 'Referral link copied');
                },
                icon: const Icon(Ionicons.copy_outline, size: 18),
                label: const Text('Copy link'),
              ),
            ],
          ),
        ),
        const PvNote('Tickets bought with this code or link are counted as your referral sales. Commission is confirmed after the event.'),
      ],
    );
  }
}

// ───────────────────────── Earnings (both roles) ─────────────────────────

class _EarningsPage extends StatelessWidget {
  const _EarningsPage({required this.team});

  final bool team;

  static const Map<String, List<(String, String)>> _details = {
    'Pending': [('Neon Garden · 12 tickets', '\$96.00'), ('Expected', 'After Sat, 31 August')],
    'Confirmed': [('Spring Social · 30 tickets', '\$240.00'), ('Warehouse Sessions · 20 tickets', '\$160.00'), ('3 table bookings', '\$28.00')],
    'Reversed': [('Spring Social · 3 refunds', '−\$24.00')],
    'Paid': [('Payout 17 Aug', '\$1,240.00'), ('Sent to', 'Bank account ending 8812')],
  };

  @override
  Widget build(BuildContext context) {
    final confirmed = team ? '\$304.00' : '\$428.00';
    return PvPage(
      eyebrow: team ? 'Event Lead · sample' : 'Ambassador · sample',
      title: 'Earnings',
      children: [
        PvHero(eyebrow: team ? 'Personal earnings' : 'Available earnings', title: confirmed, subtitle: 'Sample financial activity · CAD'),
        if (team) ...[
          pvGap,
          const BuCard(
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Permitted team total'), SizedBox(height: 2), Text('Not your personal payout', style: TextStyle(fontSize: 12))])),
                Text('\$2,416.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
        pvGap,
        PvList([
          for (final row in [
            ('Pending', '\$96.00 · Awaiting event completion', Ionicons.time_outline),
            ('Confirmed', '$confirmed · Approved commission', Ionicons.checkmark_circle_outline),
            ('Reversed', '\$24.00 · Refunded tickets', Ionicons.warning_outline),
            ('Paid', '\$1,240.00 · Last payout 17 Aug', Ionicons.cash_outline),
          ])
            PvRowData(row.$1, subtitle: row.$2, icon: row.$3, onTap: (c) => showPvSheet(c, eyebrow: 'Earnings · sample', title: row.$1, child: PvLines(_details[row.$1]!))),
        ]),
        const PvNote('Pending is estimated. Confirmed is approved. Reversed was removed after a refund. Paid has been sent.'),
      ],
    );
  }
}

// ───────────────────────── More (both roles) ─────────────────────────

class _RoleMore extends StatelessWidget {
  const _RoleMore({required this.role, required this.place, required this.hours});

  final String role;
  final String place;
  final String hours;

  @override
  Widget build(BuildContext context) {
    return PvPage(
      eyebrow: role,
      title: 'More',
      children: [
        PvList([
          PvRowData('Shift details', subtitle: 'Schedule, breaks, and assigned location', icon: Ionicons.time_outline, onTap: (c) => showShiftSheet(c, place: place, hours: hours)),
          PvRowData('Support', subtitle: 'Help articles, chat, and request a call', icon: Ionicons.chatbubble_outline, onTap: showSupportSheet),
          PvRowData('Settings', subtitle: 'Appearance, notifications, and account', icon: Ionicons.settings_outline, onTap: (c) => pvOpen<void>(c, const AppearanceSettingsPage())),
        ]),
        pvGap,
        PvSecondary('Leave the sample', icon: Ionicons.log_out_outline, onPressed: pvLeave),
      ],
    );
  }
}

// ───────────────────────── Event Lead ─────────────────────────

class _LeadOverview extends StatefulWidget {
  const _LeadOverview();

  @override
  State<_LeadOverview> createState() => _LeadOverviewState();
}

class _LeadOverviewState extends State<_LeadOverview> {
  final Set<String> _nudged = {};
  bool _resent = false;

  static const _inactive = ['Sam Rivera', 'Kai Johnson', 'Lena Park', 'Omar Haddad'];

  @override
  Widget build(BuildContext context) {
    final left = _inactive.length - _nudged.length;
    final bu = context.bu;
    return PvPage(
      eyebrow: 'Neon Garden',
      title: 'Team overview',
      trailing: TextButton(onPressed: () => pvNotConnected(context), child: Text('Message team', style: TextStyle(color: bu.orangeSoft))),
      children: [
        PvHero(
          eyebrow: 'Team performance · sample',
          title: '286 referral sales',
          subtitle: '\$2,416 confirmed team commission.',
          trailing: const BuRing(value: 286 / 350, center: '82%', caption: 'of target'),
        ),
        const SizedBox(height: BuSpace.s),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showPvSheet(
              context,
              eyebrow: 'Neon Garden · sample',
              title: 'Leaderboard',
              child: const PvLines([('1. Maya Chen', '72 sales'), ('2. Priya Shah', '54 sales'), ('3. Alex Morgan', '50 sales'), ('4. Jordan Blake', '42 sales'), ('5. You', '38 sales')]),
            ),
            icon: const Icon(Ionicons.trophy_outline, size: 18),
            label: const Text('Open leaderboard'),
          ),
        ),
        pvGap,
        const PvStatGrid([
          PvStat('38', 'Your sales', hint: '\$304 personal'),
          PvStat('286', 'Team sales', hint: '\$2,416 team total'),
          PvStat('14 / 18', 'Active', hint: 'ambassadors'),
          PvStat('82%', 'Target', hint: '286 of 350'),
        ]),
        PvSection(eyebrow: 'Needs attention', title: 'Team actions', children: [
          PvList([
            PvRowData(
              left > 0 ? '$left inactive ambassadors' : 'Everyone nudged',
              subtitle: left > 0 ? 'No link activity in 7 days' : 'Reminders sent today',
              icon: Ionicons.warning_outline,
              pill: left > 0 ? 'Needs a nudge' : null,
              tone: BuTone.attention,
              onTap: (c) async {
                await showPvSheet(c, eyebrow: 'No activity in 7 days', title: 'Inactive ambassadors', child: _NudgeList(nudged: _nudged));
                if (mounted) setState(() {});
              },
            ),
            PvRowData(
              _resent ? 'Invitations resent' : '3 invitations pending',
              subtitle: _resent ? 'New links expire in 7 days' : 'Expire in 2 days · tap to resend',
              icon: Ionicons.time_outline,
              chevron: !_resent,
              onTap: (c) {
                setState(() => _resent = true);
                pvNotConnected(c, '3 invitations resent (sample)');
              },
            ),
          ]),
        ]),
      ],
    );
  }
}

class _NudgeList extends StatefulWidget {
  const _NudgeList({required this.nudged});

  final Set<String> nudged;

  @override
  State<_NudgeList> createState() => _NudgeListState();
}

class _NudgeListState extends State<_NudgeList> {
  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return BuListCard(
      children: [
        for (final n in _LeadOverviewState._inactive)
          BuListRow(
            leading: PvAvatar(n.substring(0, 2)),
            title: n,
            subtitle: widget.nudged.contains(n) ? 'Reminder sent' : 'Last share 9 days ago',
            showChevron: false,
            trailing: TextButton(
              onPressed: widget.nudged.contains(n)
                  ? null
                  : () {
                      setState(() => widget.nudged.add(n));
                      pvNotConnected(context, 'Reminder sent to $n (sample)');
                    },
              child: Text(widget.nudged.contains(n) ? 'Sent' : 'Nudge', style: TextStyle(color: widget.nudged.contains(n) ? bu.muted : bu.orangeSoft)),
            ),
          ),
      ],
    );
  }
}

class _LeadTeam extends StatelessWidget {
  const _LeadTeam();

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return PvPage(
      eyebrow: 'Neon Garden',
      title: 'Team',
      trailing: TextButton(onPressed: () => _invite(context), child: Text('Invite', style: TextStyle(color: bu.orangeSoft))),
      children: [
        const PvStatGrid([PvStat('18', 'Ambassadors', hint: '14 active'), PvStat('286', 'Team sales', hint: 'tickets referred')]),
        PvList([
          for (final m in const [('Maya Chen', '72 sales · \$576 confirmed'), ('Alex Morgan', '50 sales · \$428 confirmed'), ('Jordan Blake', '42 sales · \$336 confirmed')])
            PvRowData(m.$1, subtitle: m.$2, initials: m.$1.substring(0, 2), onTap: (c) => _member(c, m.$1, m.$2)),
          PvRowData('Invite ambassador', subtitle: 'Assign event and target', icon: Ionicons.add_circle_outline, onTap: _invite),
        ]),
        const PvNote('Showing your top ambassadors and new invitations.'),
      ],
    );
  }

  static void _invite(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'Neon Garden',
      title: 'Invite ambassador',
      child: const Column(children: [PvField('Email address', hint: 'name@example.com'), PvField('Ticket target', value: '20'), PvPrimary('Send invitation')]),
    );
  }

  static void _member(BuildContext context, String name, String status) {
    showPvSheet(
      context,
      eyebrow: 'Ambassador',
      title: name,
      child: Column(children: [PvLines([('Role', 'Ambassador'), ('This event', status)]), pvGap, const PvSecondary('Remove from the team')]),
    );
  }
}
