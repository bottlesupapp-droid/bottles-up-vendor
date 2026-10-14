import 'dart:async';

import 'package:bottles_up_vendor/features/door/services/door_service.dart';

/// A stand-in for the database: records every call and answers from handlers set by the test.
class FakeDoorBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>? params)> handlers = {};

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final handler = handlers[function];
    if (handler == null) throw StateError('no handler for $function');
    return handler(params);
  }

  DoorService get service => DoorService(rpc: call);

  List<Map<String, dynamic>?> paramsOf(String function) => [
        for (final c in calls)
          if (c.$1 == function) c.$2,
      ];

  int count(String function) => calls.where((c) => c.$1 == function).length;
}

String hoursFromNow(int h) => DateTime.now().add(Duration(hours: h)).toUtc().toIso8601String();

Map<String, dynamic> eventRow({
  String id = 'e1',
  String title = 'Friday Night',
  int expected = 10,
  int admitted = 3,
  int startsInHours = -1,
}) =>
    {
      'event_id': id,
      'title': title,
      'venue_name': 'Club A',
      'start_date': hoursFromNow(startsInHours),
      'end_date': hoursFromNow(startsInHours + 8),
      'scope': 'venue',
      'guests_expected': expected,
      'guests_admitted': admitted,
    };

Map<String, dynamic> scanRow(String result, {String? name, String? tier, int? quantity, int? attemptsRemaining}) => {
      'result': result,
      'customer_name': name,
      'event_title': name == null ? null : 'Friday Night',
      'tier_name': tier,
      'quantity': quantity,
      if (attemptsRemaining != null) 'attempts_remaining': attemptsRemaining,
    };

Map<String, dynamic> guestRow(String name, String code, {bool needsCode = false, String? checkedInAt, int quantity = 2}) => {
      'order_id': 'o-$code',
      'customer_name': name,
      'ticket_code': code,
      'tier_name': 'General',
      'quantity': quantity,
      'checked_in_at': checkedInAt,
      'needs_code': needsCode,
    };
