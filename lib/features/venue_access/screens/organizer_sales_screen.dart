import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../night/logic/report_pdf.dart';
import '../../night/providers/night_providers.dart' show shareReportProvider;
import '../../ops/widgets/ops_async_view.dart';
import '../../organizer_events/logic/organizer_events_rules.dart';
import '../../organizer_events/providers/organizer_events_providers.dart';
import '../../workspace/models/workspace.dart';
import '../logic/access_rules.dart';
import '../providers/venue_access_providers.dart';
import '../widgets/document_cards.dart';

/// Sales (organizer): for one event, the organizer's own paid tickets (sold, checked in, money, by ticket type) and, from each club that hosts it, only what that club has chosen to share.
/// Read only. Can be shared as a PDF with the same words; the PDF never holds more than the screen.
class OrganizerSalesScreen extends ConsumerStatefulWidget {
  const OrganizerSalesScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<OrganizerSalesScreen> createState() => _OrganizerSalesScreenState();
}

class _OrganizerSalesScreenState extends ConsumerState<OrganizerSalesScreen> {
  String? _eventId;
  bool _sharing = false;

  Future<void> _share(EventSales sales) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = buildSalesDocument(sales);
      final bytes = await buildReportPdf(doc);
      await ref.read(shareReportProvider)(bytes, doc.fileName);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('The PDF could not be made or shared. Try again.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(organizerEventsProvider(widget.workspace.orgId));
    return ListView(
      key: const Key('organizer-sales'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        Text('Sales', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        OpsAsyncView<List<OrgEvent>>(
          value: events,
          what: 'your events',
          isEmpty: (d) => d.isEmpty,
          emptyText: 'No events yet. Create one in Events, then its sales appear here.',
          emptyKey: const Key('sales-no-events'),
          errorKey: const Key('sales-events-error'),
          onRetry: () => ref.invalidate(organizerEventsProvider(widget.workspace.orgId)),
          builder: (list) {
            final selected = list.any((e) => e.eventId == _eventId) ? _eventId! : list.first.eventId;
            final sales = ref.watch(eventSalesProvider(selected));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('sales-event'),
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Event'),
                  items: [for (final e in list) DropdownMenuItem(value: e.eventId, child: Text(e.title))],
                  onChanged: (v) => setState(() => _eventId = v),
                ),
                const SizedBox(height: 12),
                OpsAsyncView<EventSales>(
                  value: sales,
                  what: 'the sales',
                  errorKey: const Key('sales-error'),
                  onRetry: () => ref.invalidate(eventSalesProvider(selected)),
                  builder: (s) {
                    final doc = buildSalesDocument(s);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.statusLine, key: const Key('sales-status'), style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('sales-share'),
                          onPressed: _sharing ? null : () => _share(s),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: Text(_sharing ? 'Making the PDF…' : 'Share as PDF'),
                        ),
                        const SizedBox(height: 12),
                        DocumentCards(sections: doc.sections, keyPrefix: 'sales-section'),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
