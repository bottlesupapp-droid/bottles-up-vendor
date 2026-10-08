import 'dart:async';

import 'package:bottles_up_vendor/features/floor/services/floor_service.dart';

/// A stand-in for the database: records every call and answers from a handler set by the test.
class FakeFloorBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  FutureOr<dynamic> Function(Map<String, dynamic>? params)? onList;

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    if (function != 'list_venue_bookings' || onList == null) throw StateError('unexpected call to $function');
    return onList!(params);
  }

  FloorService get service => FloorService(rpc: call);

  List<Map<String, dynamic>?> get params => [for (final c in calls) c.$2];
}

Map<String, dynamic> bookingRow(
  String id, {
  String night = '2026-10-09',
  String time = '21:00:00',
  String? label,
  String table = 'VIP booth',
  int guests = 4,
  String name = 'Ada Lovelace',
  String email = 'ada@example.com',
  String? phone,
  String status = 'paid',
  String? code,
  String? checkedInAt,
  int total = 40000,
  int deposit = 0,
}) =>
    {
      'booking_id': id,
      'night_date': night,
      'start_time': time,
      'slot_label': label,
      'table_name': table,
      'guest_count': guests,
      'customer_name': name,
      'customer_email': email,
      'customer_phone': phone,
      'status': status,
      'fulfillment_status': 'confirmed',
      'amount_total_cents': total,
      'deposit_cents': deposit,
      'currency': 'cad',
      'confirmation_code': code,
      'checked_in_at': checkedInAt,
      'created_at': '2026-10-01T10:00:00Z',
    };
