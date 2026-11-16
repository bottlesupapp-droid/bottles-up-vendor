import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/settlement_rules.dart';
import '../services/settlement_service.dart';

final settlementServiceProvider = Provider<SettlementService>((ref) => SettlementService());

/// A club's agreements that have a share of bar sales to settle, with their settlements. Read again every time the screen opens; never kept once it is gone.
final venueSettlementsProvider = FutureProvider.autoDispose.family<List<SettlementRow>, String>((ref, venueId) => ref.watch(settlementServiceProvider).forVenue(venueId));

/// The same for an organizer's business.
final orgSettlementsProvider = FutureProvider.autoDispose.family<List<SettlementRow>, String>((ref, orgId) => ref.watch(settlementServiceProvider).forOrganizer(orgId));

/// One settlement with its calculation, history and what the person may do about it.
final settlementDetailProvider = FutureProvider.autoDispose.family<SettlementDetail, String>((ref, agreementId) => ref.watch(settlementServiceProvider).detail(agreementId));
