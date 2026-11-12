import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../preview_catalog.dart';
import '../preview_config.dart';
import '../widgets/pv_kit.dart';

/// Opens the list of sample screens (from More, or from the "no business yet" page).
void openPreviewGallery(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(PreviewRoutes.gallery);
  } else {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const PreviewGalleryScreen()));
  }
}

void _openEntry(BuildContext context, PreviewEntry entry) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(PreviewRoutes.screen(entry.id));
  } else {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (c) => entry.build(c)));
  }
}

/// The list of sample screens, by group.
class PreviewGalleryScreen extends StatelessWidget {
  const PreviewGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = previewCatalog;
    return Scaffold(
      appBar: AppBar(title: const Text('Sample screens')),
      body: SafeArea(
        child: PvPage(
          showNote: false,
          eyebrow: 'Design preview',
          title: 'Sample screens',
          intro: 'Parts of the Business app design that are not built yet. Each one is a layout with made-up names and numbers.',
          children: [
            for (final group in PreviewGroup.values)
              if (entries.any((e) => e.group == group))
                PvSection(
                  title: group.label,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: BuSpace.m),
                      child: Text(group.blurb, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.bu.muted)),
                    ),
                    BuListCard(
                      children: [
                        for (final e in entries.where((e) => e.group == group))
                          BuListRow(
                            key: Key('preview-${e.id}'),
                            icon: e.icon,
                            title: e.title,
                            subtitle: e.subtitle,
                            maxSubtitleLines: 3,
                            trailing: const BuStatusPill('Sample', tone: BuTone.attention),
                            onTap: () => _openEntry(context, e),
                          ),
                      ],
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// One sample screen, by the id in the address. An id that does not exist says so instead of a blank page.
class PreviewScreenHost extends StatelessWidget {
  const PreviewScreenHost({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final entry = previewEntryFor(id);
    if (entry == null) {
      return PvStandalone(
        title: 'Sample screen',
        child: ListView(
          padding: const EdgeInsets.all(BuSpace.page),
          children: const [PvEmpty(icon: Ionicons.help_circle_outline, title: 'There is no such sample screen', text: 'Go back to the list and pick one.')],
        ),
      );
    }
    return entry.build(context);
  }
}

/// A row for the More tab (and anywhere else) that opens the gallery. Shows nothing when the sample screens are switched off.
class PreviewMoreRow extends StatelessWidget {
  const PreviewMoreRow({super.key, this.enabled = kPreviewsEnabled});

  /// Whether the sample screens are switched on (a test passes it; the app uses the build setting).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: BuSpace.l),
      // A plain card, not a grouped list: the More tab's own list stays the only grouped card on the page.
      child: BuCard(
        padding: EdgeInsets.zero,
        child: BuListRow(
          key: const Key('more-previews'),
          icon: Ionicons.flask_outline,
          title: 'Sample screens',
          subtitle: 'Parts of the design that are not built yet: DJ, Ambassador, Event Lead and more.',
          maxSubtitleLines: 3,
          onTap: () => openPreviewGallery(context),
        ),
      ),
    );
  }
}
