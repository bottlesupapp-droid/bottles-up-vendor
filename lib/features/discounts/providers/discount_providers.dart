import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table_service/logic/bottle_orders_rules.dart' show MenuBottle;
import '../logic/discount_rules.dart';
import '../services/discount_service.dart';

final discountServiceProvider = Provider<DiscountService>((ref) => DiscountService());

/// What the caller may give on one table tonight. Never kept: the allowance used so far changes with every free bottle.
final concessionLimitsProvider = FutureProvider.autoDispose.family<ConcessionLimits, String>((ref, bookingId) => ref.watch(discountServiceProvider).limits(bookingId));

/// What has been given on one table.
final bookingConcessionsProvider = FutureProvider.autoDispose.family<List<Concession>, String>((ref, bookingId) => ref.watch(discountServiceProvider).given(bookingId));

/// The bottles that can be given free on one table.
final freeBottleMenuProvider = FutureProvider.autoDispose.family<List<MenuBottle>, String>((ref, bookingId) => ref.watch(discountServiceProvider).menu(bookingId));

/// The requests waiting at a club.
final pendingConcessionsProvider = FutureProvider.autoDispose.family<List<PendingConcession>, String>((ref, venueId) => ref.watch(discountServiceProvider).pending(venueId));

/// The club's limits.
final discountLimitsProvider = FutureProvider.autoDispose.family<DiscountLimits, String>((ref, venueId) => ref.watch(discountServiceProvider).venueLimits(venueId));
