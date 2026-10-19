import 'dart:async';

import 'package:bottles_up_vendor/features/organizer_events/services/organizer_events_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// A stand-in for the website's `list_org_events`, `save_org_event` and `remove_org_event` that behaves the way they do: events are
/// always created as drafts, only the whitelisted fields are accepted, only the fields sent are changed (so a photo that is not sent
/// survives an edit), a published event is out of reach, and a refusal is the database's own sentence raised as P0001.
class FakeOrganizerEventsBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final List<Map<String, dynamic>> events = [];
  Object? failAll;

  /// The states list_org_event_states answers, by event id. An event with no entry is a plain draft that no club was asked about (a published
  /// one is live).
  final Map<String, Map<String, dynamic>> states = {};
  bool statesFail = false;
  void Function(String function)? beforeCall;
  Future<void>? hold;
  int _next = 1;

  static const allowed = {'title', 'description', 'venue_name', 'address', 'start_date', 'end_date', 'category', 'capacity', 'cover_image_url'};

  OrganizerEventsService get service => OrganizerEventsService(rpc: call);

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'list_org_event_states':
        if (statesFail) throw StateError('relation "site_agreements" does not exist');
        return [
          for (final e in events)
            {
              'event_id': e['event_id'],
              'state': e['status'] == 'draft' ? 'draft' : 'live',
              'blockers': e['status'] == 'draft' ? ['venue_request'] : <String>[],
              'agreement_id': null,
              'agreement_status': null,
              'venue_name': null,
              ...?states[e['event_id']],
            },
        ];
      case 'list_org_events':
        return [for (final e in events) Map<String, dynamic>.from(e)];
      case 'save_org_event':
        final details = p['p_details'] as Map<String, dynamic>;
        for (final k in details.keys) {
          if (!allowed.contains(k)) throw refuse('unknown field: $k');
        }
        final id = p['p_event'] as String?;
        if (id == null) {
          if (events.length >= 200) throw refuse('a business can have 200 events at most');
          final row = <String, dynamic>{
            'event_id': 'e${_next++}', 'status': 'draft', 'ticket_tier_count': 0, 'cover_image_url': null, 'address': null, 'end_date': null, 'category': null, 'capacity': null, ...details,
          };
          events.add(row);
          return row['event_id'];
        }
        final i = events.indexWhere((e) => e['event_id'] == id);
        if (i < 0) throw refuse('event not found');
        if (events[i]['status'] != 'draft') throw refuse('this event is published, so only BottlesUp can change it');
        events[i] = {...events[i], ...details};
        return id;
      case 'remove_org_event':
        final i = events.indexWhere((e) => e['event_id'] == p['p_event']);
        if (i < 0) throw refuse('event not found');
        if (events[i]['status'] != 'draft') throw refuse('this event is published, so only BottlesUp can remove it');
        if (events[i]['has_orders'] == true) throw refuse('this event already has orders, so it cannot be removed');
        events.removeAt(i);
        return null;
    }
    throw StateError('no handler for $function');
  }

  int count(String fn) => calls.where((c) => c.$1 == fn).length;
  List<Map<String, dynamic>?> paramsOf(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> eventRow(String id, String title,
        {String status = 'draft', String start = '2031-10-24T22:00:00Z', String? end, String venue = 'The Roof', String? address, int? capacity, String? cover, String? category}) =>
    {
      'event_id': id, 'title': title, 'description': 'Dancing under the stars', 'venue_name': venue, 'address': address, 'start_date': start, 'end_date': end,
      'category': category, 'capacity': capacity, 'cover_image_url': cover, 'status': status, 'ticket_tier_count': 0,
    };
