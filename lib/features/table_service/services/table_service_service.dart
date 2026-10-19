import 'package:supabase_flutter/supabase_flutter.dart';

import '../../floor/logic/bookings_rules.dart' show parseNight;
import '../../owner/services/db_errors.dart';
import '../../team/services/team_service.dart' show sentence;
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/bottle_orders_rules.dart';
import '../logic/table_service_rules.dart';

/// Loading something for table service failed. Carries what the screen needs to say, not a stack trace.
class TableServiceLoadException implements Exception {
  const TableServiceLoadException({
    required this.unavailable,
    required this.accessEnded,
    required this.what,
  });

  /// The backend has not been given the migration yet. Nothing the person can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  /// What was being loaded, in the plural: "orders", "payments".
  final String what;

  String get message => tableServiceLoadMessage(
    unavailable: unavailable,
    accessEnded: accessEnded,
    what: what,
  );

  @override
  String toString() => 'TableServiceLoadException($message)';
}

/// The failure a screen shows for [error] while loading [what]. The service always throws a [TableServiceLoadException]; anything else
/// (which should not happen) is a plain "could not be loaded", never a blank screen.
TableServiceLoadException loadFailureFor(Object error, String what) =>
    error is TableServiceLoadException
        ? error
        : TableServiceLoadException(
          unavailable: false,
          accessEnded: false,
          what: what,
        );

/// A call to an edge function: its name and JSON body, answering with the decoded body.
typedef FunctionInvoker = Future<dynamic> Function(String name, Map<String, dynamic> body);

/// Moving an order, recording a payment or verifying one was refused or failed; the message is a plain sentence.
class TableServiceActionException implements Exception {
  const TableServiceActionException(this.message, {this.outcomeUnknown = false});

  final String message;

  /// The call may have gone through (no answer, or the server failed part way): look at the table before doing it again.
  final bool outcomeUnknown;

  @override
  String toString() => 'TableServiceActionException($message)';
}

/// The table-service calls to the website's database functions: `desk_orders`, `desk_booking_orders`, `desk_set_service_status`,
/// `desk_booking_money`, `desk_record_payment`, `desk_pending_verifications`, `desk_verify_payment`, `desk_table_status` and
/// `desk_tonight` (website repo, 20261014120000_desk_orders.sql and 20261014130000_desk_payments.sql). The database checks who may do
/// what: a server reaches only their own tables, only a manager or owner sees the whole club, a verifier checks payments but records
/// nothing, and nobody verifies their own entry. Nothing here decides that.
class TableServiceService {
  TableServiceService({SupabaseClient? client, RpcCaller? rpc, FunctionInvoker? invoker})
    : _client = client,
      _rpcOverride = rpc,
      _invokerOverride = invoker;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  final FunctionInvoker? _invokerOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  /// A call to one of the website's edge functions (the add-bottles function). Throws [FunctionException] when it answers with an error status.
  Future<dynamic> _invoke(String name, Map<String, dynamic> body) async {
    final override = _invokerOverride;
    if (override != null) return override(name, body);
    final response = await _db.functions.invoke(name, body: body);
    return response.data;
  }

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List
          ? [
            for (final r in data)
              if (r is Map) Map<String, dynamic>.from(r),
          ]
          : const [];

  TableServiceLoadException _loadFailure(Object error, String what) =>
      TableServiceLoadException(
        unavailable: isMissingFunction(error),
        accessEnded: isNoAccess(error),
        what: what,
      );

  Future<List<T>> _list<T>(
    String function,
    Map<String, dynamic> params,
    T? Function(Map<String, dynamic>) parse,
    String what,
  ) async {
    try {
      return _rows(
        await _rpc(function, params: params),
      ).map(parse).whereType<T>().toList();
    } catch (error) {
      throw _loadFailure(error, what);
    }
  }

  Future<T> _act<T>(
    Future<T> Function() call, {
    String generic =
        'This could not be done. Check your connection and try again.',
  }) async {
    try {
      return await call();
    } on TableServiceActionException {
      rethrow;
    } catch (error) {
      throw TableServiceActionException(
        sentence(actionMessage(error, generic: generic)),
      );
    }
  }

  void _checkNight(String night) {
    if (parseNight(night) == null) throw ArgumentError('not a night: $night');
  }

  /// The bottle lines of one business night at a club. A manager or owner gets the whole club, a server only their own tables.
  Future<List<OrderLine>> orders(String venueId, String night) {
    _checkNight(night);
    return _list(
      'desk_orders',
      {'p_venue': venueId, 'p_night': night},
      parseOrderLine,
      'orders',
    );
  }

  /// Every line of one table, cancelled ones included. [balanceDueCents] is the table's balance, which decides whether an item to be
  /// paid at the venue can be handed over.
  Future<List<OrderLine>> tableOrders(
    String bookingId, {
    int? balanceDueCents,
  }) async {
    final lines = await _list(
      'desk_booking_orders',
      {'p_booking': bookingId},
      (r) => parseTableLine(
        r,
        bookingId: bookingId,
        balanceDueCents: balanceDueCents,
      ),
      'orders',
    );
    if (lines.isEmpty) return lines;
    // How many of each line were handed over (partial delivery). Without this count (a server that does not have the migration yet, or a failed read) the
    // lines are shown as they were and nothing about partial delivery is offered.
    try {
      final counts = <String, int>{
        for (final r in _rows(await _rpc('desk_booking_deliveries', params: {'p_booking': bookingId})))
          if (r['line_id'] is String) r['line_id'] as String: r['delivered_quantity'] is int ? r['delivered_quantity'] as int : 0,
      };
      return [for (final l in lines) counts.containsKey(l.lineId) ? l.withDelivered(counts[l.lineId]!) : l];
    } catch (_) {
      return lines;
    }
  }

  /// Hands over [quantity] more of a line. The database is told how many were delivered when the person looked: if that moved (a repeated tap, a colleague, a lost
  /// answer sent again) it refuses and nothing is counted twice.
  Future<DeliveryResult> deliverPart(OrderLine line, int quantity) => _act(
    () async {
      final result = parseDeliveryResult(await _rpc('desk_deliver_part', params: deliverPartParams(line.lineId, quantity, line.deliveredQuantity)));
      if (result == null) {
        throw const TableServiceActionException('The delivery could not be confirmed. Look at the table\'s orders before trying again.');
      }
      return result;
    },
    generic: 'The delivery could not be recorded. Check your connection and try again.',
  );

  /// The bottles the club offers for this table right now, with the number left where the club counts. Refused (with the database's own sentence) for someone who
  /// may not add bottles here, and for a table or night that is closed.
  Future<List<MenuBottle>> bottleMenu(String bookingId) async {
    try {
      return _rows(await _rpc('desk_bottle_menu', params: {'p_booking': bookingId})).map(parseMenuBottle).whereType<MenuBottle>().toList();
    } catch (error) {
      if (error is PostgrestException && error.code == 'P0001' && !isNoAccess(error) && error.message.trim().isNotEmpty) {
        throw TableServiceActionException(sentence(error.message));
      }
      throw _loadFailure(error, 'bottles');
    }
  }

  /// Adds the basket to the table. The website prices it, checks stock, works out the table's new total and e-mails the guest; staff-added bottles are always due at
  /// the club. A call that never got an answer may have gone through, so its failure says to look at the table's orders before trying again.
  Future<void> addBottles(String bookingId, List<MenuBottle> menu, Basket basket) async {
    final problem = basketProblem(menu, basket);
    if (problem != null) throw TableServiceActionException(problem);
    try {
      await _invoke('add-table-booking-bottles', addBottlesBody(bookingId, menu, basket));
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] is String ? details['error'] as String : (details is String ? details : null);
      throw TableServiceActionException(addBottlesFailure(status: e.status, message: message), outcomeUnknown: addBottlesOutcomeUnknown(e.status));
    } catch (_) {
      throw TableServiceActionException(addBottlesFailure(), outcomeUnknown: addBottlesOutcomeUnknown(null));
    }
  }

  /// Moves one order line. Answers true when it changed and false when it already was so (a repeated tap, or a colleague got there
  /// first): nothing is written twice.
  Future<bool> moveOrder(String lineId, ServiceState to) => _act(
    () async {
      final answer = await _rpc(
        'desk_set_service_status',
        params: moveParams(lineId, to),
      );
      return answer == true;
    },
    generic:
        'The order could not be moved. Check your connection and try again.',
  );

  /// What a table was charged, what was collected, and every payment recorded for it.
  Future<BookingMoney> money(String bookingId) async {
    try {
      final money = parseBookingMoney(
        await _rpc('desk_booking_money', params: {'p_booking': bookingId}),
      );
      if (money == null) {
        throw const TableServiceLoadException(
          unavailable: false,
          accessEnded: false,
          what: 'payments',
        );
      }
      return money;
    } on TableServiceLoadException {
      rethrow;
    } catch (error) {
      throw _loadFailure(error, 'payments');
    }
  }

  /// Records a payment taken at the club. The form is checked first, so a request the database would refuse never leaves the phone.
  /// A repeated tap (or a lost answer sent again with the same receipt) comes back as a duplicate, not a second payment.
  Future<RecordedPayment> recordPayment(
    String bookingId,
    PaymentInput form, {
    required bool manager,
    String? receiptPath,
    String? receiptHash,
    String? deviceId,
  }) {
    final problems = paymentProblems(form, manager: manager);
    if (problems.isNotEmpty) {
      return Future.error(TableServiceActionException(problems.values.first));
    }
    return _act(
      () async {
        final answer = await _rpc(
          'desk_record_payment',
          params: recordPaymentParams(
            bookingId,
            form,
            receiptPath: receiptPath,
            receiptHash: receiptHash,
            deviceId: deviceId,
          ),
        );
        final recorded = parseRecordedPayment(answer);
        if (recorded == null) {
          throw const TableServiceActionException(
            'The payment could not be recorded.',
          );
        }
        return recorded;
      },
      generic:
          'The payment could not be recorded. Check your connection and try again.',
    );
  }

  /// Payments at a club that need a person: unchecked ones and disputed ones.
  Future<List<PendingPayment>> pendingPayments(String venueId) => _list(
    'desk_pending_verifications',
    {'p_venue': venueId},
    parsePendingPayment,
    'payments',
  );

  /// Marks a payment as checked. Never your own entry, never twice (the database says so in its own words).
  Future<void> verify(String paymentId, {String? note}) {
    final problem = note == null ? null : validateVerifyNote(note);
    if (problem != null) {
      return Future.error(TableServiceActionException(problem));
    }
    return _act(
      () async => await _rpc(
        'desk_verify_payment',
        params: verifyParams(paymentId, note),
      ),
      generic:
          'The payment could not be verified. Check your connection and try again.',
    );
  }

  /// One line per confirmed booking of the night: what is due, what is left to deliver, what is unchecked.
  Future<List<TableStatus>> tableStatuses(String venueId, String night) {
    _checkNight(night);
    return _list(
      'desk_table_status',
      {'p_venue': venueId, 'p_night': night},
      parseTableStatus,
      'tables',
    );
  }

  /// The manager's "Needs attention" numbers for one night.
  Future<TonightCounts> tonight(String venueId, String night) async {
    _checkNight(night);
    final rows = await _list(
      'desk_tonight',
      {'p_venue': venueId, 'p_night': night},
      parseTonight,
      'Tonight',
    );
    if (rows.isEmpty) {
      throw const TableServiceLoadException(
        unavailable: false,
        accessEnded: false,
        what: 'Tonight',
      );
    }
    return rows.first;
  }
}
