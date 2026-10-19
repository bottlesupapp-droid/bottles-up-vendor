import 'package:bottles_up_vendor/features/inventory/services/inventory_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeBottle {
  FakeBottle(this.id, this.name, {this.size, this.stock, this.threshold, this.soldOut = false});

  final String id;
  final String name;
  final String? size;
  int? stock;
  int? threshold;
  bool soldOut;
}

class FakeMovement {
  FakeMovement(this.id, this.bottle, this.kind, this.delta, this.before, this.after, this.reason, this.note, this.key, this.by, this.at);

  final String id;
  final FakeBottle bottle;
  final String kind;
  final int delta;
  final int? before;
  final int after;
  final String? reason;
  final String? note;
  final String? key;
  final String by;
  final DateTime at;
}

/// The database's stock functions, as a fake with the same sentences the SQL raises. [role] is who is signed in ('me'): 'manager' or 'server'.
class FakeInventoryBackend {
  FakeInventoryBackend({this.role = 'manager'});

  String role;
  final List<FakeBottle> bottles = [];
  final List<FakeMovement> movements = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;

  /// Fail the next move AFTER recording it: the answer is lost, as on a bad connection. A retry with the same key must not add it twice.
  bool loseNextAnswer = false;
  DateTime now = DateTime.utc(2026, 10, 9, 21, 0);
  int _ids = 0;

  InventoryService get service => InventoryService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeBottle bottle(String id) => bottles.firstWhere((b) => b.id == id);

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    if (role != 'manager' && role != 'owner') throw refuse('not allowed');
    switch (function) {
      case 'stock_list':
        {
          final sorted = [...bottles]..sort((a, b) {
              final la = _low(a) ? 0 : 1, lb = _low(b) ? 0 : 1;
              return la != lb ? la.compareTo(lb) : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          return [
            for (final b in sorted)
              {
                'bottle_id': b.id,
                'name': b.name,
                'size': b.size,
                'tracked': b.stock != null,
                'quantity': b.stock,
                'low_threshold': b.threshold,
                'is_low': _low(b),
                'is_sold_out': b.soldOut,
                'last_moved_at': movements.where((m) => m.bottle == b).map((m) => m.at).fold<DateTime?>(null, (p, e) => p == null || e.isAfter(p) ? e : p)?.toIso8601String(),
              },
          ];
        }
      case 'stock_move':
        {
          final b = bottles.where((b) => b.id == params!['p_bottle']).firstOrNull ?? (throw refuse('not allowed'));
          final kind = params!['p_kind'] as String;
          final qty = params['p_quantity'] as int?;
          final reason = (params['p_reason'] as String?)?.trim();
          final key = params['p_client_key'] as String?;
          if (key != null) {
            final held = movements.where((m) => m.key == key).firstOrNull;
            if (held != null) return {'movement_id': held.id, 'changed': false, 'before': held.before, 'after': held.after};
          }
          final before = b.stock;
          late int after, delta;
          if (kind == 'count') {
            if (qty == null || qty < 0) throw refuse('enter the amount you counted (0 or more)');
            after = qty;
            delta = after - (before ?? after);
          } else {
            if (before == null) throw refuse('this bottle has not been counted yet: count it first');
            if (kind == 'receive') {
              if (qty == null || qty <= 0) throw refuse('enter how many arrived');
              delta = qty;
            } else if (kind == 'wastage') {
              if (qty == null || qty <= 0) throw refuse('enter how many were lost');
              if (reason == null || reason.length < 3) throw refuse('say what happened to them');
              delta = -qty;
            } else {
              if (qty == null || qty == 0) throw refuse('enter the plus or minus amount');
              if (reason == null || reason.length < 3) throw refuse('say why the level is being changed');
              delta = qty;
            }
            after = before + delta;
            if (after < 0) throw refuse('only $before in stock');
          }
          b.stock = after;
          final m = FakeMovement('m${_ids++}', b, kind, delta, before, after, reason, params['p_note'] as String?, key, 'Me', now.add(Duration(minutes: _ids)));
          movements.add(m);
          if (loseNextAnswer) {
            loseNextAnswer = false;
            throw Exception('SocketException: connection lost');
          }
          return {'movement_id': m.id, 'changed': true, 'before': before, 'after': after, 'low': b.threshold != null && after <= b.threshold!};
        }
      case 'stock_set_threshold':
        {
          final b = bottles.where((b) => b.id == params!['p_bottle']).firstOrNull ?? (throw refuse('not allowed'));
          final t = params!['p_threshold'] as int?;
          if (t != null && (t < 0 || t > 100000)) throw refuse('enter a low-stock level from 0 to 100000');
          b.threshold = t;
          return null;
        }
      case 'stock_movements':
        {
          final before = params!['p_before'] == null ? null : DateTime.parse(params['p_before'] as String);
          final limit = ((params['p_limit'] as int?) ?? 50).clamp(1, 100);
          final sorted = movements.where((m) => (params['p_bottle'] == null || m.bottle.id == params['p_bottle']) && (before == null || m.at.isBefore(before))).toList()
            ..sort((a, b) => b.at.compareTo(a.at));
          return [
            for (final m in sorted.take(limit))
              {
                'movement_id': m.id,
                'bottle_id': m.bottle.id,
                'bottle_name': m.bottle.name,
                'size': m.bottle.size,
                'kind': m.kind,
                'delta': m.delta,
                'before_qty': m.before,
                'after_qty': m.after,
                'reason': m.reason,
                'note': m.note,
                'by_name': m.by,
                'by_me': m.by == 'Me',
                'created_at': m.at.toIso8601String(),
              },
          ];
        }
    }
    throw StateError('unexpected call $function');
  }

  bool _low(FakeBottle b) => b.stock != null && b.threshold != null && b.stock! <= b.threshold!;
}
