import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/widgets/ops_async_view.dart';
import '../../table_service/widgets/night_bar.dart';
import '../logic/consolidated_report.dart';
import '../logic/report_pdf.dart';
import '../providers/night_providers.dart';

/// The owner's report for one night across every club of the business: each club's own report side by side, and the totals when they
/// can honestly be added. It says how many clubs have closed the night, and can be shared as a PDF with the same words.
class ConsolidatedReportScreen extends ConsumerStatefulWidget {
  const ConsolidatedReportScreen({super.key, required this.orgId, required this.orgName, this.initialNight, this.clock = DateTime.now});

  final String orgId;
  final String orgName;
  final String? initialNight;
  final DateTime Function() clock;

  @override
  ConsumerState<ConsolidatedReportScreen> createState() => _ConsolidatedReportScreenState();
}

class _ConsolidatedReportScreenState extends ConsumerState<ConsolidatedReportScreen> {
  late String _night = widget.initialNight ?? currentNight(widget.clock());
  bool _sharing = false;

  String get _tonight => currentNight(widget.clock());
  ConsolidatedQuery get _query => ConsolidatedQuery(widget.orgId, _night);

  Future<void> _share(ConsolidatedReport report) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = buildConsolidatedDocument(report);
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
    final report = ref.watch(consolidatedReportProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(consolidatedReportProvider(_query)),
      child: ListView(
        key: const Key('consolidated-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: 8),
          OpsAsyncView<ConsolidatedReport>(
            value: report,
            what: 'the combined report',
            errorKey: const Key('consolidated-error'),
            onRetry: () => ref.invalidate(consolidatedReportProvider(_query)),
            builder: (r) {
              final doc = buildConsolidatedDocument(r);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, key: const Key('consolidated-title'), style: theme.textTheme.headlineSmall),
                  Text(doc.subtitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Chip(
                    key: const Key('consolidated-status'),
                    avatar: Icon(r.allFinal ? Icons.lock_outline : Icons.hourglass_empty, size: 16),
                    label: Text(doc.statusLine, style: theme.textTheme.labelMedium),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('consolidated-share'),
                    onPressed: _sharing ? null : () => _share(r),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(_sharing ? 'Making the PDF…' : 'Share as PDF'),
                  ),
                  const SizedBox(height: 12),
                  if (r.venues.isEmpty)
                    const Padding(
                      key: Key('consolidated-empty'),
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No venues in this business yet. Add one in Venues, then its figures appear here.'),
                    ),
                  for (final (i, s) in doc.sections.indexed)
                    Card(
                      key: Key('consolidated-section-$i'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            for (final row in s.rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(row.label, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(row.value, textAlign: TextAlign.end, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
