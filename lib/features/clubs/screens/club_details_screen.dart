import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/plain_error.dart';
import '../../../features/venues/providers/venues_provider.dart';
import '../../../shared/models/venue_model.dart';
import 'clubs_list_screen.dart' show venueSetupItems;

/// The tabs of a venue page, in the design's order. The three marked [venueTabsSoon] are designed and not built for this kind of account.
const venueTabs = ['Setup', 'Page', 'Tables', 'Menu & signs', 'Photos', 'Booking link'];
const venueTabsSoon = {'Tables', 'Menu & signs', 'Booking link'};

/// What each of the five setup steps asks for, in the design's words.
const _setupHelp = {
  'Photos': 'Show guests the room',
  'Details': 'Type of venue, music and amenities',
  'Description': 'A few lines about the venue',
  'Address': 'Street, city and province',
  'Capacity': 'How many people it holds',
};

/// The steps of the design's setup list that this kind of account cannot do yet (they live in a workspace). Each opens the Coming soon sheet.
const _setupSoon = [
  ('Rooms and floor plans', 'Create areas where bookings can be placed', Ionicons.grid_outline),
  ('Tables and capacities', 'Set minimum spends and group sizes', Ionicons.restaurant_outline),
  ('Booking rules', 'Days, times, and how far ahead guests can book', Ionicons.calendar_outline),
  ('Payment settings', 'Deposits, card holds, and cancellation policy', Ionicons.card_outline),
  ('Team invited', 'Add managers, door staff, and servers', Ionicons.people_outline),
];

/// A venue's page, as the design draws "Manage venue": a back button, the venue's name and whether it is open, then the sections as pill tabs. Setup shows how far the
/// venue is and each step; Page shows what guests will read; Photos the gallery. Tables, Menu and Booking link are designed and say "Coming soon".
class ClubDetailsScreen extends ConsumerStatefulWidget {
  const ClubDetailsScreen({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends ConsumerState<ClubDetailsScreen> {
  String _tab = venueTabs.first;

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueByIdProvider(widget.clubId));
    final top = MediaQuery.of(context).padding.top + BuSpace.m;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: venueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(couldNotLoad('venue', e))),
        data: (venue) {
          if (venue == null) {
            return Padding(
              padding: EdgeInsets.fromLTRB(BuSpace.page, top, BuSpace.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuDetailHeader(eyebrow: 'Venue', title: 'Venue not found', onBack: () => context.pop()),
                  const Spacer(),
                  const Center(child: Icon(Ionicons.search_outline, size: 48)),
                  const SizedBox(height: 12),
                  const Center(child: Text('Venue not found')),
                  Center(child: TextButton(onPressed: () => context.pop(), child: const Text('Go Back'))),
                  const Spacer(flex: 2),
                ],
              ),
            );
          }
          return ListView(
            key: const Key('venue-page'),
            padding: EdgeInsets.fromLTRB(BuSpace.page, top, BuSpace.page, BuSpace.xxl),
            children: [
              BuDetailHeader(eyebrow: venue.name, title: 'Manage venue', onBack: () => context.pop(), trailing: _StatusPill(venue.status)),
              const SizedBox(height: BuSpace.l),
              BuPillTabs(labels: venueTabs, selected: _tab, soon: venueTabsSoon, tabKeyPrefix: 'venue-tab', onSelected: (t) => setState(() => _tab = t)),
              const SizedBox(height: BuSpace.l),
              switch (_tab) {
                'Setup' => _SetupTab(venue: venue, onDelete: () => _confirmDelete(context, venue)),
                'Page' => _PageTab(venue: venue),
                'Photos' => _PhotosTab(venue: venue),
                'Tables' => const _SoonTab(title: 'Tables', icon: Ionicons.restaurant_outline, text: 'Add the tables and booths guests can book, with their minimum spend and the size of the group.'),
                'Menu & signs' => const _SoonTab(title: 'Menu & signs', icon: Ionicons.wine_outline, text: 'The bottle menu and the signs a guest can ask for, with prices you set.'),
                _ => const _SoonTab(
                  title: 'Booking link',
                  icon: Ionicons.link_outline,
                  text: 'A link and a code guests can scan to book this venue, for your website, your social channels and printed menus.',
                ),
              },
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Venue venue) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Venue'),
            content: Text('Are you sure you want to delete "${venue.name}"? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final bu = context.bu;
                  try {
                    final service = ref.read(venueRequestServiceProvider);
                    await service.deleteVenue(venue.id);
                    ref.invalidate(myVenuesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Venue deleted'), backgroundColor: bu.green));
                      context.go('/clubs');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(couldNot('delete', e)), backgroundColor: bu.red));
                    }
                  }
                },
                child: Text('Delete', style: TextStyle(color: context.bu.red)),
              ),
            ],
          ),
    );
  }
}

/// "Open" for a live venue, as the design says it; the other states keep their own word.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final VenueStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      VenueStatus.active => ('Open', BuTone.good),
      VenueStatus.approved => ('Approved', BuTone.brand),
      VenueStatus.pending => ('Pending', BuTone.attention),
      VenueStatus.suspended => ('Suspended', BuTone.bad),
    };
    return KeyedSubtree(key: const Key('venue-status'), child: BuStatusPill(label, tone: tone));
  }
}

class _SetupTab extends StatelessWidget {
  const _SetupTab({required this.venue, required this.onDelete});

  final Venue venue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final items = venueSetupItems(venue);
    final done = items.where((i) => i.$2).length;
    final complete = done == items.length;
    void edit() => context.push('/clubs/${venue.id}/edit', extra: venue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const BuEyebrow('Venue setup'), const SizedBox(height: 4), Text('$done of ${items.length} complete', key: const Key('venue-setup-progress'), style: text.titleLarge)],
                    ),
                  ),
                  if (complete) Icon(Ionicons.checkmark_circle, color: bu.green, size: 26),
                ],
              ),
              const SizedBox(height: BuSpace.m),
              ClipRRect(
                borderRadius: BorderRadius.circular(BuRadius.pill),
                child: LinearProgressIndicator(value: done / items.length, minHeight: 6, backgroundColor: bu.line, valueColor: AlwaysStoppedAnimation(complete ? bu.green : bu.orange)),
              ),
            ],
          ),
        ),
        const SizedBox(height: BuSpace.l),
        BuListCard(
          children: [
            for (final (title, isDone) in items)
              BuListRow(
                key: Key('setup-$title'),
                title: title,
                subtitle: _setupHelp[title],
                leading: _Check(done: isDone),
                trailing: Text(isDone ? 'Done' : 'Set up', style: text.labelLarge?.copyWith(color: isDone ? bu.green : bu.orange, fontWeight: FontWeight.w700)),
                onTap: edit,
              ),
          ],
        ),
        const SizedBox(height: BuSpace.xl),
        const BuSectionHeader(eyebrow: 'In your workspace', title: 'More setup'),
        const SizedBox(height: BuSpace.m),
        BuListCard(
          children: [
            for (final (title, sub, icon) in _setupSoon)
              BuListRow(
                key: Key('setup-soon-$title'),
                title: title,
                subtitle: sub,
                icon: icon,
                trailing: const BuComingSoonPill(),
                showChevron: false,
                onTap: () => showComingSoon(context, title: title, text: sub),
              ),
          ],
        ),
        const SizedBox(height: BuSpace.xl),
        SizedBox(width: double.infinity, child: FilledButton.icon(key: const Key('venue-edit'), onPressed: edit, icon: const Icon(Ionicons.create_outline), label: const Text('Edit venue'))),
        const SizedBox(height: BuSpace.m),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('venue-delete'),
            onPressed: onDelete,
            icon: Icon(Ionicons.trash_outline, color: bu.red),
            label: Text('Delete venue', style: TextStyle(color: bu.red)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: bu.red.withValues(alpha: 0.6))),
          ),
        ),
      ],
    );
  }
}

/// The round tick of a setup step: filled green when done, an empty ring when not.
class _Check extends StatelessWidget {
  const _Check({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: done ? bu.green : Colors.transparent, border: Border.all(color: done ? bu.green : bu.line, width: 1.5)),
      child: done ? Icon(Icons.check_rounded, size: 17, color: bu.bg) : null,
    );
  }
}

/// What guests will read about the venue, from what the venue has. A line that has nothing behind it is left out.
class _PageTab extends StatelessWidget {
  const _PageTab({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final sl = venue.socialLinks ?? {};
    final genres = (sl['music_genres'] as List?)?.map((g) => g.toString()).toList() ?? const <String>[];
    final amenities = (sl['amenities'] as List?)?.map((g) => g.toString()).toList() ?? const <String>[];
    final facts = <(String, String)>[
      if (sl['venue_type'] != null) ('Type', '${sl['venue_type']}'),
      if (sl['min_age'] != null) ('Age requirement', '${sl['min_age']}+'),
      if (sl['dress_code'] != null) ('Dress code', '${sl['dress_code']}'),
      if (venue.capacity != null) ('Capacity', '${venue.capacity}'),
      if (sl['vip_booths'] != null) ('VIP booths', '${sl['vip_booths']}'),
      if (sl['side_tables'] != null) ('Side tables', '${sl['side_tables']}'),
    ];
    final contact = <(String, String)>[if (venue.phone != null) ('Phone', venue.phone!), if (venue.email != null) ('Email', venue.email!)];
    final description = (venue.description ?? '').trim();
    final address = (venue.fullAddress ?? '').trim();

    Widget block(String eyebrow, Widget child, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.l),
      child: SizedBox(
        width: double.infinity,
        child: BuCard(key: key, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BuEyebrow(eyebrow), const SizedBox(height: BuSpace.s), child])),
      ),
    );
    Widget lines(List<(String, String)> rows) => Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SizedBox(width: 130, child: Text(k, style: text.bodyMedium?.copyWith(color: bu.muted))), Expanded(child: Text(v, style: text.bodyMedium))],
            ),
          ),
      ],
    );
    Widget chips(List<String> labels) => Wrap(spacing: 8, runSpacing: 8, children: [for (final g in labels) Chip(label: Text(g), visualDensity: VisualDensity.compact)]);

    final empty = description.isEmpty && address.isEmpty && facts.isEmpty && genres.isEmpty && amenities.isEmpty && contact.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (empty)
          SizedBox(
            width: double.infinity,
            child: BuCard(
              key: const Key('venue-page-empty'),
              child: Text('Nothing on the page yet. Add the venue\'s details and a description so guests know what to expect.', style: text.bodyMedium?.copyWith(color: bu.muted)),
            ),
          ),
        if (address.isNotEmpty) block('Location', Text(address, style: text.bodyMedium), key: const Key('venue-location')),
        if (description.isNotEmpty) block('About', Text(description, style: text.bodyMedium), key: const Key('venue-about')),
        if (facts.isNotEmpty) block('Venue details', lines(facts)),
        if (genres.isNotEmpty) block('Music', chips(genres)),
        if (amenities.isNotEmpty) block('Amenities', chips(amenities)),
        if (contact.isNotEmpty) block('Contact', lines(contact)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('venue-page-edit'),
            onPressed: () => context.push('/clubs/${venue.id}/edit', extra: venue),
            icon: const Icon(Ionicons.create_outline),
            label: const Text('Edit page'),
          ),
        ),
      ],
    );
  }
}

/// The venue's photos in a grid, the first one as the cover.
class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final photos = venue.gallery;
    Widget frame(String url, {bool cover = false}) => ClipRRect(
      borderRadius: BorderRadius.circular(BuRadius.control),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: bu.panel2, child: Icon(Ionicons.image_outline, color: bu.muted))),
          if (cover) Positioned(left: 8, top: 8, child: const BuStatusPill('Cover', tone: BuTone.brand)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(photos.isEmpty ? 'No photos yet' : '${photos.length} ${photos.length == 1 ? 'photo' : 'photos'}', key: const Key('venue-photo-count'), style: text.titleMedium)),
            TextButton.icon(
              key: const Key('venue-photos-edit'),
              onPressed: () => context.push('/clubs/${venue.id}/edit', extra: venue),
              icon: const Icon(Ionicons.add),
              label: Text(photos.isEmpty ? 'Add photos' : 'Edit photos'),
            ),
          ],
        ),
        const SizedBox(height: BuSpace.s),
        if (photos.isEmpty)
          BuCard(
            key: const Key('venue-photos-empty'),
            child: Row(
              children: [
                BuIconTile(icon: Ionicons.images_outline, size: 44),
                const SizedBox(width: BuSpace.m),
                Expanded(child: Text('Guests choose a venue by its photos. Add a few of the room, the bar and a busy night.', style: text.bodyMedium?.copyWith(color: bu.muted))),
              ],
            ),
          )
        else
          GridView.count(
            key: const Key('venue-photos-grid'),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (var i = 0; i < photos.length; i++) frame(photos[i], cover: i == 0)],
          ),
        const SizedBox(height: BuSpace.l),
        BuListCard(
          children: [
            BuListRow(
              key: const Key('venue-photos-video'),
              title: 'Video',
              subtitle: 'A short film of the venue at its best',
              icon: Ionicons.videocam_outline,
              trailing: const BuComingSoonPill(),
              showChevron: false,
              onTap: () => showComingSoon(context, title: 'Venue video', text: 'Add a short film of the venue to its page.'),
            ),
            BuListRow(
              key: const Key('venue-photos-reorder'),
              title: 'Reorder and choose a cover',
              subtitle: 'Drag photos into the order guests see them',
              icon: Ionicons.swap_vertical_outline,
              trailing: const BuComingSoonPill(),
              showChevron: false,
              onTap: () => showComingSoon(context, title: 'Reorder photos', text: 'Drag your photos into the order you want and pick which one is the cover.'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A section that is designed and not built for this kind of account: a card that says what it will do, with the pill.
class _SoonTab extends StatelessWidget {
  const _SoonTab({required this.title, required this.icon, required this.text});

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    return BuHeroCard(key: Key('venue-soon-$title'), eyebrow: 'Coming soon', title: '$title is on its way', subtitle: text, trailing: Icon(icon, size: 38, color: bu.orangeSoft));
  }
}
