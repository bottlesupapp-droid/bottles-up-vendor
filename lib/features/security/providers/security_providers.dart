import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../logic/security_rules.dart';
import '../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) => SecurityService());

/// How often the alerts look for news while they are on screen. There is no push yet; tests make it long.
final securityPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 10));

final alertsProvider = FutureProvider.autoDispose.family<List<SecurityAlert>, NightQuery>(
  (ref, q) => ref.watch(securityServiceProvider).alerts(q.venueId, q.night),
);

final securityTasksProvider = FutureProvider.autoDispose.family<List<SecurityTask>, NightQuery>(
  (ref, q) => ref.watch(securityServiceProvider).tasks(q.venueId, q.night),
);

final incidentsProvider = FutureProvider.autoDispose.family<List<IncidentRow>, String>(
  (ref, venueId) => ref.watch(securityServiceProvider).incidents(venueId),
);

final incidentDetailProvider = FutureProvider.autoDispose.family<IncidentDetail, String>(
  (ref, id) => ref.watch(securityServiceProvider).incident(id),
);

final securitySummaryProvider = FutureProvider.autoDispose.family<SecuritySummary, NightQuery>(
  (ref, q) => ref.watch(securityServiceProvider).summary(q.venueId, q.night),
);
