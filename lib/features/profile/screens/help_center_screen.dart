import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';

/// One question and its answer.
class FAQItem {
  final String category;
  final String question;
  final String answer;

  const FAQItem({required this.category, required this.question, required this.answer});
}

/// The questions, written for the app as it is today. Where something is not built, the answer says so and where to go instead; nothing here promises a notification, a fee or a
/// payout date the app cannot keep (an earlier version quoted a "10% service fee" and "push notifications", neither of which is settled or built).
const helpFaqs = [
  FAQItem(
    category: 'Getting started',
    question: 'How do I create my first event?',
    answer: 'Open the Overview and tap "Create event", or open More, then Events, and tap the + button. Fill in the name, venue, date and time and the ticket zones, then tap Create.',
  ),
  FAQItem(
    category: 'Getting started',
    question: 'How do I see my stock?',
    answer: 'Open More, then Inventory. Every bottle shows how many are left, and the Low and Out filters show what needs restocking. Adding, editing and removing a bottle in the app is coming soon.',
  ),
  FAQItem(
    category: 'Bookings',
    question: 'How do I view and manage bookings?',
    answer: 'Open More, then Bookings. Filter by Pending, Confirmed, Completed or Cancelled. A pending booking can be confirmed or cancelled, and a confirmed one can be marked completed.',
  ),
  FAQItem(
    category: 'Bookings',
    question: 'How do I know a booking came in?',
    answer: 'It appears under Bookings as Pending, and the Overview counts it under "to confirm". The app does not send notifications yet (coming soon), so look at the Overview or Bookings.',
  ),
  FAQItem(category: 'Events', question: 'Can I edit an event after creating it?', answer: 'Yes. Open More, then Events, tap the event, and tap the pencil at the top right to change it.'),
  FAQItem(
    category: 'Events',
    question: 'How do I cancel or delete an event?',
    answer: 'Cancelling or deleting an event in the app is not built yet. Contact Support and the BottlesUp team will help.',
  ),
  FAQItem(
    category: 'Money',
    question: 'Where do I see my sales?',
    answer: 'The Overview shows this month\'s sales and your estimated earnings, and Reports shows revenue by event. Payouts and balances in the app are coming soon.',
  ),
  FAQItem(category: 'Money', question: 'When am I paid, and what are the fees?', answer: 'The app does not show payout dates or fees yet. Contact Support for the terms that apply to your business.'),
  FAQItem(
    category: 'Account',
    question: 'How do I change my business name or phone number?',
    answer:
        'Open More and tap Edit on your card, or Settings, then Edit profile. You can change the business name, the phone number and the photo. Your email is how you sign in, so it cannot be changed there.',
  ),
  FAQItem(
    category: 'Account',
    question: 'How do I delete my account?',
    answer: 'Open More and use "Delete Account" near the bottom, or Settings, then Security. You are asked to confirm first, and it cannot be undone.',
  ),
  FAQItem(
    category: 'Troubleshooting',
    question: 'A screen says it could not load',
    answer: 'Check your connection and pull down on the screen to try again, or tap Retry. If it keeps happening, Contact Support with what you were doing.',
  ),
  FAQItem(
    category: 'Troubleshooting',
    question: 'I have a problem with a guest or a booking',
    answer: 'Try to settle it with the guest first and keep what was said. If it is not settled, Contact Support with the booking number from the Bookings screen.',
  ),
];

/// Help Center, as the design draws a list page: a search box, the way to reach support, then the questions in groups, each opening to its answer.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FAQItem> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return helpFaqs;
    return [
      for (final f in helpFaqs)
        if (f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q) || f.category.toLowerCase().contains(q)) f,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final shown = _shown;
    final categories = <String>[for (final f in shown) f.category].toSet().toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Help', title: 'Help Center'),
      body: ListView(
        key: const Key('help-list'),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        children: [
          TextField(
            key: const Key('help-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search for help',
              prefixIcon: const Icon(Ionicons.search_outline, size: 18),
              suffixIcon:
                  _query.isEmpty
                      ? null
                      : IconButton(
                        key: const Key('help-search-clear'),
                        icon: const Icon(Ionicons.close_circle),
                        onPressed:
                            () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                      ),
            ),
          ),
          const SizedBox(height: BuSpace.l),
          if (_query.isEmpty) ...[
            BuListCard(
              children: [
                BuListRow(
                  key: const Key('help-contact'),
                  icon: Ionicons.chatbubbles_outline,
                  title: 'Contact Support',
                  subtitle: 'Get help from the BottlesUp team',
                  onTap: () => context.push('/support/contact'),
                ),
              ],
            ),
            const SizedBox(height: BuSpace.xl),
          ],
          if (shown.isEmpty)
            BuCard(key: const Key('help-none'), child: Text('Nothing matches "$_query". Try another word, or Contact Support.', style: text.bodyMedium?.copyWith(color: bu.muted)))
          else
            for (final category in categories) ...[
              BuEyebrow(category),
              const SizedBox(height: BuSpace.s),
              BuListCard(
                children: [
                  for (final f in shown.where((f) => f.category == category))
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: Key('faq-${helpFaqs.indexOf(f)}'),
                        tilePadding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: 2),
                        childrenPadding: const EdgeInsets.fromLTRB(BuSpace.l, 0, BuSpace.l, BuSpace.l),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        iconColor: bu.orange,
                        collapsedIconColor: bu.muted,
                        title: Text(f.question, style: text.titleSmall),
                        children: [Text(f.answer, style: text.bodyMedium?.copyWith(color: bu.soft, height: 1.45))],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BuSpace.xl),
            ],
        ],
      ),
    );
  }
}
