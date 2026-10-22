import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/door_sales_rules.dart';
import '../services/door_sales_service.dart';

final doorSalesServiceProvider = Provider<DoorSalesService>((ref) => DoorSalesService());

/// What can be sold for an event now. Never kept: the tickets left change with every sale, here and at the other doors.
final saleOptionsProvider = FutureProvider.autoDispose.family<SaleOptions, String>((ref, eventId) => ref.watch(doorSalesServiceProvider).options(eventId));

/// This person's shift at an event. Never kept: it must show the sale made a moment ago.
final shiftSummaryProvider = FutureProvider.autoDispose.family<ShiftSummary, String>((ref, eventId) => ref.watch(doorSalesServiceProvider).summary(eventId));

/// The key of the sale being made, created when the person first presses the button and kept until it succeeds (see [saleFingerprint]).
typedef SaleKeyMaker = String Function();

final saleKeyMakerProvider = Provider<SaleKeyMaker>((ref) => newSaleKey);
