import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/owner_rules.dart';

Future<void> _defaultCopy(String text) => Clipboard.setData(ClipboardData(text: text));
Future<void> _defaultOpen(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Where guests book at this venue: the address, a Copy button, a QR code, and whether it works yet. It points at the existing
/// public venue page; only a published venue's link works, so a draft says so instead of handing out a "not found" page.
/// Short addresses and counting the bookings that came through a link are not available yet.
class BookingLinkCard extends StatelessWidget {
  const BookingLinkCard({
    super.key,
    required this.venue,
    this.site,
    this.copy = _defaultCopy,
    this.open = _defaultOpen,
  });

  final OrgVenue venue;

  /// The site the link points at. Defaults to this build's (SITE_URL or the real site).
  final String? site;
  final Future<void> Function(String text) copy;
  final Future<void> Function(Uri uri) open;

  String get link => bookingLink(site ?? siteUrl, id: venue.id, slug: venue.slug);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = venue.isLive;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        Text('Booking link', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(12)),
          child: SelectableText(link, key: const Key('booking-link'), style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('copy-link'),
                icon: const Icon(Ionicons.copy_outline, size: 18),
                label: const Text('Copy link'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await copy(link);
                    messenger.showSnackBar(const SnackBar(content: Text('Link copied.')));
                  } catch (_) {
                    messenger.showSnackBar(const SnackBar(content: Text('Could not copy. Select the link and copy it.')));
                  }
                },
              ),
            ),
            if (live) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('open-link'),
                  icon: const Icon(Ionicons.open_outline, size: 18),
                  label: const Text('Preview'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await open(Uri.parse(link));
                    } catch (_) {
                      messenger.showSnackBar(const SnackBar(content: Text('This could not be opened on this phone.')));
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          linkNote(venue.status),
          key: const Key('link-note'),
          style: theme.textTheme.bodyMedium?.copyWith(color: live ? const Color(0xFF66BB6A) : const Color(0xFFFFB300)),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(
              key: const Key('booking-qr'),
              data: link,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              semanticsLabel: 'QR code for the ${venue.name} booking link',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Short venue addresses and counting the bookings that came through this link are not available yet.',
          key: const Key('link-footnote'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
