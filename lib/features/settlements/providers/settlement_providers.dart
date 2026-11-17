import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/settlement_adjustment_rules.dart';
import '../logic/settlement_rules.dart';
import '../services/settlement_service.dart';

final settlementServiceProvider = Provider<SettlementService>((ref) => SettlementService());

/// A club's agreements that have a share of bar sales to settle, with their settlements. Read again every time the screen opens; never kept once it is gone.
final venueSettlementsProvider = FutureProvider.autoDispose.family<List<SettlementRow>, String>((ref, venueId) => ref.watch(settlementServiceProvider).forVenue(venueId));

/// The same for an organizer's business.
final orgSettlementsProvider = FutureProvider.autoDispose.family<List<SettlementRow>, String>((ref, orgId) => ref.watch(settlementServiceProvider).forOrganizer(orgId));

/// One settlement with its calculation, history and what the person may do about it.
final settlementDetailProvider = FutureProvider.autoDispose.family<SettlementDetail, String>((ref, agreementId) => ref.watch(settlementServiceProvider).detail(agreementId));

/// The adjustments after payment of one paid settlement: the totals, each adjustment with what the person may do about it, and the history. Read again every time it is shown.
final settlementAdjustmentsProvider = FutureProvider.autoDispose.family<SettlementAdjustments, String>((ref, agreementId) => ref.watch(settlementServiceProvider).adjustments(agreementId));

/// Which of a club's settlements have adjustments after payment (for a line under the row). Never fails: no answer is no badge.
final venueAdjustmentFlagsProvider = FutureProvider.autoDispose.family<Map<String, AdjustmentFlag>, String>((ref, venueId) => ref.watch(settlementServiceProvider).adjustmentFlagsForVenue(venueId));

/// The same for an organizer's business.
final orgAdjustmentFlagsProvider = FutureProvider.autoDispose.family<Map<String, AdjustmentFlag>, String>((ref, orgId) => ref.watch(settlementServiceProvider).adjustmentFlagsForOrganizer(orgId));
