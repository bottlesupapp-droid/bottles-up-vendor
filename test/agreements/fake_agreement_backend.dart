import 'package:bottles_up_vendor/features/agreements/services/agreement_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeVersion {
  FakeVersion(this.version, this.terms, this.proposedBySide, {this.note}) {
    if (proposedBySide == 'organizer') organizerBy = 'Olive Organizer';
    if (proposedBySide == 'venue') venueBy = 'Mia Manager';
  }

  final int version;
  final Map<String, dynamic> terms;
  final String proposedBySide;
  final String? note;
  String? organizerBy;
  String? venueBy;
}

class FakeAgreement {
  FakeAgreement(this.id, this.event, this.venue, {this.requestNote});

  final String id;
  final String event;
  final String venue;
  final String? requestNote;
  String status = 'requested';
  int current = 0;
  int? active;
  String? closedReason;
  final List<FakeVersion> versions = [];
  final List<({String side, String body, bool mine})> notes = [];
}

/// The database's agreement functions as a fake with the same sentences the SQL raises. [side] is who the signed-in person is:
/// 'venue' or 'organizer'. Use [otherProposes] and [otherAccepts] to play the other party.
class FakeAgreementBackend {
  FakeAgreementBackend({this.side = 'venue'});

  String side;
  final List<FakeAgreement> agreements = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  int _ids = 0;

  AgreementService get service => AgreementService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeAgreement agreement(String id) => agreements.firstWhere((a) => a.id == id);

  String get _other => side == 'venue' ? 'organizer' : 'venue';

  /// The other party proposes terms (a new version they have accepted themselves).
  void otherProposes(String id, Map<String, dynamic> terms, {String? note}) {
    final a = agreement(id);
    a.current++;
    final v = FakeVersion(a.current, terms, _other, note: note);
    if (_other == 'organizer') {
      v.organizerBy = 'Olive Organizer';
    } else {
      v.venueBy = 'Vera Venue';
    }
    a.versions.add(v);
    a.status = a.active == null ? 'negotiating' : 'changes_pending';
  }

  void otherAccepts(String id) {
    final a = agreement(id);
    final v = a.versions.last;
    if (_other == 'organizer') {
      v.organizerBy = 'Olive Organizer';
    } else {
      v.venueBy = 'Vera Venue';
    }
    a.status = 'active';
    a.active = v.version;
  }

  String? _waiting(FakeAgreement a) {
    if (a.status == 'declined' || a.status == 'cancelled') return null;
    if (a.current == 0) return 'venue';
    final v = a.versions.last;
    if (v.organizerBy != null && v.venueBy != null) return null;
    return v.organizerBy == null ? 'organizer' : 'venue';
  }

  Map<String, dynamic> _detail(FakeAgreement a) {
    final v = a.versions.isEmpty ? null : a.versions.last;
    final mineAccepted = v == null ? true : (side == 'organizer' ? v.organizerBy != null : v.venueBy != null);
    final closed = a.status == 'declined' || a.status == 'cancelled';
    return {
      'agreement_id': a.id,
      'status': a.status,
      'side': side,
      'event_title': a.event,
      'event_start': '2026-11-01T21:00:00Z',
      'venue_name': a.venue,
      'organizer_name': 'Night Events',
      'current_version': a.current,
      'active_version': a.active,
      'request_note': a.requestNote,
      'closed_reason': a.closedReason,
      'can_accept': !closed && v != null && !mineAccepted,
      'can_propose': !closed,
      'can_close': !closed,
      'versions': [
        for (final x in a.versions.reversed)
          {
            'version': x.version,
            'terms': x.terms,
            'note': x.note,
            'proposed_by_side': x.proposedBySide,
            'proposed_at': '2026-10-09T20:00:00Z',
            'proposed_by_name': x.proposedBySide == 'organizer' ? 'Olive Organizer' : 'Mia Manager',
            'organizer_accepted_at': x.organizerBy == null ? null : '2026-10-09T20:00:00Z',
            'organizer_accepted_by_name': x.organizerBy,
            'venue_accepted_at': x.venueBy == null ? null : '2026-10-09T20:05:00Z',
            'venue_accepted_by_name': x.venueBy,
            'is_active': a.active == x.version,
          },
      ],
      'notes': [for (final n in a.notes) {'side': n.side, 'version': a.current == 0 ? null : a.current, 'body': n.body, 'created_at': '2026-10-09T20:10:00Z', 'is_mine': n.mine, 'author_name': n.mine ? 'Me' : 'Someone'}],
    };
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'agreement_list':
        return [
          for (final a in agreements)
            {
              'agreement_id': a.id,
              'event_title': a.event,
              'event_start': '2026-11-01T21:00:00Z',
              'venue_name': a.venue,
              'organizer_name': 'Night Events',
              'status': a.status,
              'current_version': a.current,
              'active_version': a.active,
              'side': params!['p_venue'] != null ? 'venue' : 'organizer',
              'waiting_on': _waiting(a),
              'requested_at': '2026-10-01T10:00:00Z',
              'closed_reason': a.closedReason,
            },
        ];
      case 'agreement_detail':
        return _detail(agreement(params!['p_agreement'] as String));
      case 'search_venues':
        final q = (params!['p_query'] as String).toLowerCase();
        return [
          for (final v in const [('v1', 'Club A', true), ('v2', 'Club Alpha', true), ('v3', 'Club Alone', false)])
            if (v.$2.toLowerCase().contains(q)) {'venue_id': v.$1, 'name': v.$2, 'address': '1 Main St', 'is_claimed': v.$3, 'claimed_by_you': false},
        ];
      case 'agreement_request':
        {
          if (side != 'organizer') throw refuse('not allowed');
          final venue = params!['p_venue'] as String;
          if (agreements.any((a) => a.venue == venue && a.status != 'declined' && a.status != 'cancelled')) throw refuse('this event already has an agreement with that club');
          final a = FakeAgreement('a${_ids++}', 'Night One', venue, requestNote: params['p_message'] as String?);
          agreements.add(a);
          return a.id;
        }
      case 'agreement_propose':
        {
          final a = agreement(params!['p_agreement'] as String);
          if (a.status == 'declined' || a.status == 'cancelled') throw refuse('this agreement is closed');
          final terms = Map<String, dynamic>.from(params['p_terms'] as Map);
          if (terms.isEmpty) throw refuse('propose at least one term');
          if (terms['bar_percent'] is num && (terms['bar_percent'] as num) > 0 && terms['threshold_cents'] == null) throw refuse('a share of bar sales needs a threshold (0 if it applies from the first sale)');
          a.current++;
          a.versions.add(FakeVersion(a.current, terms, side, note: params['p_note'] as String?));
          a.status = a.active == null ? 'negotiating' : 'changes_pending';
          return a.current;
        }
      case 'agreement_accept':
        {
          final a = agreement(params!['p_agreement'] as String);
          if (a.status == 'declined' || a.status == 'cancelled') throw refuse('this agreement is closed');
          if (a.current == 0) throw refuse('nothing has been proposed yet');
          if (params['p_version'] != a.current) throw refuse('that version was replaced: read the latest one');
          final v = a.versions.last;
          if ((side == 'organizer' && v.organizerBy != null) || (side == 'venue' && v.venueBy != null)) return {'changed': false, 'status': a.status};
          if (side == 'organizer') {
            v.organizerBy = 'Me';
          } else {
            v.venueBy = 'Me';
          }
          a.status = 'active';
          a.active = v.version;
          return {'changed': true, 'status': 'active', 'version': v.version};
        }
      case 'agreement_note':
        {
          final a = agreement(params!['p_agreement'] as String);
          final body = (params['p_body'] as String).trim();
          if (body.isEmpty) throw refuse('write the note first');
          a.notes.add((side: side, body: body, mine: true));
          return 'n${_ids++}';
        }
      case 'agreement_close':
        {
          final a = agreement(params!['p_agreement'] as String);
          if (a.status == 'declined' || a.status == 'cancelled') throw refuse('this agreement is already closed');
          final reason = (params['p_reason'] as String).trim();
          if (reason.length < 3) throw refuse('say why');
          a.status = side == 'venue' && a.active == null ? 'declined' : 'cancelled';
          a.closedReason = reason;
          return null;
        }
    }
    throw StateError('unexpected call $function');
  }
}
