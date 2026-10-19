import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/agreement_rules.dart';
import '../services/agreement_service.dart';

final agreementServiceProvider = Provider<AgreementService>((ref) => AgreementService());

/// The agreements of a club (venue side) or of an organizer's business. Exactly one of the two is given.
final agreementListProvider = FutureProvider.autoDispose.family<List<AgreementRow>, ({String venueId, String orgId})>((ref, q) {
  final service = ref.watch(agreementServiceProvider);
  return q.venueId.isNotEmpty ? service.listForVenue(q.venueId) : service.listForOrg(q.orgId);
});

final agreementDetailProvider = FutureProvider.autoDispose.family<AgreementDetail, String>((ref, id) => ref.watch(agreementServiceProvider).detail(id));
