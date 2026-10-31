import 'dart:async';

import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/venue_access/services/venue_access_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

const accessKeys = ['bar_sales', 'ticket_checkins', 'capacity', 'table_sales', 'chat', 'settlement'];
const availableKeys = {'ticket_checkins', 'capacity', 'table_sales'};

class FakeAccessAgreement {
  FakeAccessAgreement(this.id, this.eventId, this.eventTitle, this.venueName, this.status, {Set<String>? grants, this.agreedCapacity}) : grants = grants ?? {};

  final String id;
  final String eventId;
  final String eventTitle;
  final String venueName;
  String status;
  final Set<String> grants;
  int? agreedCapacity;

  bool get inForce => status == 'active' || status == 'changes_pending';
}

/// The database's venue access functions as a fake, with the rules and sentences of the SQL (website repo, 20261117100000_agreement_access.sql, tested there) and the figures of its test.
/// [role] is who is signed in: 'club' (the owner or manager of the club), 'organizer' or 'stranger'.
class FakeAccessBackend {
  FakeAccessBackend({this.role = 'club'}) {
    agreements['a1'] = FakeAccessAgreement('a1', 'e1', 'Night One', 'Club A', 'active', grants: {'table_sales', 'capacity'}, agreedCapacity: 250);
    agreements['a2'] = FakeAccessAgreement('a2', 'e1', 'Night One', 'Club B', 'negotiating');
    agreements['a3'] = FakeAccessAgreement('a3', 'e2', 'Late Night', 'Club A', 'requested');
  }

  String role;
  final agreements = <String, FakeAccessAgreement>{};
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  bool mixedCurrency = false;
  final Map<String, Completer<void>> gates = {};

  VenueAccessService get service => VenueAccessService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  Map<String, dynamic> _grantList(FakeAccessAgreement a, {bool withNames = false, bool withData = false}) => {
        'grants': [
          for (final k in accessKeys)
            {
              'key': k,
              'allowed': a.inForce && a.grants.contains(k),
              'available': availableKeys.contains(k),
              if (withNames) 'granted_by_name': a.inForce && a.grants.contains(k) ? 'Staff member' : null,
              if (withNames) 'granted_at': a.inForce && a.grants.contains(k) ? '2026-10-09T18:00:00Z' : null,
              if (withData) 'data': a.inForce && a.grants.contains(k) && availableKeys.contains(k) ? _data(a, k) : null,
            },
        ],
      };

  Map<String, dynamic> _data(FakeAccessAgreement a, String key) => switch (key) {
        'table_sales' => {
            'night': '2026-10-09',
            'tables': 3,
            'guests': 9,
            'currency_mixed': mixedCurrency,
            'currency': mixedCurrency ? null : 'CAD',
            'booked_cents': mixedCurrency ? null : 18000,
            'paid_cents': mixedCurrency ? null : 15800,
          },
        'capacity' => {'agreed': a.agreedCapacity, 'tickets_sold': 6, 'checked_in': 2},
        _ => {'checked_in': 2, 'tickets_sold': 6, 'last_check_in_at': '2026-10-09T23:30:00Z'},
      };

  Map<String, dynamic> sales(String eventId) {
    final isOne = eventId == 'e1';
    return {
      'generated_at': '2026-10-09T23:40:00Z',
      'event': {'id': eventId, 'title': isOne ? 'Night One' : 'Late Night', 'start': '2026-10-10T02:00:00Z', 'end': '2026-10-10T08:00:00Z', 'status': 'published', 'capacity': isOne ? 400 : null, 'venue_name': 'Club A'},
      'tickets': isOne
          ? {
              'orders': 3,
              'tickets_sold': 6,
              'checked_in': 2,
              'refunded_orders': 1,
              'refunded_cents': 3000,
              'currency_mixed': mixedCurrency,
              'currency': mixedCurrency ? null : 'CAD',
              'gross_cents': mixedCurrency ? null : 36000,
              'by_tier': [
                {'tier': 'General', 'price_cents': 3000, 'capacity': 500, 'currency': 'CAD', 'sold': 3, 'checked_in': 2, 'gross_cents': 9000},
                {'tier': 'VIP', 'price_cents': 9000, 'capacity': 50, 'currency': 'CAD', 'sold': 3, 'checked_in': 0, 'gross_cents': 27000},
              ],
            }
          : {'orders': 0, 'tickets_sold': 0, 'checked_in': 0, 'refunded_orders': 0, 'refunded_cents': 0, 'currency_mixed': false, 'currency': 'CAD', 'gross_cents': 0, 'by_tier': <Map<String, dynamic>>[]},
      'venues': [
        for (final a in agreements.values)
          if (a.eventId == eventId && a.status != 'declined' && a.status != 'cancelled')
            {'agreement_id': a.id, 'venue_id': 'v-${a.venueName}', 'venue_name': a.venueName, 'status': a.status, 'in_force': a.inForce, ..._grantList(a, withData: true)},
      ],
    };
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    final gate = gates[function];
    if (gate != null) await gate.future;
    switch (function) {
      case 'agreement_grants':
        {
          final a = agreements[params!['p_agreement']];
          if (a == null || role == 'stranger') throw refuse('not allowed');
          final side = role == 'club' ? 'venue' : 'organizer';
          return {'agreement_id': a.id, 'status': a.status, 'side': side, 'in_force': a.inForce, 'can_change': side == 'venue' && a.inForce, ..._grantList(a, withNames: side == 'venue')};
        }
      case 'set_agreement_grant':
        {
          final a = agreements[params!['p_agreement']];
          if (a == null || role != 'club') throw refuse('not allowed');
          final key = params['p_grant'];
          final allowed = params['p_allowed'];
          if (key == null || !accessKeys.contains(key)) throw refuse('choose one of the things a club can share');
          if (allowed == null) throw refuse('say whether to share it, yes or no');
          if (!a.inForce) throw refuse('the agreement has to be active before you can share anything under it');
          return allowed == true ? a.grants.add(key as String) : a.grants.remove(key);
        }
      case 'organizer_venue_access':
        {
          if (role != 'organizer') throw refuse('not allowed');
          return [
            for (final a in agreements.values)
              if (a.status != 'declined' && a.status != 'cancelled')
                {'agreement_id': a.id, 'event_id': a.eventId, 'event_title': a.eventTitle, 'event_start': '2026-10-10T02:00:00Z', 'venue_id': 'v-${a.venueName}', 'venue_name': a.venueName, 'status': a.status, 'in_force': a.inForce, ..._grantList(a)},
          ];
        }
      case 'organizer_event_sales':
        {
          if (role != 'organizer') throw refuse('not allowed');
          final id = params!['p_event'];
          if (id != 'e1' && id != 'e2') throw refuse('not allowed');
          return sales(id as String);
        }
    }
    throw StateError('unexpected call $function');
  }
}
