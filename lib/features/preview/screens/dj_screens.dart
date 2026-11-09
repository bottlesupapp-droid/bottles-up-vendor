import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';
import '../widgets/pv_mini_app.dart';
import 'app_wide_screens.dart';
import 'inbox_screens.dart';

/// DJ / Artist: booking requests from guests, organizers and venues, the calendar, the packages and add-ons shown on the public profile, and
/// the money. Sample screens (see `preview_config.dart`); the layout follows the prototype's `Dj.tsx` and `DjStudio.tsx`.

String _money(num n) {
  final cents = (n * 100).round();
  final whole = cents ~/ 100;
  final text = whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$text.${(cents % 100).toString().padLeft(2, '0')}';
}

String _money0(num n) => '\$${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

class _Pkg {
  const _Pkg(this.id, this.name, this.desc, this.price, this.hours, {this.from = false, this.notice = '', this.setup = '', this.includes = const []});

  final String id;
  final String name;
  final String desc;
  final int price;
  final double hours;
  final bool from;
  final String notice;
  final String setup;
  final List<String> includes;
}

class _Addon {
  const _Addon(this.id, this.name, this.desc, this.price, {this.perHour = false});

  final String id;
  final String name;
  final String desc;
  final int price;
  final bool perHour;
}

const _packages = [
  _Pkg('warmup', 'Warm-up set', 'Set the room before the headliner.', 500, 2, notice: '7 days', setup: 'Venue decks and booth monitor', includes: ['Soundcheck', 'Own USBs']),
  _Pkg('club', 'Club set', 'Peak-time Afro house and amapiano.', 1200, 4, notice: '14 days', setup: '2 × CDJ-3000, DJM-A9, booth monitor', includes: ['Soundcheck', 'Custom intro edit', 'Social post']),
  _Pkg('private', 'Private event', 'Weddings, birthdays and brand nights.', 900, 3, from: true, notice: '21 days', setup: 'Power and a 2 m table', includes: ['Planning call', 'Requests on the night']),
  _Pkg('festival', 'Festival / headline', 'Headline slot with full production.', 2000, 1.5, from: true, notice: '30 days', setup: 'Full rider', includes: ['Exclusive edits', 'Rider-ready tech spec', '2 guest-list spots']),
];

const _addons = [
  _Addon('gear', 'DJ equipment', 'I bring decks, mixer and monitors.', 300),
  _Addon('lights', 'Lighting package', 'Wash lights and haze for small rooms.', 350),
  _Addon('mc', 'MC / hype host', 'Mic work and announcements.', 200),
  _Addon('extra', 'Extra performance time', 'Keep the party going.', 250, perHour: true),
  _Addon('travel', 'Travel outside Toronto', 'Up to 150 km.', 150),
];

enum _Status { newRequest, countered, awaitingDeposit, confirmed, declined }

class _Req {
  const _Req({
    required this.ref,
    required this.client,
    required this.clientType,
    required this.clientNote,
    required this.pkg,
    required this.date,
    required this.start,
    required this.end,
    required this.venue,
    required this.eventType,
    required this.guests,
    required this.message,
    required this.received,
    required this.status,
    this.extraHours = 0,
    this.addons = const [],
    this.travel = false,
    this.conflict,
  });

  final String ref;
  final String client;
  final String clientType;
  final String clientNote;
  final String pkg;
  final String date;
  final String start;
  final String end;
  final String venue;
  final String eventType;
  final int guests;
  final String message;
  final String received;
  final _Status status;
  final int extraHours;
  final List<String> addons;
  final bool travel;
  final String? conflict;

  _Pkg get package => _packages.firstWhere((p) => p.id == pkg);

  /// What the client is quoted, line by line, the way the prototype adds it up: package, extra hours, add-ons, travel; then 13% tax, a 30%
  /// deposit, and the artist's payout after the 10% fee.
  _Quote get quote {
    final lines = <(String, num)>[('${package.name} · ${package.hours % 1 == 0 ? package.hours.toInt() : package.hours} h', package.price)];
    if (extraHours > 0) lines.add(('Extra time · $extraHours h', extraHours * 250));
    for (final id in addons) {
      final a = _addons.firstWhere((x) => x.id == id);
      lines.add((a.name, a.price));
    }
    if (travel) lines.add(('Travel outside Toronto', 150));
    final subtotal = lines.fold<num>(0, (s, l) => s + l.$2);
    final tax = (subtotal * 13).round() / 100;
    final total = subtotal + tax;
    final deposit = (total * 30).round() / 100;
    final fee = (subtotal * 10).round() / 100;
    return _Quote(lines, subtotal, tax, total, deposit, fee, subtotal - fee);
  }

  double get setHours => package.hours + extraHours;
}

class _Quote {
  const _Quote(this.lines, this.subtotal, this.tax, this.total, this.deposit, this.fee, this.payout);

  final List<(String, num)> lines;
  final num subtotal;
  final num tax;
  final num total;
  final num deposit;
  final num fee;
  final num payout;
}

const _requests = [
  _Req(
    ref: 'BK-7559', client: 'Jordan Ellis', clientType: 'Guest · BottlesUp app', clientNote: 'First booking · 42 nights out on BottlesUp', pkg: 'private',
    date: 'Sat, Sep 7', start: '9:00 PM', end: '1:00 AM', venue: 'Private loft · Liberty Village', eventType: 'Birthday after-party', guests: 40, extraHours: 1,
    addons: ['gear'], message: '30th birthday after-party for about 40 people. Afro house and amapiano all night, please!', received: '12 min ago', status: _Status.newRequest,
  ),
  _Req(
    ref: 'BK-7531', client: 'Midnight Social', clientType: 'Organizer', clientNote: 'Booked you 2 times · 4.9 rating from artists', pkg: 'club',
    date: 'Fri, Oct 11', start: '10:00 PM', end: '2:00 AM', venue: 'Sky Room · Harbour Avenue', eventType: 'Club night', guests: 220, addons: ['lights'],
    message: 'Rooftop Frequencies afterparty. Headline slot after midnight.', received: '2 h ago', status: _Status.newRequest, conflict: 'Nova Room residency',
  ),
  _Req(
    ref: 'BK-7490', client: 'Priya Shah', clientType: 'Guest · BottlesUp app', clientNote: 'New to BottlesUp', pkg: 'private',
    date: 'Fri, Aug 30', start: '8:00 PM', end: '11:00 PM', venue: '42 Queen St W, Toronto', eventType: 'Private party', guests: 60, addons: ['mc'],
    message: 'Engagement party. Some Bollywood mixed in would be amazing.', received: 'Yesterday', status: _Status.newRequest,
  ),
  _Req(
    ref: 'BK-7402', client: 'Sky Room', clientType: 'Venue', clientNote: 'Booked you 5 times', pkg: 'warmup',
    date: 'Fri, Sep 20', start: '9:00 PM', end: '11:00 PM', venue: 'Sky Room · Harbour Avenue', eventType: 'Club night', guests: 180,
    message: 'Opening for our resident.', received: 'Aug 2', status: _Status.confirmed,
  ),
  _Req(
    ref: 'BK-7388', client: 'Northwind Agency', clientType: 'Corporate', clientNote: 'New to BottlesUp', pkg: 'private',
    date: 'Thu, Sep 12', start: '7:00 PM', end: '10:00 PM', venue: 'Mississauga Convention Ctr', eventType: 'Corporate event', guests: 300, addons: ['gear'], travel: true,
    message: 'Staff party, clean versions only.', received: 'Jul 30', status: _Status.declined,
  ),
  _Req(
    ref: 'BK-7377', client: 'Maya Chen', clientType: 'Guest · BottlesUp app', clientNote: 'Booked you 1 time', pkg: 'club',
    date: 'Sat, Sep 28', start: '10:00 PM', end: '2:00 AM', venue: 'Nova Room · King Street', eventType: 'Club night', guests: 150,
    message: 'We would love the same set as last time.', received: 'Jul 28', status: _Status.countered,
  ),
];

String _group(_Status s) => switch (s) {
      _Status.newRequest => 'New',
      _Status.countered || _Status.awaitingDeposit => 'Awaiting client',
      _Status.confirmed => 'Confirmed',
      _Status.declined => 'Past',
    };

(String, BuTone) _statusPill(_Status s) => switch (s) {
      _Status.newRequest => ('New', BuTone.brand),
      _Status.countered => ('Awaiting client', BuTone.attention),
      _Status.awaitingDeposit => ('Awaiting deposit', BuTone.attention),
      _Status.confirmed => ('Confirmed', BuTone.good),
      _Status.declined => ('Declined', BuTone.neutral),
    };

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.length == 1 ? parts.first.substring(0, parts.first.length < 2 ? 1 : 2) : '${parts.first[0]}${parts.last[0]}';
}

// ───────────────────────── the role ─────────────────────────

PvMiniAppConfig get djApp => PvMiniAppConfig(
      id: 'dj',
      role: 'DJ / Artist',
      org: 'Amara Vale',
      scope: 'Booking requests and gigs',
      tabs: [
        PvTab(label: 'Requests', icon: Ionicons.ticket_outline, activeIcon: Ionicons.ticket, builder: (_) => const DjRequestsTab()),
        PvTab(label: 'Calendar', icon: Ionicons.calendar_outline, activeIcon: Ionicons.calendar, builder: (_) => const DjCalendarTab()),
        PvTab(label: 'Services', icon: Ionicons.card_outline, activeIcon: Ionicons.card, builder: (_) => const DjServicesTab()),
        PvTab(label: 'Earnings', icon: Ionicons.cash_outline, activeIcon: Ionicons.cash, builder: (_) => const DjEarningsTab()),
        PvTab(label: 'More', icon: Ionicons.menu_outline, activeIcon: Ionicons.menu, builder: (_) => const DjMoreTab()),
      ],
    );

// ───────────────────────── Requests ─────────────────────────

class DjRequestsTab extends StatefulWidget {
  const DjRequestsTab({super.key});

  @override
  State<DjRequestsTab> createState() => _DjRequestsTabState();
}

class _DjRequestsTabState extends State<DjRequestsTab> {
  String _filter = 'New';

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in _requests) {
      counts[_group(r.status)] = (counts[_group(r.status)] ?? 0) + 1;
    }
    final shown = [for (final r in _requests) if (_group(r.status) == _filter) r];
    return PvPage(
      eyebrow: 'Amara Vale · DJ',
      title: 'Requests',
      children: [
        const PvSwitchCard(title: 'Accepting bookings', subtitle: 'When paused, your profile says "Not taking bookings".', initial: true),
        pvGap,
        PvFilterChips(
          labels: const ['New', 'Awaiting client', 'Confirmed', 'Past'],
          counts: {'New': counts['New'] ?? 0, 'Awaiting client': counts['Awaiting client'] ?? 0},
          initial: _filter,
          onChanged: (v) => setState(() => _filter = v),
        ),
        pvGap,
        if (shown.isEmpty)
          PvEmpty(
            icon: Ionicons.calendar_outline,
            title: _filter == 'New' ? "You're all caught up" : 'Nothing in $_filter',
            text: _filter == 'New' ? 'New requests from guests, organizers and venues appear here.' : 'Requests move here as they progress.',
          )
        else
          PvList([
            for (final r in shown)
              PvRowData(
                r.client,
                subtitle: '${r.eventType} · ${r.date} · ${r.venue.split(' · ').first}\n${r.setHours % 1 == 0 ? r.setHours.toInt() : r.setHours} h set · offered ${_money0(r.quote.subtotal)} + HST'
                    '${r.conflict != null && r.status == _Status.newRequest ? '\nDate conflict with ${r.conflict}' : ''}',
                initials: _initials(r.client),
                pill: _statusPill(r.status).$1,
                tone: _statusPill(r.status).$2,
                onTap: (c) => pvOpen<void>(c, _DjRequestDetailPage(request: r)),
              ),
          ]),
      ],
    );
  }
}

class _DjRequestDetailPage extends StatelessWidget {
  const _DjRequestDetailPage({required this.request});

  final _Req request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final q = r.quote;
    final bu = context.bu;
    final pill = _statusPill(r.status);
    final open = r.status == _Status.newRequest;
    String addonNames() => r.addons.isEmpty ? 'None' : r.addons.map((id) => _addons.firstWhere((a) => a.id == id).name).join(', ');
    return PvStandalone(
      title: r.ref,
      child: PvPage(
        eyebrow: '${r.ref} · received ${r.received}',
        title: r.package.name,
        trailing: BuStatusPill(pill.$1, tone: pill.$2),
        children: [
          BuCard(
            padding: EdgeInsets.zero,
            child: BuListRow(
              leading: PvAvatar(_initials(r.client)),
              title: r.client,
              subtitle: '${r.clientType} · ${r.clientNote}',
              trailing: Icon(Ionicons.chatbubble_outline, size: 20, color: bu.orangeSoft),
              showChevron: false,
              maxSubtitleLines: 3,
            ),
          ),
          const SizedBox(height: BuSpace.m),
          Text('“${r.message}”', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: bu.soft, fontStyle: FontStyle.italic)),
          if (r.conflict != null && open) ...[
            const SizedBox(height: BuSpace.m),
            BuCard(
              accent: bu.amber,
              child: Row(
                children: [
                  Icon(Ionicons.warning_outline, color: bu.amber, size: 20),
                  const SizedBox(width: BuSpace.s + 2),
                  Expanded(child: Text('You already have “${r.conflict}” on ${r.date}.', style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          ],
          pvGap,
          PvSection(eyebrow: 'Event', title: 'Details', children: [
            PvLines([
              ('Date', r.date),
              ('Set time', '${r.start} – ${r.end}'),
              ('Where', r.venue),
              ('Event', '${r.eventType} · ${r.guests} guests'),
              ('Add-ons', addonNames()),
            ]),
          ]),
          PvSection(eyebrow: 'Equipment', title: "What's needed", children: [
            PvLines([
              ('Decks and mixer', r.addons.contains('gear') ? 'You bring your setup (+ add-on)' : 'Venue provides · rider: 2 × CDJ-3000, DJM-A9'),
              ('Lighting', r.addons.contains('lights') ? 'You bring the lighting package' : 'Venue lighting'),
              ('Host / MC', r.addons.contains('mc') ? 'Included' : 'Not requested'),
              ('Travel', r.travel ? 'Outside Toronto · travel fee applies' : 'Within Toronto'),
            ]),
          ]),
          PvSection(eyebrow: 'Price', title: 'What the client pays', children: [
            PvLines([
              for (final l in q.lines) (l.$1, _money(l.$2)),
              ('Subtotal', _money(q.subtotal)),
              ('HST (13%)', _money(q.tax)),
              ('Client total', _money(q.total)),
              ('Deposit to confirm (30%)', _money(q.deposit)),
            ]),
            const SizedBox(height: BuSpace.m),
            BuCard(
              highlight: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BuEyebrow('You receive'),
                  const SizedBox(height: 4),
                  Text(_money(q.payout), style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('${_money(q.subtotal)} minus the 10% BottlesUp fee (${_money(q.fee)}). HST is collected and remitted separately.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted)),
                ],
              ),
            ),
          ]),
          const PvSection(eyebrow: 'Terms', title: 'Booking terms', children: [
            PvLines([
              ('Deposit', '30% to confirm, held by BottlesUp'),
              ('Balance', 'Due 7 days before the gig'),
              ('Client cancels', 'Over 14 days: full refund · under 14 days: deposit kept'),
              ('You cancel', 'Client refunded in full'),
              ('Payout', '2 business days after the gig'),
            ]),
          ]),
          if (open) ...[
            PvPrimary('Accept booking', icon: Ionicons.checkmark, onPressed: (c) => _acceptSheet(c, r)),
            const SizedBox(height: BuSpace.s),
            Row(
              children: [
                Expanded(child: _ActionButton(label: 'Decline', icon: Ionicons.close, primary: false, onPressed: () => _declineSheet(context))),
                const SizedBox(width: BuSpace.m),
                Expanded(child: _ActionButton(label: 'Counter-offer', icon: null, primary: true, onPressed: () => _counterSheet(context, r))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static void _acceptSheet(BuildContext context, _Req r) {
    final q = r.quote;
    showPvSheet(
      context,
      eyebrow: '${r.ref} · ${r.client}',
      title: 'Accept this booking?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PvLines([
            ('Date', '${r.date} · ${r.start}–${r.end}'),
            ('Client pays now', '${_money(q.deposit)} deposit (30%)'),
            ('Balance', '${_money(q.total - q.deposit)} · 7 days before'),
            ('You receive', '${_money(q.payout)} after the 10% fee'),
          ]),
          const PvNote('The date is held on your calendar. It becomes confirmed when the client pays the deposit.'),
          const PvPrimary('Accept booking'),
        ],
      ),
    );
  }

  static void _counterSheet(BuildContext context, _Req r) {
    showPvSheet(
      context,
      eyebrow: r.ref,
      title: 'Counter-offer',
      child: Column(
        children: [
          PvField('Your price before HST', value: '${r.quote.subtotal.round()}'),
          PvField('Start time', value: r.start),
          const PvField('Note', hint: 'e.g. Happy to do it with my own equipment included'),
          const PvPrimary('Send counter-offer'),
        ],
      ),
    );
  }

  static void _declineSheet(BuildContext context) {
    showPvSheet(
      context,
      title: 'Decline this request?',
      eyebrow: 'The client is told it was declined',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PvFilterChips(labels: ['Not available', 'Not my style of event', 'Budget too low', 'Other']),
          SizedBox(height: BuSpace.l),
          PvField('Add a note (optional)', maxLines: 3),
          PvPrimary('Decline request'),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.primary, required this.onPressed});

  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    return primary
        ? (icon == null ? FilledButton(onPressed: onPressed, child: child) : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: child))
        : (icon == null ? OutlinedButton(onPressed: onPressed, child: child) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: child));
  }
}

// ───────────────────────── Calendar ─────────────────────────

class DjCalendarTab extends StatelessWidget {
  const DjCalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PvPage(
      eyebrow: 'Amara Vale',
      title: 'Calendar',
      children: [
        PvCalendar(
          monthLabel: 'September',
          startWeekday: 0,
          days: 30,
          marks: const {
            7: PvDayMark.request,
            12: PvDayMark.request,
            14: PvDayMark.booked,
            20: PvDayMark.held,
            21: PvDayMark.booked,
            26: PvDayMark.blocked,
            27: PvDayMark.blocked,
          },
          onDayTap: (day) => showPvSheet(
            context,
            eyebrow: 'Sept $day',
            title: {14: 'Booked', 21: 'Booked', 20: 'Held for a deposit', 7: 'Booking request', 12: 'Booking request', 26: 'Blocked', 27: 'Blocked'}[day] ?? 'Open for bookings',
            child: Column(
              children: [
                if ({14, 21}.contains(day)) const PvLines([('Gig', 'Nova Room residency'), ('Status', 'Confirmed')]) else if ({7, 12, 20}.contains(day)) const PvLines([('Request', 'Open it from Requests'), ('Status', 'Waiting')]) else
                  PvPrimary({26, 27}.contains(day) ? 'Open this date' : 'Block this date'),
              ],
            ),
          ),
        ),
        pvGap,
        PvSection(title: 'Your gigs', children: [
          PvList([
            PvRowData('Sat, Sep 14', subtitle: 'EONICS × Amara Vale · Nova Room', icon: Ionicons.calendar_outline),
            PvRowData('Fri, Sep 20', subtitle: 'Sky Room warm-up · waiting for the deposit', icon: Ionicons.calendar_outline),
            PvRowData('Sat, Sep 21', subtitle: 'Nova Room residency', icon: Ionicons.calendar_outline),
          ]),
        ]),
        const PvNote('Tap a free date to block it: guests cannot request a blocked date.'),
      ],
    );
  }
}

// ───────────────────────── Services ─────────────────────────

class DjServicesTab extends StatelessWidget {
  const DjServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PvPage(
      eyebrow: 'Shown on your public profile',
      title: 'Services',
      children: [
        PvSection(
          eyebrow: 'Packages',
          title: 'What you offer',
          actionLabel: 'Add package',
          onAction: () => _editPackage(context, null),
          children: [
            PvList([
              for (final p in _packages)
                PvRowData(
                  p.name,
                  subtitle: '${p.from ? 'from ' : ''}${_money0(p.price)} · ${p.hours % 1 == 0 ? p.hours.toInt() : p.hours} h · ${p.desc}',
                  icon: Ionicons.musical_notes_outline,
                  onTap: (c) => _editPackage(c, p),
                ),
            ]),
          ],
        ),
        PvSection(
          eyebrow: 'Add-ons',
          title: 'Extras a client can add',
          actionLabel: 'Add add-on',
          onAction: () => _editAddon(context, null),
          children: [
            PvList([
              for (final a in _addons)
                PvRowData(a.name, subtitle: '${_money0(a.price)}${a.perHour ? ' per hour' : ''} · ${a.desc}', icon: Ionicons.add_circle_outline, onTap: (c) => _editAddon(c, a)),
            ]),
          ],
        ),
        const PvNote('Prices here are the ones a guest sees when they request you in the BottlesUp app.'),
      ],
    );
  }

  static void _editPackage(BuildContext context, _Pkg? p) {
    showPvSheet(
      context,
      eyebrow: p == null ? 'New package' : 'Package',
      title: p?.name ?? 'Add a package',
      child: Column(
        children: [
          PvField('Name', value: p?.name ?? ''),
          PvField('Short description', value: p?.desc ?? '', maxLines: 2),
          PvField('Price (before HST)', value: p == null ? '' : '${p.price}'),
          PvField('Length of the set (hours)', value: p == null ? '' : '${p.hours}'),
          PvField('Notice needed', value: p?.notice ?? ''),
          PvField('Equipment needed', value: p?.setup ?? ''),
          PvField('Included', value: (p?.includes ?? const []).join(', ')),
          const PvSwitchCard(title: 'Hide this package', subtitle: 'Guests cannot see or request it.'),
          pvGap,
          const PvPrimary('Save package'),
        ],
      ),
    );
  }

  static void _editAddon(BuildContext context, _Addon? a) {
    showPvSheet(
      context,
      eyebrow: a == null ? 'New add-on' : 'Add-on',
      title: a?.name ?? 'Add an add-on',
      child: Column(
        children: [
          PvField('Name', value: a?.name ?? ''),
          PvField('Short description', value: a?.desc ?? '', maxLines: 2),
          PvField(a?.perHour == true ? 'Price per hour' : 'Price', value: a == null ? '' : '${a.price}'),
          const PvSwitchCard(title: 'Hide this add-on'),
          pvGap,
          const PvPrimary('Save add-on'),
        ],
      ),
    );
  }
}

// ───────────────────────── Earnings ─────────────────────────

class DjEarningsTab extends StatelessWidget {
  const DjEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final confirmed = _requests.where((r) => r.status == _Status.confirmed);
    return PvPage(
      eyebrow: 'Private · sample data',
      title: 'Earnings',
      children: [
        const PvHero(eyebrow: 'Available for payout', title: '\$2,640.00', subtitle: 'Next payout Mon, Aug 26 · bank ending 8812'),
        pvGap,
        PvSection(title: 'Payment status', children: [
          PvList([
            for (final r in confirmed)
              PvRowData(r.client, subtitle: '${r.date} · you receive ${_money(r.quote.payout)}', pill: 'Deposit held', tone: BuTone.brand),
            const PvRowData('Nova Room residency', subtitle: 'Aug 17 · you receive \$1,110.00', pill: 'Payout pending', tone: BuTone.attention),
            const PvRowData('Sky Room warm-up', subtitle: 'Aug 10 · you receive \$450.00', pill: 'Paid out', tone: BuTone.good),
            const PvRowData('Private set · Liberty Village', subtitle: 'Aug 3 · you receive \$1,080.00', pill: 'Paid out', tone: BuTone.good),
          ]),
        ]),
        const PvNote("Deposits are held by BottlesUp until the gig happens. You're paid 2 business days after each gig, after the 10% fee. Only you can see this page."),
      ],
    );
  }
}

// ───────────────────────── More ─────────────────────────

class DjMoreTab extends StatelessWidget {
  const DjMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PvPage(
      eyebrow: 'DJ / Artist',
      title: 'More',
      children: [
        PvSection(title: 'Public profile', children: [
          BuCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile visibility', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15)),
                  const SizedBox(height: BuSpace.xs),
                  Text('Anyone can find and book you', key: const Key('dj-visibility-line'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.bu.muted)),
                  const SizedBox(height: BuSpace.m),
                  const PvFilterChips(labels: ['Public', 'Private']),
                ],
              ),
            ),
          ),
          const SizedBox(height: BuSpace.m),
          PvList([
            PvRowData('View public profile', subtitle: 'See it the way visitors do', icon: Ionicons.person_outline, onTap: (c) => pvOpen<void>(c, const DjPublicProfilePage())),
            PvRowData('Edit profile', subtitle: 'Photos, bio, genres, links and booking preferences', icon: Ionicons.create_outline, onTap: (c) => pvOpen<void>(c, const DjProfileEditPage())),
          ]),
        ]),
        PvSection(title: 'Private', children: [
          PvList([
            PvRowData('Messages', subtitle: '2 unread · inquiries and team', icon: Ionicons.chatbubbles_outline, badge: 2, onTap: (c) => pvOpen<void>(c, const InboxPage(account: 'DJ / Artist'))),
            PvRowData('Analytics', subtitle: 'Profile views, requests and booking rate', icon: Ionicons.stats_chart_outline, onTap: (c) => _analytics(c)),
            PvRowData('Rider', subtitle: 'Shared with clients after you accept', icon: Ionicons.document_text_outline, onTap: (c) => _rider(c)),
            PvRowData('Account settings', subtitle: 'Appearance, notifications, payouts', icon: Ionicons.settings_outline, onTap: (c) => pvOpen<void>(c, const AppearanceSettingsPage())),
            PvRowData('Support', subtitle: 'Help with bookings and payouts', icon: Ionicons.help_buoy_outline, onTap: (c) => showSupportSheet(c)),
          ]),
        ]),
        PvSecondary('Leave the sample', icon: Ionicons.log_out_outline, onPressed: pvLeave),
      ],
    );
  }

  static void _analytics(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'Private · sample data',
      title: 'Last 30 days',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PvBars(values: [120, 180, 150, 240], labels: ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'], caption: 'Profile views rose in week 4 after your Sky Room reel.'),
          SizedBox(height: BuSpace.m),
          PvLines([('Profile views', '690'), ('Booking requests', '9'), ('Accepted', '5 of 9 (56%)'), ('Avg. reply time', '3 h')]),
        ],
      ),
    );
  }

  static void _rider(BuildContext context) {
    showPvSheet(
      context,
      eyebrow: 'Shared after accepting',
      title: 'Rider',
      child: const PvLines([('Decks', '2 × Pioneer CDJ-3000'), ('Mixer', 'Pioneer DJM-A9'), ('Monitor', '1 booth monitor, own controls'), ('Hospitality', 'Water and a place to leave a bag')]),
    );
  }
}

// ───────────────────────── Public profile, editor, booking form ─────────────────────────

class DjPublicProfilePage extends StatelessWidget {
  const DjPublicProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvStandalone(
      title: 'Public profile',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xxl),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BuRadius.card),
              gradient: LinearGradient(colors: [bu.orange.withValues(alpha: 0.35), bu.panel2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: bu.line),
            ),
            alignment: Alignment.center,
            child: Icon(Ionicons.image_outline, color: bu.muted, size: 32),
          ),
          const SizedBox(height: BuSpace.l),
          Row(
            children: [
              const PvAvatar('AV', size: 64),
              const SizedBox(width: BuSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amara Vale', style: text.titleLarge),
                    Text('@amaravale · Toronto', style: text.bodyMedium?.copyWith(color: bu.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BuSpace.m),
          Wrap(spacing: BuSpace.s, runSpacing: BuSpace.s, children: const [BuStatusPill('Afro house'), BuStatusPill('Amapiano'), BuStatusPill('Deep house')]),
          const SizedBox(height: BuSpace.m),
          Text('Resident at Nova Room. Clubs, private events and festivals across Ontario.', style: text.bodyMedium?.copyWith(color: bu.soft)),
          pvGap,
          PvSection(title: 'Packages', children: [
            PvList([
              for (final p in _packages.where((p) => p.id != 'festival'))
                PvRowData(p.name, subtitle: '${p.from ? 'from ' : ''}${_money0(p.price)} · ${p.hours % 1 == 0 ? p.hours.toInt() : p.hours} h', icon: Ionicons.musical_notes_outline),
            ]),
          ]),
          PvSection(title: 'Latest', children: [
            PvList(const [
              PvRowData('Live at Nova Room · Afterglow', subtitle: 'Video', icon: Ionicons.videocam_outline),
              PvRowData('SoundCloud mix', subtitle: 'soundcloud.com/amaravale/sunset-vol-3', icon: Ionicons.link_outline),
            ]),
          ]),
          const PvSampleNote(),
          pvGap,
          PvPrimary('Request a booking', icon: Ionicons.calendar_outline, onPressed: (c) => pvOpen<void>(c, const DjBookingRequestPage())),
          const SizedBox(height: BuSpace.s),
          const PvSecondary('Message Amara', icon: Ionicons.chatbubble_outline),
        ],
      ),
    );
  }
}

class DjBookingRequestPage extends StatelessWidget {
  const DjBookingRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Request a booking',
      child: PvPage(
        eyebrow: 'Visitor view',
        title: 'Request Amara',
        intro: 'Amara replies within a few hours. You pay a 30% deposit only after she accepts.',
        children: [
          const PvFilterChips(labels: ['Warm-up set', 'Club set', 'Private event', 'Festival']),
          pvGap,
          const PvField('Your name', value: 'Jordan Ellis'),
          const PvField('Date', value: 'Sat, Sep 7'),
          const PvField('Start time', value: '9:00 PM'),
          const PvField('End time', value: '1:00 AM'),
          const PvField('Where is it?', hint: 'Venue or address'),
          const PvField('What kind of event?', value: 'Birthday after-party'),
          const PvField('Message', maxLines: 4, hint: 'Tell Amara about the night'),
          PvSection(title: 'Add-ons', children: [
            PvList([for (final a in _addons) PvRowData(a.name, subtitle: '${_money0(a.price)}${a.perHour ? ' per hour' : ''}', icon: Ionicons.add_circle_outline)]),
          ]),
          const PvPrimary('Send request'),
        ],
      ),
    );
  }
}

class DjProfileEditPage extends StatelessWidget {
  const DjProfileEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PvStandalone(
      title: 'Edit profile',
      child: PvPage(
        eyebrow: 'Public profile',
        title: 'Edit profile',
        children: [
          PvSection(title: 'Photos', children: [
            BuCard(
              child: Row(
                children: [
                  const PvAvatar('AV', size: 56),
                  const SizedBox(width: BuSpace.l),
                  const Expanded(child: Text('Profile photo and cover. Drag the cover to move it, pinch to zoom.')),
                  TextButton(onPressed: () => pvNotConnected(context), child: const Text('Change')),
                ],
              ),
            ),
          ]),
          PvSection(title: 'About you', children: const [
            PvField('Stage name', value: 'Amara Vale'),
            PvField('Username', value: 'amaravale'),
            PvField('Bio', value: 'Resident at Nova Room. Clubs, private events and festivals across Ontario.', maxLines: 3),
            PvField('Based in', value: 'Toronto'),
            PvField('Areas you travel to', value: 'Toronto, GTA'),
          ]),
          PvSection(title: 'Sound', children: const [
            PvField('Genres', value: 'Afro house, Amapiano, Deep house'),
            PvField('Event types', value: 'Club night, Private party, Festival'),
            PvField('Starting price', value: '500'),
          ]),
          PvSection(title: 'Links', children: const [
            PvField('Instagram', value: '@amaravale'),
            PvField('TikTok', value: '@amaravale'),
            PvField('SoundCloud', value: 'amaravale'),
            PvField('Notice needed for bookings', value: '14 days'),
          ]),
          const PvPrimary('Save profile'),
        ],
      ),
    );
  }
}
