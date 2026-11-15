import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';

/// Notification settings, as the design draws them: how you are told, and what you are told about. **Notifications are not sent from the app yet** (no push, SMS or e-mail
/// provider is connected), so nothing here can be changed or saved: the switches are shown dimmed, and the page says so at the top. (It used to say "Notification preferences
/// saved" after a Save button that saved nothing.)
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    Widget row(String key, IconData icon, String title, String subtitle, bool on) =>
        BuListRow(key: Key(key), icon: icon, title: title, subtitle: subtitle, showChevron: false, trailing: ExcludeSemantics(child: Switch(value: on, onChanged: null)));
    Widget group(String eyebrow, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuEyebrow(eyebrow), const SizedBox(height: BuSpace.s), Opacity(opacity: 0.55, child: BuListCard(children: rows))]),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Account', title: 'Notifications'),
      body: ListView(
        key: const Key('notifications-list'),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        children: [
          BuHeroCard(
            key: const Key('notifications-soon'),
            eyebrow: 'Coming soon',
            title: 'Notifications are on their way',
            subtitle: 'The app does not send alerts yet, so there is nothing to choose or save. When it does, these are the choices you will have.',
            trailing: Icon(Ionicons.notifications, size: 36, color: bu.orangeSoft),
          ),
          const SizedBox(height: BuSpace.xl),
          group('How you are told', [
            row('notify-push', Ionicons.notifications_outline, 'Push notifications', 'On this phone', true),
            row('notify-email', Ionicons.mail_outline, 'Email', 'To your account address', true),
            row('notify-sms', Ionicons.chatbubble_outline, 'Text message', 'To your phone number', false),
          ]),
          group('What you are told about', [
            row('notify-bookings', Ionicons.calendar_outline, 'New bookings', 'When a guest books', true),
            row('notify-reminders', Ionicons.alarm_outline, 'Event reminders', 'Before a night starts', true),
            row('notify-inventory', Ionicons.cube_outline, 'Stock alerts', 'When a bottle runs low', true),
            row('notify-payments', Ionicons.card_outline, 'Payment updates', 'Payouts and refunds', true),
            row('notify-marketing', Ionicons.megaphone_outline, 'News from BottlesUp', 'Tips and product updates', false),
          ]),
          Text('Nothing here is saved or sent.', style: text.bodySmall?.copyWith(color: bu.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
