import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/vip_rules.dart';
import '../services/vip_service.dart';

final vipServiceProvider = Provider<VipService>((ref) => VipService());

/// A club's VIP list for one search.
final vipListProvider = FutureProvider.autoDispose.family<List<VipMember>, ({String venueId, String search, bool includeEnded})>(
  (ref, q) => ref.watch(vipServiceProvider).list(q.venueId, search: q.search, includeEnded: q.includeEnded),
);

final vipProfileProvider = FutureProvider.autoDispose.family<VipProfile, String>(
  (ref, id) => ref.watch(vipServiceProvider).detail(id),
);
