import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money_rules.dart';
import '../services/money_service.dart';

final moneyServiceProvider = Provider<MoneyService>((ref) => MoneyService());

final moneyProvider = FutureProvider.autoDispose.family<List<VenueMoney>, ({String orgId, String from, String to})>(
  (ref, q) => ref.watch(moneyServiceProvider).clubs(q.orgId, q.from, q.to),
);
