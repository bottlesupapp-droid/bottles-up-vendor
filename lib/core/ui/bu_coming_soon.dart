import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'bu_kit.dart';

// "Coming soon": how the app says that a part of the design is not built yet. One pill, one sheet and one page, so every unfinished place looks the same and
// says the same thing. Nothing here saves or sends anything.

/// The small pill that sits beside something that is not built yet.
class BuComingSoonPill extends StatelessWidget {
  const BuComingSoonPill({super.key});

  @override
  Widget build(BuildContext context) => const BuStatusPill('Coming soon', tone: BuTone.brand);
}

/// Tells the person, in a sheet from the bottom, that [title] is on its way. [text] says what it will do.
Future<void> showComingSoon(BuildContext context, {required String title, String? text}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BuEyebrow('Coming soon'),
              const SizedBox(height: 6),
              Semantics(header: true, child: Text(title, style: theme.textTheme.headlineMedium)),
              if (text != null) ...[
                const SizedBox(height: BuSpace.s),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: context.bu.muted)),
              ],
              const SizedBox(height: BuSpace.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(key: const Key('coming-soon-close'), onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A whole screen for a part of the design that is not built yet: a heading, what it will hold (each line with its own pill), and a way back.
class BuComingSoonPage extends StatelessWidget {
  const BuComingSoonPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.intro,
    required this.icon,
    required this.will,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String intro;
  final IconData icon;

  /// What will be here, one line each: (title, what it shows, icon).
  final List<(String, String, IconData)> will;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return ListView(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xxl),
      children: [
        BuPageHeader(eyebrow: eyebrow, title: title, intro: intro, trailing: const BuComingSoonPill()),
        const SizedBox(height: BuSpace.xl),
        BuHeroCard(
          eyebrow: 'Coming soon',
          title: '$title is on its way',
          subtitle: 'It is designed and waiting to be built. Nothing here saves or sends anything yet.',
          trailing: Icon(icon, size: 40, color: bu.orangeSoft),
        ),
        const SizedBox(height: BuSpace.xl),
        const BuSectionHeader(eyebrow: 'What it will hold', title: 'On this screen'),
        const SizedBox(height: BuSpace.m),
        BuListCard(
          children: [
            for (final (t, sub, ic) in will) BuListRow(title: t, subtitle: sub, icon: ic, trailing: const BuComingSoonPill(), showChevron: false),
          ],
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: BuSpace.xl),
          OutlinedButton(key: const Key('coming-soon-action'), onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
