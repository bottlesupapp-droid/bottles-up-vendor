import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';

/// Settings, as the design draws it: a Display card (the app is dark for now, Light and "match my phone" are shown as Coming soon), then the account's pages as grouped rows
/// (each opens the page that exists), help, and the legal pages.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;

    Widget group(String eyebrow, List<Widget> rows, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuEyebrow(eyebrow), const SizedBox(height: BuSpace.s), BuListCard(key: key, children: rows)]),
    );
    Widget row(String key, IconData icon, String title, String subtitle, String path) => BuListRow(key: Key(key), icon: icon, title: title, subtitle: subtitle, onTap: () => context.push(path));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Account', title: 'Settings'),
      body: ListView(
        key: const Key('settings-list'),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        children: [
          const BuEyebrow('Display'),
          const SizedBox(height: BuSpace.s),
          BuCard(
            key: const Key('settings-appearance'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('The app is dark for now.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: bu.muted)),
                const SizedBox(height: BuSpace.m),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: bu.panel2, borderRadius: BorderRadius.circular(BuRadius.control)),
                  child: Row(
                    children: [
                      Expanded(child: _Segment(label: 'Dark', selected: true, segmentKey: const Key('appearance-dark'))),
                      Expanded(
                        child: _Segment(
                          label: 'Light',
                          segmentKey: const Key('appearance-light'),
                          onTap: () => showComingSoon(context, title: 'Light appearance', text: 'A light look for the app, for people who prefer it in daylight.'),
                        ),
                      ),
                      Expanded(
                        child: _Segment(
                          label: 'Auto',
                          segmentKey: const Key('appearance-auto'),
                          onTap: () => showComingSoon(context, title: 'Match my phone', text: 'Follow the phone: light by day, dark at night.'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BuSpace.s),
                const Align(alignment: Alignment.centerRight, child: BuComingSoonPill()),
              ],
            ),
          ),
          const SizedBox(height: BuSpace.xl),
          group('Account', [
            row('settings-edit-profile', Ionicons.person_outline, 'Edit profile', 'Your name, photo and phone', '/profile/edit'),
            row('settings-business', Ionicons.business_outline, 'Business details', 'Business name, address and contact', '/profile/business'),
            row('settings-security', Ionicons.lock_closed_outline, 'Security', 'Password and sign-in', '/profile/security'),
            BuListRow(
              key: const Key('settings-notifications'),
              icon: Ionicons.notifications_outline,
              title: 'Notifications',
              subtitle: 'Choose what you are told about',
              trailing: const BuComingSoonPill(),
              showChevron: false,
              onTap: () => context.push('/profile/notifications'),
            ),
            BuListRow(
              key: const Key('settings-billing'),
              icon: Ionicons.card_outline,
              title: 'Billing and payouts',
              subtitle: 'Payout account, schedule and plan',
              trailing: const BuComingSoonPill(),
              showChevron: false,
              onTap: () => showComingSoon(context, title: 'Billing and payouts', text: 'Your payout account, when you are paid and your plan, in one place.'),
            ),
          ]),
          group('Help', [
            row('settings-help', Ionicons.help_circle_outline, 'Help Center', 'Answers to common questions', '/support/help'),
            row('settings-support', Ionicons.chatbubbles_outline, 'Contact Support', 'Ask the BottlesUp team', '/support/contact'),
          ]),
          group('About', [
            row('settings-terms', Ionicons.document_text_outline, 'Terms of Service', 'Legal terms and conditions', '/legal/terms'),
            row('settings-privacy', Ionicons.shield_checkmark_outline, 'Privacy Policy', 'How we protect your data', '/legal/privacy'),
            row('settings-about', Ionicons.information_circle_outline, 'About BottlesUp Business', 'Version and what the app does', '/about'),
          ]),
        ],
      ),
    );
  }
}

/// One of the three choices of the Display card: the chosen one is raised, the others are plain.
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.segmentKey, this.selected = false, this.onTap});

  final String label;
  final Key segmentKey;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: segmentKey,
        borderRadius: BorderRadius.circular(BuRadius.control - 4),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? bu.raised : Colors.transparent, borderRadius: BorderRadius.circular(BuRadius.control - 4)),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? bu.ink : bu.muted, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
