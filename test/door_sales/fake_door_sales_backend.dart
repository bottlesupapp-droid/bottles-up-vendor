import 'package:bottles_up_vendor/features/door_sales/services/door_sales_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The website's door sales (20261026100000_door_sales.sql) as a fake with the same checks, in the same order, with the same sentences: who may, when selling is open, what must be filled
/// in, the capacity, and the same key being the same sale. Every call is recorded with its exact parameter names.
class FakeDoorSalesBackend {
  /// 'door', or 'none' (signed out / no door role for the event).
  String role = 'door';
  bool windowOpen = true;

  /// The tiers of the event: id, name, price_cents, capacity, sold_count, gated.
  List<Map<String, dynamic>> tiers = [
    tier('t-gen', 'General', 5000, 10, 2),
    tier('t-vip', 'VIP', 12000, 3, 0),
    tier('t-full', 'Sold Out', 3000, 2, 2),
  ];

  /// The sales made, newest last, by key.
  final Map<String, Map<String, dynamic>> sales = {};
  int _n = 0;

  /// The figures the shift summary answers for scanning (the sales part is computed from [sales]).
  int guestsAdmitted = 0;
  int scansAccepted = 0;

  final List<(String, Map<String, dynamic>?)> calls = [];
  Object? failAll;

  /// Fails only a sale (the options and the shift still answer).
  Object? failSell;
  void Function(String function)? beforeCall;

  /// The next sale is recorded but its answer is lost (a dropped connection after the database committed).
  bool loseNextAnswer = false;

  DoorSalesService get service => DoorSalesService(caller: call);

  static Map<String, dynamic> tier(String id, String name, int price, int capacity, int sold, {bool gated = false}) =>
      {'id': id, 'name': name, 'price_cents': price, 'capacity': capacity, 'sold_count': sold, 'gated': gated};

  List<Map<String, dynamic>> callsOf(String function) => [
        for (final c in calls)
          if (c.$1 == function) c.$2 ?? {},
      ];

  int get orderCount => sales.length;
  int soldOf(String tierId) => tiers.firstWhere((t) => t['id'] == tierId)['sold_count'] as int;

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    if (role != 'door') throw refuse('not authorized');
    if (function == 'door_sell_ticket' && failSell != null) throw failSell!;
    switch (function) {
      case 'door_sale_options':
        return _options(params!);
      case 'door_sell_ticket':
        return _sell(params!);
      case 'door_shift_summary':
        return _summary(params!);
    }
    throw StateError('unexpected call $function');
  }

  static const _optionKeys = ['p_event'];
  static const _sellKeys = ['p_client_key', 'p_email', 'p_event', 'p_method', 'p_name', 'p_phone', 'p_quantity', 'p_reference', 'p_tier'];

  void _only(Map<String, dynamic> p, List<String> keys) {
    final got = p.keys.toList()..sort();
    if (got.join(',') != keys.join(',')) throw StateError('the database takes $keys, the app sent $got');
  }

  List<Map<String, dynamic>> _options(Map<String, dynamic> p) {
    _only(p, _optionKeys);
    if (!windowOpen) throw refuse('ticket sales at the door are not open for this event');
    final rows = [
      for (final t in tiers)
        if (t['gated'] != true)
          {
            'tier_id': t['id'],
            'tier_name': t['name'],
            'price_cents': t['price_cents'],
            'currency': 'cad',
            'capacity': t['capacity'],
            'sold_count': t['sold_count'],
            'available': ((t['capacity'] as int) - (t['sold_count'] as int)).clamp(0, 1 << 30),
          },
    ]..sort((a, b) {
        final byPrice = (a['price_cents'] as int).compareTo(b['price_cents'] as int);
        return byPrice != 0 ? byPrice : (a['tier_name'] as String).compareTo(b['tier_name'] as String);
      });
    return rows;
  }

  Map<String, dynamic> _answer(Map<String, dynamic> sale, Map<String, dynamic> t, {required bool repeated}) => {
        'order_id': sale['order_id'],
        'ticket_code': sale['ticket_code'],
        'quantity': sale['quantity'],
        'amount_cents': sale['amount_cents'],
        'currency': 'cad',
        'tier_name': t['name'],
        'available': ((t['capacity'] as int) - (t['sold_count'] as int)).clamp(0, 1 << 30),
        'repeated': repeated,
      };

  Map<String, dynamic> _sell(Map<String, dynamic> p) {
    _only(p, _sellKeys);
    final key = ((p['p_client_key'] as String?) ?? '').trim();
    if (key.length < 8 || key.length > 80) throw refuse('a sale needs its own key of 8 to 80 characters');
    final old = sales[key];
    if (old != null) {
      if (old['event'] != p['p_event'] || old['tier'] != p['p_tier'] || old['quantity'] != p['p_quantity']) throw refuse('that sale key was already used for a different sale');
      return _answer(old, tiers.firstWhere((t) => t['id'] == old['tier']), repeated: true);
    }
    final method = p['p_method'];
    final reference = (p['p_reference'] as String?)?.trim();
    final ref = reference == null || reference.isEmpty ? null : reference;
    final name = ((p['p_name'] as String?) ?? '').trim();
    final email = ((p['p_email'] as String?) ?? '').trim().toLowerCase();
    final phone = (p['p_phone'] as String?)?.trim();
    final qty = p['p_quantity'];
    if (method != 'cash' && method != 'external_terminal') throw refuse('choose how it was paid: cash, or the card terminal');
    if (method == 'external_terminal' && ref == null) throw refuse('add the terminal\'s receipt number');
    if (ref != null && (ref.length < 3 || ref.length > 120)) throw refuse('the receipt number needs 3 to 120 characters');
    if (name.length < 2 || name.length > 120) throw refuse('the guest\'s name needs 2 to 120 characters');
    if (email.isNotEmpty && (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) || email.length > 254)) throw refuse('enter a valid email address, or leave it empty');
    if (phone != null && phone.length > 40) throw refuse('the phone number is too long');
    if (qty is! int || qty < 1 || qty > 20) throw refuse('how many tickets? between 1 and 20');
    if (!windowOpen) throw refuse('ticket sales at the door are not open for this event');
    final matches = tiers.where((t) => t['id'] == p['p_tier']);
    if (matches.isEmpty) throw refuse('ticket type not found');
    final t = matches.first;
    if (t['gated'] == true) throw refuse('that ticket type is not sold at the door');
    final left = ((t['capacity'] as int) - (t['sold_count'] as int)).clamp(0, 1 << 30);
    if (qty > left) throw refuse('only $left of these tickets are left');
    _n++;
    final sale = {
      'order_id': 'order-$_n',
      'ticket_code': 'BU-FAKE${_n.toString().padLeft(4, '0')}',
      'quantity': qty,
      'amount_cents': (t['price_cents'] as int) * qty,
      'event': p['p_event'],
      'tier': p['p_tier'],
      'method': method,
      'reference': ref,
      'name': name,
      'email': email,
      'phone': phone,
      'at': DateTime.utc(2026, 10, 24, 19, _n).toIso8601String(),
    };
    sales[key] = sale;
    t['sold_count'] = (t['sold_count'] as int) + qty;
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw Exception('connection lost');
    }
    return _answer(sale, t, repeated: false);
  }

  Map<String, dynamic> _summary(Map<String, dynamic> p) {
    _only(p, _optionKeys);
    final byMethod = <String, List<Map<String, dynamic>>>{};
    for (final s in sales.values) {
      byMethod.putIfAbsent(s['method'] as String, () => []).add(s);
    }
    final methods = byMethod.keys.toList()..sort();
    final all = sales.values.toList();
    return {
      'event_title': 'Friday Night',
      'guests_admitted': guestsAdmitted,
      'scans_accepted': scansAccepted,
      'sales': [
        for (final m in methods)
          {
            'method': m,
            'sales': byMethod[m]!.length,
            'tickets': byMethod[m]!.fold<int>(0, (a, s) => a + (s['quantity'] as int)),
            'amount_cents': byMethod[m]!.fold<int>(0, (a, s) => a + (s['amount_cents'] as int)),
          },
      ],
      'first_sale_at': all.isEmpty ? null : all.first['at'],
      'last_sale_at': all.isEmpty ? null : all.last['at'],
    };
  }
}
