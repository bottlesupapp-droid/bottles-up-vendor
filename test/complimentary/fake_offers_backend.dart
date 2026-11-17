import 'dart:async';

import 'package:bottles_up_vendor/features/complimentary/services/complimentary_service.dart';
import 'package:bottles_up_vendor/features/inventory/services/inventory_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// A stand-in for the database's offer functions: records every call and answers from rows the test sets. It decides nothing: which steps are open is whatever `actions` says in each row.
class FakeOffersBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>? params)> handlers = {};
  List<Map<String, dynamic>> offers = [];
  List<Map<String, dynamic>> tables = [tableRow('t1', 'Booth 1', floor: 'Main floor'), tableRow('t2', 'Booth 2')];
  List<Map<String, dynamic>> bookings = [bookingRow('b1', 'Ada Evening', 'ADA-EVENING')];
  bool offline = false;
  bool missing = false;

  /// The attempts to e-mail an offer's link, as comp_offer_sends answers them.
  List<Map<String, dynamic>> sends = [];

  /// Every call of an edge function, and what it answers (or throws). The default is a send that went.
  final List<(String, Map<String, dynamic>)> invokes = [];
  FutureOr<dynamic> Function(String name, Map<String, dynamic> body)? invokeHandler;

  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    invokes.add((name, body));
    if (offline) throw Exception('SocketException: connection lost');
    final handler = invokeHandler;
    if (handler != null) return handler(name, body);
    return {'sent': true};
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function public.$function does not exist', code: '42883');
    final handler = handlers[function];
    if (handler != null) return handler(params);
    return switch (function) {
      'comp_offers_list' => offers,
      'comp_offer_tables' => tables,
      'comp_offer_bookings' => bookings,
      'comp_offer_create' => 'o-new',
      'comp_offer_set_location' => 'location_submitted',
      'comp_offer_accept' => {'offer_id': 'o1', 'status': 'accepted', 'concession_id': 'c1', 'concession_status': 'applied'},
      'comp_offer_mark_delivered' => 'delivered',
      'comp_offer_cancel' => 'cancelled',
      'comp_offer_sends' => sends,
      'stock_list' => stock,
      _ => throw StateError('unexpected call $function'),
    };
  }

  List<Map<String, dynamic>> stock = [stockRow('p1', 'Patron', '750ml'), stockRow('v1', 'Vodka', null)];

  ComplimentaryService get service => ComplimentaryService(rpc: OpsRpc(rpc: call, invoker: invoke));
  InventoryService get inventory => InventoryService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>?> paramsOf(String function) => [
    for (final c in calls)
      if (c.$1 == function) c.$2,
  ];

  int count(String function) => calls.where((c) => c.$1 == function).length;
}

Map<String, dynamic> stockRow(String id, String name, String? size) => {
  'bottle_id': id,
  'name': name,
  'size': size,
  'tracked': false,
  'quantity': null,
  'low_threshold': null,
  'is_low': false,
  'is_sold_out': false,
};

Map<String, dynamic> tableRow(String id, String name, {String? floor}) => {'table_id': id, 'name': name, 'floor_label': floor};

Map<String, dynamic> bookingRow(String id, String guest, String code, {String table = 'Booth 1', int guests = 2}) => {
  'booking_id': id,
  'confirmation_code': code,
  'guest_name': guest,
  'table_name': table,
  'guest_count': guests,
};

/// One row of comp_offers_list. [actions] names the open steps.
Map<String, dynamic> offerRow({
  String id = 'o1',
  String status = 'approved',
  String bottle = 'Patron',
  String? size = '750ml',
  int quantity = 2,
  String email = 'gina@x.example',
  String? name = 'Gina',
  String reason = 'Birthday table',
  String? sign = 'Happy Birthday',
  List<String>? actions,
  String? location,
  String? setBy,
  String? concession,
  String? booking,
}) => {
  'offer_id': id,
  'bottle_name': bottle,
  'bottle_size': size,
  'quantity': quantity,
  'value_cents': 25000 * quantity,
  'recipient_email': email,
  'recipient_name': name,
  'reason': reason,
  'sign_text': sign,
  'status': status,
  'expires_at': '2026-11-18T21:00:00Z',
  'created_at': '2026-11-17T09:00:00Z',
  'created_by_name': 'Mia Manager',
  'location_table_name': location,
  'location_set_by': setBy,
  'booking_id': booking,
  'concession_status': concession,
  'delivered_at': status == 'delivered' ? '2026-11-17T22:00:00Z' : null,
  'actions':
      actions ??
      switch (status) {
        'approved' || 'sent' || 'awaiting_location' => ['set_location', 'cancel'],
        'location_submitted' => ['accept', 'set_location', 'cancel'],
        'accepted' => ['mark_delivered'],
        _ => <String>[],
      },
};

/// One row of comp_offer_sends.
Map<String, dynamic> sendRow({String id = 's1', String to = 'gina@x.example', String status = 'sent', String? failure, String at = '2026-11-17T21:04:00Z', bool first = true, bool mine = true}) => {
  'id': id,
  'to_email': to,
  'status': status,
  'failure': failure,
  'created_at': at,
  'finished_at': status == 'pending' ? null : at,
  'first_send': first,
  'mine': mine,
};
