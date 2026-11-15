import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../providers/event_list_provider.dart';
import '../providers/event_filter_provider.dart';
import '../widgets/event_card_enhanced.dart';
import '../widgets/event_filter_bottom_sheet.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';

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

    final bu = context.bu;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.m),
            child: BuPageHeader(
              eyebrow: 'Your business',
              title: 'Events',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter button, with a dot when filters are active
                  Stack(
                    children: [
                      IconButton(
                        key: const Key('events-filter'),
                        icon: const Icon(Ionicons.filter_outline),
                        onPressed: () => _showFilterSheet(context),
                        tooltip: 'Filter Events',
                      ),
                      if (filter.hasActiveFilters)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: bu.orange, shape: BoxShape.circle)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: bu.orange,
                    borderRadius: BorderRadius.circular(BuRadius.control),
                    child: InkWell(
                      key: const Key('events-add'),
                      borderRadius: BorderRadius.circular(BuRadius.control),
                      onTap: () => context.push('/events/create'),
                      child: Tooltip(message: 'Create Event', child: const SizedBox(width: 44, height: 44, child: Icon(Ionicons.add, color: Colors.white, size: 24))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
            child: Container(
              key: const Key('events-tabs'),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: bu.panel, borderRadius: BorderRadius.circular(BuRadius.control + 2)),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: bu.raised, borderRadius: BorderRadius.circular(BuRadius.control - 2)),
                labelColor: bu.ink,
                unselectedLabelColor: bu.muted,
                labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: bu.ink),
                unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                tabs: _tabLabels.map((label) => Tab(text: label, height: 38)).toList(),
              ),
            ),
          ),
          const SizedBox(height: BuSpace.s),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
            ),
          ),
        ],
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
        padding: EdgeInsets.zero,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, 8, BuSpace.page, 100),
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
        padding: EdgeInsets.zero,
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
        padding: EdgeInsets.zero,
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
