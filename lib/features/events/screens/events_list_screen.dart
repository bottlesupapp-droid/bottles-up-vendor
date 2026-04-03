import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../providers/event_list_provider.dart';
import '../providers/event_filter_provider.dart';
import '../widgets/event_card_enhanced.dart';
import '../widgets/event_filter_bottom_sheet.dart';
import '../../../shared/widgets/responsive_wrapper.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['active', 'draft', 'past', 'templates'];
  final List<String> _tabLabels = ['Active', 'Drafts', 'Past', 'Templates'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(eventFilterProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // Filter button with badge if filters are active
          Stack(
            children: [
              IconButton(
                icon: const Icon(Ionicons.filter_outline),
                onPressed: () => _showFilterSheet(context),
                tooltip: 'Filter Events',
              ),
              if (filter.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Ionicons.add_outline),
            onPressed: () => context.push('/events/create'),
            tooltip: 'Create Event',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    final eventsAsync = ref.watch(filteredEventsProvider(tab));

    return eventsAsync.when(
      data: (events) => _buildEventsContent(events, tab),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error, tab),
    );
  }

  Widget _buildEventsContent(List<Map<String, dynamic>> events, String tab) {
    if (events.isEmpty) {
      return _buildEmptyState(tab);
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(filteredEventsProvider(tab)),
      child: ResponsiveWrapper(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCardEnhanced(
              event: event,
              onTap: () => context.push('/events/${event['id']}'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    final theme = Theme.of(context);

    String title;
    String subtitle;
    String buttonLabel;
    IconData icon;

    switch (tab) {
      case 'draft':
        title = 'No Draft Events';
        subtitle = 'Events you save as drafts will appear here';
        buttonLabel = 'Create Draft';
        icon = Ionicons.document_outline;
        break;
      case 'past':
        title = 'No Past Events';
        subtitle = 'Completed and cancelled events will appear here';
        buttonLabel = 'Create Event';
        icon = Ionicons.time_outline;
        break;
      case 'templates':
        title = 'No Templates';
        subtitle = 'Save events as templates for quick reuse';
        buttonLabel = 'Create Event';
        icon = Ionicons.copy_outline;
        break;
      case 'active':
      default:
        title = 'No Active Events';
        subtitle = 'Create your first event to start managing bookings';
        buttonLabel = 'Create Event';
        icon = Ionicons.calendar_outline;
        break;
    }

    return Center(
      child: ResponsiveWrapper(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/events/create'),
              icon: const Icon(Ionicons.add_outline),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, String tab) {
    final theme = Theme.of(context);

    return Center(
      child: ResponsiveWrapper(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.warning_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Events',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => ref.invalidate(filteredEventsProvider(tab)),
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) async {
    final citiesAsync = ref.read(distinctCitiesProvider);
    final cities = citiesAsync.asData?.value ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => EventFilterBottomSheet(
          currentFilter: ref.read(eventFilterProvider),
          availableCities: cities,
          onApply: (filter) {
            ref.read(eventFilterProvider.notifier).updateFilter(filter);
            // Invalidate all tab providers to refresh with new filter
            for (final tab in _tabs) {
              ref.invalidate(filteredEventsProvider(tab));
            }
          },
        ),
      ),
    );
  }
}
