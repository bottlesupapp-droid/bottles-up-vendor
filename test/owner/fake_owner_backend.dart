import 'dart:async';

import 'package:bottles_up_vendor/features/owner/services/owner_service.dart';

/// A stand-in for the database: records every call and answers from handlers set by the test.
class FakeOwnerBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>? params)> handlers = {};
  FutureOr<List<Map<String, dynamic>>> Function(List<String> ids)? onVenueRows;
  final List<List<String>> venueRowCalls = [];

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final h = handlers[function];
    if (h == null) throw StateError('no handler for $function');
    return h(params);
  }

  Future<List<Map<String, dynamic>>> venueRows(List<String> ids) async {
    venueRowCalls.add(ids);
    final h = onVenueRows;
    return h == null ? <Map<String, dynamic>>[] : await h(ids);
  }

  OwnerService get service => OwnerService(rpc: call, venueRows: venueRows);

  int count(String fn) => calls.where((c) => c.$1 == fn).length;
  List<Map<String, dynamic>?> paramsOf(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> myVenue(String id, String name, {String org = 'o1', String status = 'draft'}) =>
    {'venue_id': id, 'venue_name': name, 'org_id': org, 'status': status};

Map<String, dynamic> stepRow(String step, String status, {bool required = true, String? detail}) =>
    {'step': step, 'status': status, 'required': required, 'detail': detail};

/// A venue that is nearly set up: three of the five required steps done.
List<Map<String, dynamic>> partialSetup() => [
      stepRow('profile', 'done'),
      stepRow('floor_plan', 'done'),
      stepRow('tables', 'todo', detail: 'add a table type with capacity, deposit and minimum spend'),
      stepRow('bottles', 'done'),
      stepRow('booking_rules', 'todo', detail: 'choose the days and arrival times you accept bookings'),
      stepRow('team', 'todo', required: false, detail: 'invite a manager or staff'),
      stepRow('payments', 'unavailable', required: false, detail: 'payment configuration is not available yet'),
      stepRow('notifications', 'unavailable', required: false),
    ];
