import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/providers/table_service_providers.dart' show NightQuery;
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
