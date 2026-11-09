import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../widgets/pv_kit.dart';
import '../widgets/pv_mini_app.dart';

/// Parts of the design that belong to the whole app, not to one role: settings with the appearance choice, the launch screen, the access
/// states (invitation, expired, pending), the support sheet and the shift details. Sample screens (see `preview_config.dart`).

// ───────────────────────── Settings and appearance ─────────────────────────

/// Settings as the design draws them: the appearance (Dark, Light, or match the phone), the notifications, and sign out. The app has only the
/// dark look today (see `docs/VENDOR_REDESIGN.md`, decision 1), so the Light choice here is a sample of the control, not a working theme.
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  String _appearance = 'Dark';

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return PvStandalone(
      title: 'Settings',
      child: PvPage(
        eyebrow: 'Account',
        title: 'Settings',
        children: [
          PvSection(eyebrow: 'Display', title: 'Appearance', children: [
            BuCard(
              padding: const EdgeInsets.all(BuSpace.m),
              child: Row(
                children: [
                  for (final option in const [('Dark', Ionicons.moon_outline), ('Light', Ionicons.sunny_outline), ('System', Ionicons.phone_portrait_outline)])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          key: Key('pv-appearance-${option.$1}'),
                          borderRadius: BorderRadius.circular(BuRadius.control),
                          onTap: () => setState(() => _appearance = option.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: BuSpace.l),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(BuRadius.control),
                              color: _appearance == option.$1 ? bu.orangeWash : bu.panel2,
                              border: Border.all(color: _appearance == option.$1 ? bu.orange : bu.line),
                            ),
                            child: Column(
                              children: [
                                Icon(option.$2, color: _appearance == option.$1 ? bu.orangeSoft : bu.muted),
                                const SizedBox(height: 6),
                                Text(option.$1, style: text.labelMedium),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PvNote(_appearance == 'Dark' ? 'The app uses the dark look.' : 'Sample only: the light look is not built yet, so the app stays dark.'),
          ]),
          const PvSection(eyebrow: 'Notifications', title: 'What the app tells you', children: [
            PvSwitchCard(title: 'Bookings', subtitle: 'New requests and changes', initial: true),
            SizedBox(height: BuSpace.s),
            PvSwitchCard(title: 'Shifts', subtitle: 'Start times and swaps', initial: true),
            SizedBox(height: BuSpace.s),
            PvSwitchCard(title: 'Invitations', subtitle: 'Teams and events that invite you', initial: true),
            SizedBox(height: BuSpace.s),
            PvSwitchCard(title: 'Orders', subtitle: 'Every bottle order at your tables'),
          ]),
          PvSecondary('Leave the sample', icon: Ionicons.log_out_outline, onPressed: pvLeave),
        ],
      ),
    );
  }
}

// ───────────────────────── Sheets ─────────────────────────

void showSupportSheet(BuildContext context) {
  showPvSheet(
    context,
    eyebrow: 'Help',
    title: 'Support',
    child: const PvList([
      PvRowData('Chat with support', subtitle: 'Typical reply under 5 minutes', icon: Ionicons.chatbubble_outline),
      PvRowData('Request a call', subtitle: "We'll call the number on your account", icon: Ionicons.call_outline),
      PvRowData('Help articles', subtitle: 'Bookings, payments, check-in and payouts', icon: Ionicons.document_text_outline),
    ]),
  );
}

void showShiftSheet(BuildContext context, {required String place, required String hours}) {
  showPvSheet(
    context,
    eyebrow: 'Your shift',
    title: 'Shift details',
    child: PvLines([
      ('Location', place),
      ('Shift', hours),
      ('Break', '11:30 PM · 30 minutes'),
      ('Manager on duty', 'Jordan Blake'),
      ('Date', 'Tonight'),
    ]),
  );
}

// ───────────────────────── Launch screen ─────────────────────────

/// The screen shown while the app starts: the logo still, the name, "BUSINESS", and a thin orange cue that turns. The design's bottle
/// animation (it pops and splashes) is a drawing from the design file; this is the still version.
class LaunchScreenPage extends StatelessWidget {
  const LaunchScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: BuBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BuLogoMark(size: 104),
                    const SizedBox(height: BuSpace.l),
                    const BuWordmark(size: 40),
                    const SizedBox(height: BuSpace.s),
                    const BuEyebrow('Business'),
                    const SizedBox(height: BuSpace.xl),
                    SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: bu.orange)),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: BuSpace.l,
                child: Column(
                  children: [
                    const PvSampleNote(),
                    TextButton(onPressed: () => pvLeave(context), child: Text('Close', style: text.labelLarge)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Access states ─────────────────────────

/// What a person sees when an invitation or an access request is not simply "in": invited, expired, or waiting for an administrator.
class AccessStatesPage extends StatefulWidget {
  const AccessStatesPage({super.key});

  @override
  State<AccessStatesPage> createState() => _AccessStatesPageState();
}

class _AccessStatesPageState extends State<AccessStatesPage> {
  String _state = 'Invitation';

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final (icon, color, title, body, button) = switch (_state) {
      'Expired' => (Ionicons.warning_outline, bu.amber, 'Invitation expired', 'Ask an owner or organizer to send a new invitation.', 'Request a new invite'),
      'Pending' => (Ionicons.time_outline, bu.amber, 'Access pending', 'Your request is waiting for an administrator to approve it.', 'Check again'),
      _ => (Ionicons.ticket_outline, bu.green, "You're invited", 'Join Nova Room as a server. Accepting signs you in with this invitation.', 'Accept invitation'),
    };
    return PvStandalone(
      title: 'Access states',
      child: PvPage(
        eyebrow: 'Invitations and access',
        title: 'Access states',
        children: [
          PvFilterChips(labels: const ['Invitation', 'Expired', 'Pending'], initial: _state, onChanged: (v) => setState(() => _state = v)),
          const SizedBox(height: BuSpace.xl),
          BuCard(
            padding: const EdgeInsets.all(BuSpace.xl),
            child: Column(
              children: [
                BuIconTile(icon: icon, size: 64, color: color, background: color.withValues(alpha: 0.12)),
                const SizedBox(height: BuSpace.l),
                Text(title, textAlign: TextAlign.center, style: text.titleLarge),
                const SizedBox(height: BuSpace.s),
                Text(body, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: bu.muted)),
                const SizedBox(height: BuSpace.xl),
                PvPrimary(button),
              ],
            ),
          ),
          const PvNote('The app already has an "accept invitation" screen; these are the expired and pending states the design adds around it.'),
        ],
      ),
    );
  }
}
