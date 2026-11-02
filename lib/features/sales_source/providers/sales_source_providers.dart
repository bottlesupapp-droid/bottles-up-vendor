import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/sales_source_rules.dart';
import '../services/sales_source_service.dart';

final salesSourceServiceProvider = Provider<SalesSourceService>((ref) => SalesSourceService());

/// Where one club's sales come from.
final salesSourceProvider = FutureProvider.autoDispose.family<SalesSource, String>((ref, venueId) => ref.watch(salesSourceServiceProvider).source(venueId));

/// One club's closing reports, newest night first.
final closingReportsProvider = FutureProvider.autoDispose.family<List<ClosingReport>, String>((ref, venueId) => ref.watch(salesSourceServiceProvider).reports(venueId));

/// One night's sales for one club: ([venueId], [night]).
final nightSalesProvider = FutureProvider.autoDispose.family<NightSales, ({String venueId, String night})>((ref, q) => ref.watch(salesSourceServiceProvider).nightSales(q.venueId, q.night));
