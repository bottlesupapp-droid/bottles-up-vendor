import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../logic/cash_rules.dart';
import '../services/cash_service.dart';

final cashServiceProvider = Provider<CashService>((ref) => CashService());

/// Who holds how much cash at a club for a night. Not kept once the screen is gone: stale money is worse than slow money.
final cashPositionProvider = FutureProvider.autoDispose.family<List<CashLine>, NightQuery>(
  (ref, q) => ref.watch(cashServiceProvider).position(q.venueId, q.night),
);

final handoversProvider = FutureProvider.autoDispose.family<List<Handover>, NightQuery>(
  (ref, q) => ref.watch(cashServiceProvider).handovers(q.venueId, q.night),
);

final verifierSummaryProvider = FutureProvider.autoDispose.family<VerifierSummary, NightQuery>(
  (ref, q) => ref.watch(cashServiceProvider).summary(q.venueId, q.night),
);

/// A club's flagged payments, open or resolved.
final flagsProvider = FutureProvider.autoDispose.family<List<PaymentFlag>, ({String venueId, bool resolved})>(
  (ref, q) => ref.watch(cashServiceProvider).flags(q.venueId, resolved: q.resolved),
);
