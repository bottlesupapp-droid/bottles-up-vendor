import 'dart:async';

import 'package:bottles_up_vendor/features/bottle_signs/services/bottle_sign_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeSignBottle {
  FakeSignBottle(this.id, this.name, {this.size = '750ml', this.category = 'Spirits', this.eligible = false});

  final String id;
  final String name;
  final String? size;
  final String? category;
  bool eligible;
}

class FakeSignLine {
  FakeSignLine(this.id, this.bookingId, this.bottleId, {this.state = 'awaiting_prep', this.cancelled = false, this.text, this.status, this.note, this.setBy, this.name = 'Patron', this.quantity = 1, this.guest = 'Ada Lovelace'});

  final String id;
  final String bookingId;
  final String? bottleId;
  String state;
  bool cancelled;
  String? text;
  String? status;
  String? note;
  String? setBy;
  String name;
  int quantity;
  String guest;
}

/// The database's bottle sign functions as a fake, with the rules and sentences of the SQL (website repo, 20261116100000_bottle_signs.sql, tested there). [role] is who is signed in:
/// 'manager', 'owner', 'server', 'verifier', 'door' or 'stranger'. A server holds the tables in [myTables].
class FakeSignBackend {
  FakeSignBackend({this.role = 'manager'});

  String role;
  final String me = 'u-me';
  String mode = 'off';
  bool review = false;
  final Set<String> myTables = {'b1'};
  final bottles = <String, FakeSignBottle>{};
  final lines = <String, FakeSignLine>{};
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;

  /// A function name -> a future the call waits for, to look at a screen while a call is on its way.
  final Map<String, Completer<void>> gates = {};

  BottleSignService get service => BottleSignService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  bool get _editor => role == 'manager' || role == 'owner';

  String? _level(String bookingId) {
    if (_editor) return 'manager';
    if (role == 'server' && myTables.contains(bookingId)) return 'server';
    if (role == 'verifier') return 'verifier';
    return null;
  }

  bool _eligible(FakeSignLine l) => mode == 'all' || (mode == 'selected' && (bottles[l.bottleId]?.eligible ?? false));
  bool _open(FakeSignLine l) => !l.cancelled && l.state != 'picked_up' && l.state != 'served';

  Map<String, dynamic> _settings() => {
        'mode': mode,
        'review_required': review,
        'bottles': [
          for (final b in bottles.values) {'id': b.id, 'name': b.name, 'size': b.size, 'category': b.category, 'sign_eligible': b.eligible, 'is_available': true},
        ],
      };

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    final gate = gates[function];
    if (gate != null) await gate.future;
    switch (function) {
      case 'venue_sign_settings':
        if (!_editor) throw refuse('not allowed');
        return _settings();
      case 'save_venue_sign_settings':
        {
          if (!_editor) throw refuse('not allowed');
          final d = Map<String, dynamic>.from(params!['p_details'] as Map);
          for (final k in d.keys) {
            if (k != 'mode' && k != 'review_required') throw refuse('unknown field: $k');
          }
          final m = d['mode'];
          if (m != null && !['off', 'all', 'selected'].contains(m)) throw refuse('signs must be off, on every bottle, or on the bottles you choose');
          if (d.containsKey('review_required') && d['review_required'] is! bool) throw refuse('say whether a sign needs a manager\'s approval, yes or no');
          if (m == null && !d.containsKey('review_required')) throw refuse('choose how signs work');
          if (m != null) mode = m as String;
          if (d.containsKey('review_required')) review = d['review_required'] as bool;
          return _settings();
        }
      case 'set_bottle_sign_eligible':
        {
          if (!_editor) throw refuse('not allowed');
          final b = bottles[params!['p_bottle']];
          if (b == null) throw refuse('that bottle is not on this club\'s menu');
          final want = params['p_eligible'] as bool;
          if (b.eligible == want) return false;
          b.eligible = want;
          return true;
        }
      case 'desk_line_signs':
        {
          final ids = List<String>.from(params!['p_lines'] as List);
          if (ids.length > 500) throw refuse('ask for at most 500 items at a time');
          return [
            for (final id in ids)
              if (lines[id] case final l? when (_level(l.bookingId) == 'manager' || _level(l.bookingId) == 'server'))
                if (l.text != null || (_open(l) && _eligible(l)))
                  {'line_id': l.id, 'sign_text': l.text, 'sign_status': l.status, 'review_note': l.note, 'can_set': _open(l) && _eligible(l), 'review_required': review},
          ];
        }
      case 'desk_set_bottle_sign':
        {
          final l = lines[params!['p_line']];
          final level = l == null ? null : _level(l.bookingId);
          if (level != 'manager' && level != 'server') throw refuse('not allowed');
          if (l!.cancelled) throw refuse('this item was cancelled');
          if (!_open(l)) throw refuse('this item is already on its way, so its sign can no longer change');
          final text = (params['p_text'] as String? ?? '').trim();
          if (text.isEmpty) {
            if (l.text == null) return {'changed': false, 'sign_text': null, 'sign_status': null};
            l.text = l.status = l.note = l.setBy = null;
            return {'changed': true, 'sign_text': null, 'sign_status': null};
          }
          if (text.length > 40) throw refuse('a sign is at most 40 characters');
          if (RegExp(r'[\u0000-\u001F]').hasMatch(text)) throw refuse('a sign is one line of plain text');
          if (mode == 'off') throw refuse('signs are not switched on for this club');
          if (mode == 'selected' && !(bottles[l.bottleId]?.eligible ?? false)) throw refuse('this bottle is not one of the club\'s sign bottles');
          if (l.text == text) return {'changed': false, 'sign_text': l.text, 'sign_status': l.status};
          l.text = text;
          l.status = review && level == 'server' ? 'pending_review' : 'approved';
          l.note = null;
          l.setBy = me;
          return {'changed': true, 'sign_text': text, 'sign_status': l.status};
        }
      case 'desk_review_bottle_sign':
        {
          final l = lines[params!['p_line']];
          if (l == null || _level(l.bookingId) != 'manager') throw refuse('not allowed');
          final decision = params['p_decision'];
          final note = (params['p_note'] as String?)?.trim();
          if (decision != 'approve' && decision != 'reject') throw refuse('approve the sign or decline it');
          if (decision == 'reject' && (note == null || note.length < 3)) throw refuse('say why the sign is declined (at least 3 characters)');
          if (note != null && note.length > 200) throw refuse('keep the reason to 200 characters or fewer');
          final to = decision == 'approve' ? 'approved' : 'rejected';
          if (l.text == null) throw refuse('this item has no sign');
          if (l.status == to) return {'changed': false, 'sign_status': to};
          if (l.status != 'pending_review') throw refuse('this sign was already reviewed');
          if (l.setBy == me) throw refuse('someone else has to review your sign');
          l.status = to;
          l.note = to == 'rejected' ? note : null;
          return {'changed': true, 'sign_status': to};
        }
      case 'desk_pending_sign_reviews':
        {
          if (!_editor) throw refuse('not allowed');
          return [
            for (final l in lines.values)
              if (l.status == 'pending_review' && !l.cancelled && _open(l))
                {'line_id': l.id, 'booking_id': l.bookingId, 'bottle_name': l.name, 'quantity': l.quantity, 'sign_text': l.text, 'set_by_name': 'Sam Server', 'set_at': '2026-10-09T20:30:00Z', 'guest_name': l.guest, 'service_status': l.state},
          ];
        }
    }
    throw StateError('unexpected call $function');
  }
}
