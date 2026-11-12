import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';

/// Messages for organizers and DJs: "Inquiries" (guests, clients and anyone contacting you or one of your events) and "Team" (staff, venues,
/// DJs and collaborators; invited members only). Sample screens; the layout follows the prototype's `Inbox.tsx` and `Messages.tsx`.

/// One message of a sample conversation.
class PvChatMessage {
  const PvChatMessage(this.mine, this.text, this.time, {this.who});

  final bool mine;
  final String text;
  final String time;
  final String? who;
}

class _Thread {
  const _Thread({required this.area, required this.title, required this.context, required this.messages, this.unread = 0, this.card, this.members});

  /// "Inquiries" or "Team".
  final String area;
  final String title;
  final String context;
  final List<PvChatMessage> messages;
  final int unread;

  /// The event or booking the conversation is about, shown at the top of the chat.
  final (String, String)? card;
  final List<String>? members;
}

const _organizerThreads = [
  _Thread(
    area: 'Inquiries', title: 'Liam Carter', context: 'About Neon Garden', unread: 1, card: ('Neon Garden · Sat, 31 Aug', 'Nova Room · tickets from \$35'),
    messages: [PvChatMessage(false, 'Do you still have table tickets for Saturday?', '7:42 PM', who: 'Liam')],
  ),
  _Thread(
    area: 'Inquiries', title: 'Northwind Agency', context: 'Private event enquiry', unread: 1,
    messages: [PvChatMessage(false, 'Could you produce a staff party for 300 in November?', 'Yesterday', who: 'Northwind')],
  ),
  _Thread(
    area: 'Inquiries', title: 'Maya Chen', context: 'About Warehouse Sessions', card: ('Warehouse Sessions · Sat, 28 Sep', 'The Warehouse · ticket-only'),
    messages: [PvChatMessage(true, 'Doors open at 9 PM. See you there!', 'Sun'), PvChatMessage(false, 'Perfect, thank you.', 'Sun', who: 'Maya')],
  ),
  _Thread(
    area: 'Team', title: 'Neon Garden crew', context: 'Event group · 5 members', unread: 2, members: ['Jamie Fox', 'Morgan Lee', 'Amara Vale', 'Nova Room (venue)', 'You'],
    card: ('Neon Garden · Sat, 31 Aug', 'Event group'),
    messages: [PvChatMessage(false, 'Soundcheck is at 7 PM.', '6:10 PM', who: 'Jamie'), PvChatMessage(false, 'Guest list closes at 6.', '6:12 PM', who: 'Morgan')],
  ),
  _Thread(
    area: 'Team', title: 'Nova Room', context: 'Venue contact',
    messages: [PvChatMessage(false, "We've reviewed the bar-sales terms.", '8:58 PM', who: 'Nova Room')],
  ),
  _Thread(
    area: 'Team', title: 'Amara Vale', context: 'DJ · direct message',
    messages: [PvChatMessage(true, 'Can you send your rider for Sep 14?', 'Sun'), PvChatMessage(false, 'Sent! Two CDJ-3000s and a DJM-A9.', 'Sun', who: 'Amara')],
  ),
];

const _djThreads = [
  _Thread(
    area: 'Inquiries', title: 'Jordan Ellis', context: 'Booking BK-7559 · Sat, Sep 7', unread: 1, card: ('BK-7559 · Private event', 'Liberty Village · 9 PM – 1 AM · New request'),
    messages: [PvChatMessage(false, 'Hi Amara! Can you do some Afro house in the first hour?', '12 min', who: 'Jordan')],
  ),
  _Thread(
    area: 'Inquiries', title: 'Priya Shah', context: 'Booking BK-7490 · Fri, Aug 30', card: ('BK-7490 · Private event', '42 Queen St W · 8 – 11 PM'),
    messages: [PvChatMessage(false, 'Is the MC add-on included?', 'Yesterday', who: 'Priya'), PvChatMessage(true, 'It is an add-on: \$200.', 'Yesterday')],
  ),
  _Thread(
    area: 'Inquiries', title: 'Sofia Bell', context: 'Question before booking', unread: 1,
    messages: [PvChatMessage(false, 'Do you play weddings outside Toronto?', '2h', who: 'Sofia')],
  ),
  _Thread(
    area: 'Team', title: 'Neon Garden crew', context: 'Event group · invited by Midnight Social', unread: 1, members: ['Midnight Social', 'Jamie Fox', 'Nova Room (venue)', 'You'],
    card: ('Neon Garden · Sat, 31 Aug', 'Event group'),
    messages: [PvChatMessage(false, 'Set times are in the pinned note.', '5:30 PM', who: 'Jamie')],
  ),
  _Thread(
    area: 'Team', title: 'Sky Room', context: 'Venue contact',
    messages: [PvChatMessage(false, 'Load-in is through the back lane on Sep 20.', 'Fri', who: 'Sky Room')],
  ),
];

class InboxPage extends StatefulWidget {
  /// [account] is "Event organizer" or "DJ / Artist": it picks the made-up conversations.
  const InboxPage({super.key, required this.account, this.start = 'Inquiries'});

  final String account;
  final String start;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late String _tab = widget.start;
  String _query = '';

  List<_Thread> get _all => widget.account == 'DJ / Artist' ? _djThreads : _organizerThreads;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final inTab = [for (final t in _all) if (t.area == _tab) t];
    final term = _query.trim().toLowerCase();
    final shown = [
      for (final t in inTab)
        if (term.isEmpty || '${t.title} ${t.context} ${t.messages.map((m) => m.text).join(' ')}'.toLowerCase().contains(term)) t,
    ];
    int unread(String area) => _all.where((t) => t.area == area).fold(0, (s, t) => s + t.unread);
    return PvStandalone(
      title: 'Messages',
      child: PvPage(
        eyebrow: widget.account,
        title: 'Messages',
        trailing: IconButton(tooltip: 'New message', onPressed: () => pvNotConnected(context), icon: Icon(Ionicons.create_outline, color: bu.orangeSoft)),
        children: [
          PvFilterChips(
            labels: const ['Inquiries', 'Team'],
            counts: {'Inquiries': unread('Inquiries'), 'Team': unread('Team')},
            initial: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: BuSpace.m),
          Text(
            _tab == 'Inquiries'
                ? 'Guests, clients and anyone contacting you or one of your events.'
                : 'Staff, venues, DJs and collaborators. Only invited members can read these.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted),
          ),
          const SizedBox(height: BuSpace.m),
          TextField(
            key: const Key('pv-inbox-search'),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(prefixIcon: const Icon(Ionicons.search_outline, size: 18), hintText: 'Search ${_tab.toLowerCase()}'),
          ),
          if (_tab == 'Team') ...[
            const SizedBox(height: BuSpace.m),
            const PvDualActions(secondary: 'Direct message', primary: 'Event group', secondaryIcon: Ionicons.chatbubble_outline, primaryIcon: Ionicons.people_outline),
          ],
          pvGap,
          if (shown.isEmpty)
            PvEmpty(
              icon: Ionicons.chatbubbles_outline,
              title: term.isEmpty ? 'No conversations yet' : 'No matches',
              text: term.isEmpty ? 'When someone messages you or one of your events, it appears here.' : 'Nothing matches “${_query.trim()}”.',
            )
          else
            PvList([
              for (final t in shown)
                PvRowData(
                  t.title,
                  subtitle: '${t.context}\n${t.messages.last.text}',
                  initials: t.title.substring(0, 2),
                  badge: t.unread > 0 ? t.unread : null,
                  onTap: (c) => pvOpen<void>(c, PvChatPage(title: t.title, subtitle: t.context, messages: t.messages, card: t.card, members: t.members)),
                ),
            ]),
          const PvNote('Sample conversations. Real delivery and notifications need the BottlesUp backend.'),
        ],
      ),
    );
  }
}

/// One conversation: what it is about at the top, the messages, a box to write in.
class PvChatPage extends StatelessWidget {
  const PvChatPage({super.key, required this.title, required this.subtitle, required this.messages, this.card, this.members});

  final String title;
  final String subtitle;
  final List<PvChatMessage> messages;

  /// The event or booking the conversation is about.
  final (String, String)? card;
  final List<String>? members;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: text.titleMedium), Text(subtitle, style: text.bodySmall?.copyWith(color: bu.muted))],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(BuSpace.page),
                children: [
                  if (card != null)
                    BuCard(
                      padding: EdgeInsets.zero,
                      child: BuListRow(icon: Ionicons.ticket_outline, title: card!.$1, subtitle: card!.$2, showChevron: false),
                    ),
                  if (members != null) ...[
                    const SizedBox(height: BuSpace.m),
                    Text('Members: ${members!.join(', ')}', style: text.bodySmall?.copyWith(color: bu.muted)),
                  ],
                  const SizedBox(height: BuSpace.l),
                  for (final m in messages) _Bubble(message: m),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.m, BuSpace.m),
              child: Row(
                children: [
                  const Expanded(child: TextField(decoration: InputDecoration(hintText: 'Write a message'))),
                  const SizedBox(width: BuSpace.s),
                  IconButton.filled(onPressed: () => pvNotConnected(context), icon: const Icon(Ionicons.send, size: 18), tooltip: 'Send'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final PvChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: BuSpace.s + 2),
        padding: const EdgeInsets.symmetric(horizontal: BuSpace.m + 2, vertical: BuSpace.m),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? bu.orangeWash : bu.panel,
          borderRadius: BorderRadius.circular(BuRadius.card),
          border: Border.all(color: mine ? bu.orange.withValues(alpha: 0.3) : bu.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && message.who != null) Text(message.who!, style: text.labelSmall?.copyWith(color: bu.orangeSoft)),
            Text(message.text, style: text.bodyMedium),
            const SizedBox(height: 4),
            Text(message.time, style: text.labelSmall?.copyWith(color: bu.muted)),
          ],
        ),
      ),
    );
  }
}
