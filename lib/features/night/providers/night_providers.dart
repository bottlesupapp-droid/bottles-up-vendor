import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../logic/consolidated_report.dart';
import '../logic/night_rules.dart';
import '../services/night_service.dart';

final nightServiceProvider = Provider<NightService>((ref) => NightService());

/// Replaced in tests with one that records what was shared.
final shareReportProvider = Provider<ShareReport>((ref) => shareReportFile);

final nightChecklistProvider = FutureProvider.autoDispose.family<List<ChecklistItem>, NightQuery>(
  (ref, q) => ref.watch(nightServiceProvider).checklist(q.venueId, q.night),
);

final closeStatusProvider = FutureProvider.autoDispose.family<CloseStatus, NightQuery>(
  (ref, q) => ref.watch(nightServiceProvider).status(q.venueId, q.night),
);

final nightReportProvider = FutureProvider.autoDispose.family<NightReport, NightQuery>(
  (ref, q) => ref.watch(nightServiceProvider).report(q.venueId, q.night),
);

/// One business and one night, for the owner's combined report.
class ConsolidatedQuery {
  const ConsolidatedQuery(this.orgId, this.night);

  final String orgId;
  final String night;

  @override
  bool operator ==(Object other) => other is ConsolidatedQuery && other.orgId == orgId && other.night == night;

  @override
  int get hashCode => Object.hash(orgId, night);
}

final consolidatedReportProvider = FutureProvider.autoDispose.family<ConsolidatedReport, ConsolidatedQuery>(
  (ref, q) => ref.watch(nightServiceProvider).consolidated(q.orgId, q.night),
);
