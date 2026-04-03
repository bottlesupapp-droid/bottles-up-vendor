import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import 'venue_proposal_screen.dart';

class VenueDetailScreen extends ConsumerWidget {
  final Venue venue;

  const VenueDetailScreen({
    super.key,
    required this.venue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentVendorUserProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                venue.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: venue.gallery.isNotEmpty
                  ? Image.network(
                      venue.gallery.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.location_city, size: 80),
                      ),
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.location_city, size: 80),
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  _buildStatusBadge(context),

                  const SizedBox(height: 24),

                  // Location
                  if (venue.fullAddress != null)
                    _buildInfoSection(
                      context,
                      icon: Icons.location_on,
                      title: 'Location',
                      content: venue.fullAddress!,
                    ),

                  const SizedBox(height: 16),

                  // Capacity
                  if (venue.capacity != null)
                    _buildInfoSection(
                      context,
                      icon: Icons.people,
                      title: 'Capacity',
                      content: '${venue.capacity} guests',
                    ),

                  const SizedBox(height: 24),

                  // Gallery
                  if (venue.gallery.length > 1) ...[
                    Text(
                      'Gallery',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: venue.gallery.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                venue.gallery[index],
                                width: 160,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 160,
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // License Documents (if any)
                  if (venue.licenseDocuments.isNotEmpty) ...[
                    Text(
                      'Verified',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${venue.licenseDocuments.length} license document(s) on file',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Button
                  if (userAsync != null && userAsync.role == 'organizer')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToProposal(context, userAsync),
                        icon: const Icon(Icons.send),
                        label: const Text('Send Event Proposal'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    String statusText;

    switch (venue.status) {
      case VenueStatus.active:
        badgeColor = Colors.green;
        statusText = 'Active';
        break;
      case VenueStatus.approved:
        badgeColor = Colors.blue;
        statusText = 'Approved';
        break;
      case VenueStatus.pending:
        badgeColor = Colors.orange;
        statusText = 'Pending';
        break;
      case VenueStatus.suspended:
        badgeColor = Colors.red;
        statusText = 'Suspended';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToProposal(BuildContext context, VendorUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VenueProposalScreen(
          venue: venue,
          organizer: user,
        ),
      ),
    );
  }
}
