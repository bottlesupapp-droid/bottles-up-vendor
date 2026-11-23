import 'dart:async';

import 'package:bottles_up_vendor/features/organizer_events/services/organizer_tiers_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuseTier(String message) => PostgrestException(message: message, code: 'P0001');

/// A stand-in for the website's `list_org_tiers`, `save_org_tier` and `remove_org_tier` that behaves the way they do: only the whitelisted fields,
/// only the fields sent change, a type that has sold keeps its price and name, the capacity never goes below what sold, a type with an order is not
/// removed, at most 20 types, no two with the same name, and a refusal is the database's own sentence raised as P0001. (It does not repeat the sale
/// window rules: the form's own checks are tested against those, and the database function has its own tests.)
class FakeOrganizerTiersBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];

  /// Rows as list_org_tiers answers them, plus `event_id` (taken off before answering).
  final List<Map<String, dynamic>> tiers = [];
  Object? failAll;
  void Function(String function)? beforeCall;
  Future<void>? hold;
  int _next = 1;

  static const allowed = {'name', 'price_cents', 'capacity', 'sale_starts_at', 'sale_ends_at'};

  OrganizerTiersService get service => OrganizerTiersService(rpc: call);

  void seed({
    String? id,
    String event = 'ev1',
    String name = 'General',
    int price = 2500,
    int capacity = 100,
    int sold = 0,
    String? starts,
    String? ends,
    bool hasSold = false,
    bool hasOrders = false,
    bool code = false,
  }) {
    tiers.add({
      'tier_id': id ?? 't${_next++}',
      'event_id': event,
      'name': name,
      'price_cents': price,
      'currency': 'cad',
      'capacity': capacity,
      'sold_count': sold,
      'sale_starts_at': starts,
      'sale_ends_at': ends,
      'has_sold': hasSold || sold > 0,
      'has_orders': hasOrders || hasSold || sold > 0,
      'requires_access_code': code,
    });
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'list_org_tiers':
        return [
          for (final t in tiers)
            if (t['event_id'] == p['p_event']) {for (final e in t.entries) if (e.key != 'event_id') e.key: e.value},
        ];
      case 'save_org_tier':
        final details = p['p_details'] as Map<String, dynamic>;
        for (final k in details.keys) {
          if (!allowed.contains(k)) throw refuseTier('unknown field: $k');
        }
        final event = p['p_event'] as String;
        final id = p['p_tier'] as String?;
        final mine = tiers.where((t) => t['event_id'] == event).toList();
        final name = details['name'] as String;
        if (mine.any((t) => t['tier_id'] != id && (t['name'] as String).toLowerCase() == name.toLowerCase())) {
          throw refuseTier('this event already has a ticket type with that name');
        }
        if (id == null) {
          if (mine.length >= 20) throw refuseTier('an event can have at most 20 ticket types');
          final newId = 't${_next++}';
          tiers.add({
            'tier_id': newId,
            'event_id': event,
            'name': name,
            'price_cents': details['price_cents'],
            'currency': 'cad',
            'capacity': details['capacity'],
            'sold_count': 0,
            'sale_starts_at': details['sale_starts_at'],
            'sale_ends_at': details['sale_ends_at'],
            'has_sold': false,
            'has_orders': false,
            'requires_access_code': false,
          });
          return newId;
        }
        final t = mine.firstWhere((x) => x['tier_id'] == id, orElse: () => throw refuseTier('ticket type not found'));
        if (t['has_sold'] == true) {
          if (details['price_cents'] != t['price_cents']) throw refuseTier('tickets of this type have been sold, so its price cannot be changed. Add a new ticket type instead');
          if (name != t['name']) throw refuseTier('tickets of this type have been sold, so its name cannot be changed. Add a new ticket type instead');
        }
        if ((details['capacity'] as int) < (t['sold_count'] as int)) {
          throw refuseTier('the capacity cannot be lower than the ${t['sold_count']} tickets already sold');
        }
        t
          ..['name'] = name
          ..['price_cents'] = details['price_cents']
          ..['capacity'] = details['capacity']
          ..['sale_starts_at'] = details['sale_starts_at']
          ..['sale_ends_at'] = details['sale_ends_at'];
        return id;
      case 'remove_org_tier':
        final id = p['p_tier'] as String;
        final t = tiers.firstWhere((x) => x['tier_id'] == id, orElse: () => throw refuseTier('ticket type not found'));
        if (t['has_orders'] == true || (t['sold_count'] as int) > 0) {
          throw refuseTier('people have bought or started to buy this ticket type, so it cannot be removed. Set its sales to end now instead');
        }
        tiers.remove(t);
        return null;
    }
    throw StateError('unexpected call $function');
  }
}
