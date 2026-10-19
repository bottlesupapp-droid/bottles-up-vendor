import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';

/// Stock of bottles: the level of each, and the record of how it was changed by hand. The database decides who may read or change stock,
/// that it never goes below 0, and that a retry is one movement. This file reads what it sends, words it, and checks what was typed.

class StockItem {
  const StockItem({
    required this.bottleId,
    required this.name,
    required this.tracked,
    required this.isLow,
    required this.isSoldOut,
    this.size,
    this.quantity,
    this.lowThreshold,
    this.lastMovedAt,
  });

  final String bottleId;
  final String name;
  final String? size;

  /// False until the bottle has been counted: its level is then unknown (the booking pages treat it as unlimited).
  final bool tracked;
  final int? quantity;
  final int? lowThreshold;
  final bool isLow;
  final bool isSoldOut;
  final DateTime? lastMovedAt;

  String get title => size == null ? name : '$name · $size';
}

StockItem? parseStockItem(Map<String, dynamic> r) {
  final id = opsStr(r, 'bottle_id');
  if (id == null) return null;
  final tracked = opsBool(r, 'tracked');
  return StockItem(
    bottleId: id,
    name: opsStr(r, 'name') ?? 'Bottle',
    size: opsStr(r, 'size'),
    tracked: tracked,
    quantity: tracked && r['quantity'] != null ? opsInt(r, 'quantity') : null,
    lowThreshold: r['low_threshold'] == null ? null : opsInt(r, 'low_threshold'),
    isLow: opsBool(r, 'is_low'),
    isSoldOut: opsBool(r, 'is_sold_out'),
    lastMovedAt: opsTime(r, 'last_moved_at'),
  );
}

int lowStockCount(Iterable<StockItem> items) => items.where((i) => i.isLow).length;

enum StockKind {
  receive('receive', 'Receive', 'How many arrived?', needsReason: false),
  wastage('wastage', 'Wastage', 'How many were lost?', needsReason: true),
  adjust('adjust', 'Adjust', 'Plus or minus how many?', needsReason: true),
  count('count', 'Count', 'How many are there now?', needsReason: false);

  const StockKind(this.id, this.label, this.question, {required this.needsReason});

  final String id;
  final String label;
  final String question;
  final bool needsReason;

  String get reasonQuestion => this == StockKind.wastage ? 'What happened to them?' : 'Why is the level being changed?';
}

/// What was typed for a movement, checked the way the database will check it. Exactly one of [quantity] and [error] is set.
/// [current] is the level now (null when the bottle has not been counted).
({int? quantity, String? error}) checkMovement(StockKind kind, String quantityText, String reason, {int? current}) {
  final text = quantityText.trim().replaceFirst(RegExp(r'^\+'), '');
  final n = int.tryParse(text);
  if (n == null) return (quantity: null, error: kind == StockKind.count ? 'Enter the amount you counted (0 or more).' : 'Enter a whole number.');
  switch (kind) {
    case StockKind.receive:
      if (current == null) return (quantity: null, error: 'Count this bottle first: its level is not known yet.');
      if (n <= 0) return (quantity: null, error: 'Enter how many arrived.');
    case StockKind.wastage:
      if (current == null) return (quantity: null, error: 'Count this bottle first: its level is not known yet.');
      if (n <= 0) return (quantity: null, error: 'Enter how many were lost.');
      if (n > current) return (quantity: null, error: 'Only $current in stock.');
    case StockKind.adjust:
      if (current == null) return (quantity: null, error: 'Count this bottle first: its level is not known yet.');
      if (n == 0) return (quantity: null, error: 'Enter the plus or minus amount.');
      if (current + n < 0) return (quantity: null, error: 'Only $current in stock.');
    case StockKind.count:
      if (n < 0) return (quantity: null, error: 'Enter the amount you counted (0 or more).');
  }
  if (n.abs() > 100000) return (quantity: null, error: 'That is more than can be recorded.');
  if (kind.needsReason) {
    final r = reason.trim();
    if (r.length < 3) return (quantity: null, error: kind == StockKind.wastage ? 'Say what happened to them.' : 'Say why the level is being changed.');
    if (r.length > 200) return (quantity: null, error: 'Keep the reason to 200 characters or fewer.');
  }
  return (quantity: n, error: null);
}

/// A low-stock level: a whole number from 0 up, or empty to clear it. Null level and no error means "clear".
({int? level, bool clear, String? error}) checkThreshold(String text) {
  final t = text.trim();
  if (t.isEmpty) return (level: null, clear: true, error: null);
  final n = int.tryParse(t);
  if (n == null || n < 0 || n > 100000) return (level: null, clear: false, error: 'Enter a whole number from 0 to 100000, or leave it empty to clear it.');
  return (level: n, clear: false, error: null);
}

class MoveOutcome {
  const MoveOutcome({required this.changed, this.before, this.after, this.low = false});

  final bool changed;
  final int? before;
  final int? after;
  final bool low;
}

MoveOutcome parseMoveOutcome(Object? data) {
  final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  return MoveOutcome(
    changed: opsBool(m, 'changed'),
    before: m['before'] == null ? null : opsInt(m, 'before'),
    after: m['after'] == null ? null : opsInt(m, 'after'),
    low: opsBool(m, 'low'),
  );
}

/// The sentence shown after a movement.
String moveOutcomeMessage(StockKind kind, MoveOutcome o, {required String name}) {
  if (!o.changed) return 'Already recorded. Nothing was added twice.';
  final level = o.after == null ? '' : ' $name: ${o.after} in stock.';
  final base = switch (kind) {
    StockKind.receive => 'Delivery recorded.',
    StockKind.wastage => 'Wastage recorded.',
    StockKind.adjust => 'Level adjusted.',
    StockKind.count => 'Count recorded.',
  };
  return '$base$level${o.low ? ' That is low.' : ''}';
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.bottleName,
    required this.kind,
    required this.delta,
    required this.afterQty,
    required this.byName,
    required this.byMe,
    this.bottleId,
    this.size,
    this.beforeQty,
    this.reason,
    this.note,
    this.createdAt,
  });

  final String id;
  final String? bottleId;
  final String bottleName;
  final String? size;
  final String kind;
  final int delta;
  final int? beforeQty;
  final int afterQty;
  final String? reason;
  final String? note;
  final String byName;
  final bool byMe;
  final DateTime? createdAt;

  String get title => size == null ? bottleName : '$bottleName · $size';

  /// "Received 24 (10 → 34)", "Wastage 2 (34 → 32): dropped a case", "Counted 28 (30 → 28)".
  String get sentence {
    final range = beforeQty == null ? '→ $afterQty' : '($beforeQty → $afterQty)';
    final head = switch (kind) {
      'receive' => 'Received $delta',
      'wastage' => 'Wastage ${delta.abs()}',
      'adjust' => delta > 0 ? 'Adjusted +$delta' : 'Adjusted $delta',
      'count' => 'Counted $afterQty',
      _ => kind,
    };
    final tail = reason == null ? '' : ': $reason';
    return kind == 'count' ? '$head ${beforeQty == null ? '(first count)' : range}$tail' : '$head $range$tail';
  }
}

StockMovement? parseMovement(Map<String, dynamic> r) {
  final id = opsStr(r, 'movement_id');
  if (id == null) return null;
  return StockMovement(
    id: id,
    bottleId: opsStr(r, 'bottle_id'),
    bottleName: opsStr(r, 'bottle_name') ?? 'Bottle',
    size: opsStr(r, 'size'),
    kind: opsStr(r, 'kind') ?? 'adjust',
    delta: opsInt(r, 'delta'),
    beforeQty: r['before_qty'] == null ? null : opsInt(r, 'before_qty'),
    afterQty: opsInt(r, 'after_qty'),
    reason: opsStr(r, 'reason'),
    note: opsStr(r, 'note'),
    byName: opsStr(r, 'by_name') ?? 'Staff member',
    byMe: opsBool(r, 'by_me'),
    createdAt: opsTime(r, 'created_at'),
  );
}

/// Between two consecutive movements of the SAME bottle (newest first: [newer], then [older]), the change that did not go through the
/// ledger, almost always bottles ordered: the newer one started from a different level than the older one ended on. Null when they chain.
int? gapBetween(StockMovement newer, StockMovement older) {
  if (newer.bottleId == null || newer.bottleId != older.bottleId) return null;
  final started = newer.beforeQty;
  if (started == null || started == older.afterQty) return null;
  return started - older.afterQty;
}

String gapSentence(int gap) => gap < 0 ? '${-gap} taken outside this list (orders)' : '$gap added outside this list';

String stockTime(DateTime? at) => at == null ? '' : DateFormat('d MMM HH:mm').format(at.toLocal());
