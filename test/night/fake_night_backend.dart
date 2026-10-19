import 'dart:convert';

import 'package:bottles_up_vendor/features/night/services/night_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

const checklistItems = <(String, String, String)>[
  ('floor_ready', 'Floor plan and tables are set up', 'prepare'),
  ('servers_assigned', 'Every booked table has a server', 'prepare'),
  ('stock_ready', 'Bottles and stock checked', 'prepare'),
  ('float_ready', 'Cash float counted', 'prepare'),
  ('security_briefed', 'Security briefed', 'prepare'),
  ('doors_ready', 'Door team ready', 'prepare'),
  ('floor_cleared', 'Floor cleared and tables released', 'close'),
  ('stock_counted', 'Closing stock counted', 'close'),
  ('cash_secured', 'Cash counted and locked away', 'close'),
];

/// The full report as the database would give a manager, with the figures of the SQL test.
Map<String, dynamic> sampleFullReport() => {
      'venue_name': 'Club A',
      'business_night': '2026-10-09',
      'generated_at': '2026-10-09T23:40:00Z',
      'bookings': {'count': 2, 'guests': 4, 'total_cents': 16000, 'paid_cents': 13800, 'balance_cents': 2200, 'discount_cents': 0, 'seated': 1},
      'payments': {
        'count': 5, 'collected_cents': 13800, 'billed_cents': 13800, 'cash_cents': 9500, 'debit_cents': 4000, 'credit_cents': 300, 'split_card_cents': 0,
        'tax_cents': 0, 'gratuity_cents': 0, 'discount_cents': 0, 'unverified': 4, 'disputed': 1, 'no_receipt': 5, 'corrections': 1,
      },
      'bottles': {'lines': 3, 'value_cents': 10000, 'served': 1, 'in_progress': 1, 'awaiting': 1, 'cancelled': 1, 'due_at_venue': 1},
      'cash': {'handovers': 1, 'claimed_cents': 8000, 'counted_cents': 7900, 'shortage_cents': 100, 'overage_cents': 0, 'waiting': 0, 'held_cents': 1500},
      'flags': {'raised': 2, 'open': 1, 'resolved': 1, 'by_resolution': {'confirmed_ok': 1}},
      'service': {'total': 2, 'open': 1, 'completed': 1, 'escalated': 0, 'cancelled': 0},
      'security': {
        'alerts': {'total': 2, 'urgent': 1, 'unresolved': 1, 'escalated': 0, 'by_kind': {'fight': 1, 'medical': 1}},
        'tasks': {'total': 1, 'done': 0, 'open': 1},
        'incidents': [
          {'kind': 'fight', 'location': 'Terrace', 'status': 'submitted'},
        ],
      },
    };

/// The database's night functions as a fake with the same sentences the SQL raises. [role] is who is signed in:
/// 'manager', 'owner', 'verifier', 'security' or 'server'.
class FakeNightBackend {
  FakeNightBackend({this.role = 'manager'});

  String role;
  final Set<String> ticked = {};
  List<Map<String, dynamic>> blockers = [];
  String status = 'open';
  Map<String, dynamic>? closedReport;
  List<Map<String, dynamic>> closedExceptions = [];
  String? closedNote;
  String? reopenReason;
  Map<String, dynamic> live = sampleFullReport();
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  int closeCount = 0;

  NightService get service => NightService(rpc: OpsRpc(rpc: call));

  bool get _manager => role == 'manager' || role == 'owner';

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  List<String> get _closeItemsOpen => [for (final i in checklistItems) if (i.$3 == 'close' && !ticked.contains(i.$1)) i.$2];

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'night_checklist':
        {
          if (!_manager) throw refuse('not allowed');
          return [
            for (final i in checklistItems)
              {
                'item_key': i.$1,
                'label': i.$2,
                'phase': i.$3,
                'done': ticked.contains(i.$1),
                'done_by_name': ticked.contains(i.$1) ? 'Mia Manager' : null,
                'done_at': ticked.contains(i.$1) ? '2026-10-09T20:00:00Z' : null,
              },
          ];
        }
      case 'night_check':
        {
          if (!_manager) throw refuse('not allowed');
          final key = params!['p_key'];
          if (!checklistItems.any((i) => i.$1 == key)) throw refuse('choose a checklist item');
          if (status == 'closed') throw refuse('this night is closed: the owner has to reopen it first');
          return params['p_done'] == true ? ticked.add(key as String) : ticked.remove(key);
        }
      case 'night_close_status':
        {
          if (!_manager) throw refuse('not allowed');
          return {
            'status': status,
            'closed': status == 'closed',
            'closed_at': status == 'closed' ? '2026-10-10T02:15:00Z' : null,
            'closed_by_name': status == 'closed' ? 'Mia Manager' : null,
            'exceptions': status == 'closed' ? closedExceptions : <Map<String, dynamic>>[],
            'exceptions_note': status == 'closed' ? closedNote : null,
            'reopened_at': status == 'reopened' ? '2026-10-10T09:00:00Z' : null,
            'reopen_reason': status == 'reopened' ? reopenReason : null,
            'blockers': blockers,
            'close_items_open': _closeItemsOpen,
          };
        }
      case 'close_night':
        {
          if (!_manager) throw refuse('not allowed');
          if (status == 'closed') throw refuse('this night is already closed');
          final exceptions = <Map<String, dynamic>>[
            ...blockers,
            for (final l in _closeItemsOpen) {'key': l, 'label': l, 'count': 1, 'kind': 'checklist'},
          ];
          final note = (params!['p_note'] as String?)?.trim();
          if (exceptions.isNotEmpty) {
            if (params['p_acknowledge'] != true) {
              throw refuse('still open: ${exceptions.map((e) => e['kind'] == 'checklist' ? 'not ticked: ${e['label']}' : '${e['count']} ${e['label']}').join(', ')}. Deal with it, or close with exceptions and say why');
            }
            if (note == null || note.length < 10) throw refuse('say why you are closing with these still open (at least 10 characters)');
          }
          status = 'closed';
          closeCount++;
          closedExceptions = exceptions;
          closedNote = exceptions.isEmpty ? null : note;
          closedReport = jsonDecode(jsonEncode(live)) as Map<String, dynamic>;
          return {'closed_at': '2026-10-10T02:15:00Z', 'exceptions': exceptions.length};
        }
      case 'reopen_night':
        {
          if (role != 'owner') throw refuse('not allowed');
          final reason = (params!['p_reason'] as String).trim();
          if (reason.length < 10) throw refuse('say why this night is being reopened (at least 10 characters)');
          if (status != 'closed') throw refuse('this night is not closed');
          status = 'reopened';
          reopenReason = reason;
          return null;
        }
      case 'night_report':
        {
          final view = _manager ? 'full' : (role == 'verifier' ? 'finance' : (role == 'security' ? 'security' : null));
          if (view == null) throw refuse('not allowed');
          final data = status == 'closed' ? closedReport! : live;
          final out = <String, dynamic>{
            'view': view,
            'final': status == 'closed',
            'venue_name': data['venue_name'],
            'business_night': data['business_night'],
            'generated_at': data['generated_at'],
          };
          if (status == 'closed') {
            out['closed_at'] = '2026-10-10T02:15:00Z';
            out['closed_by_name'] = 'Mia Manager';
            if (view != 'security') {
              out['exceptions'] = closedExceptions;
              out['exceptions_note'] = closedNote;
            }
          }
          if (view == 'full' || view == 'finance') {
            for (final k in ['bookings', 'payments', 'cash', 'flags']) {
              out[k] = data[k];
            }
          }
          if (view == 'full') {
            out['bottles'] = data['bottles'];
            out['service'] = data['service'];
          }
          if (view == 'full' || view == 'security') out['security'] = data['security'];
          return out;
        }
    }
    throw StateError('unexpected call $function');
  }
}
