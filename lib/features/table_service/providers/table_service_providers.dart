import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/table_service_rules.dart';
import '../services/receipt_service.dart';
import '../services/table_service_service.dart';

final tableServiceServiceProvider = Provider<TableServiceService>(
  (ref) => TableServiceService(),
);
final receiptServiceProvider = Provider<ReceiptService>(
  (ref) => ReceiptService(),
);

/// What one read of a club's night is about. Equal queries share an answer.
class NightQuery {
  const NightQuery(this.venueId, this.night);

  final String venueId;
  final String night;

  @override
  bool operator ==(Object other) =>
      other is NightQuery && other.venueId == venueId && other.night == night;

  @override
  int get hashCode => Object.hash(venueId, night);
}

/// A club's order lines for one night. Not kept once the screen is gone: a stale list at a table is worse than a slow one.
final ordersProvider = FutureProvider.autoDispose
    .family<List<OrderLine>, NightQuery>(
      (ref, q) =>
          ref.watch(tableServiceServiceProvider).orders(q.venueId, q.night),
    );

/// Where each confirmed booking of the night stands (what is due, what is left to deliver).
final tableStatusesProvider = FutureProvider.autoDispose
    .family<List<TableStatus>, NightQuery>(
      (ref, q) => ref
          .watch(tableServiceServiceProvider)
          .tableStatuses(q.venueId, q.night),
    );

final tonightProvider = FutureProvider.autoDispose
    .family<TonightCounts, NightQuery>(
      (ref, q) =>
          ref.watch(tableServiceServiceProvider).tonight(q.venueId, q.night),
    );

/// The payments waiting for a person at a club.
final pendingPaymentsProvider = FutureProvider.autoDispose
    .family<List<PendingPayment>, String>(
      (ref, venueId) =>
          ref.watch(tableServiceServiceProvider).pendingPayments(venueId),
    );

/// One table's money.
final bookingMoneyProvider = FutureProvider.autoDispose.family<
  BookingMoney,
  String
>((ref, bookingId) => ref.watch(tableServiceServiceProvider).money(bookingId));

/// One table's order lines, read with the table's balance.
class TableOrdersQuery {
  const TableOrdersQuery(this.bookingId, this.balanceDueCents);

  final String bookingId;
  final int? balanceDueCents;

  @override
  bool operator ==(Object other) =>
      other is TableOrdersQuery &&
      other.bookingId == bookingId &&
      other.balanceDueCents == balanceDueCents;

  @override
  int get hashCode => Object.hash(bookingId, balanceDueCents);
}

final tableOrdersProvider = FutureProvider.autoDispose
    .family<List<OrderLine>, TableOrdersQuery>(
      (ref, q) => ref
          .watch(tableServiceServiceProvider)
          .tableOrders(q.bookingId, balanceDueCents: q.balanceDueCents),
    );
