import '../../ops/logic/ops_json.dart';

// The stock overview (website 20261122110000_stock_overview.sql; brief section 22: "Inventory -> Available / Reserved / Low Stock -> Product", "Show most-sold bottles by selected period").
// Read only. The database counts everything; this file reads what it sends, chooses what each tab lists, and words it. Nothing here changes a stock figure.

/// One bottle of the club with what is on the shelf, what is promised to tables, and what has been handed over.
class StockOverviewItem {
  const StockOverviewItem({
    required this.bottleId,
    required this.name,
    required this.tracked,
    required this.reserved,
    required this.handedOver,
    required this.sold,
    required this.isLow,
    required this.isSoldOut,
    this.size,
    this.category,
    this.onHand,
    this.available,
    this.lowThreshold,
  });

  final String bottleId;
  final String name;
  final String? size;
  final String? category;

  /// False until the bottle has been counted: it then has no on-hand and no available figure (the booking pages treat it as unlimited).
  final bool tracked;
  final int? onHand;

  /// Sold to a table and not handed over yet.
  final int reserved;

  /// Sold to a table and already handed over.
  final int handedOver;

  /// What may still be sold: on hand minus everything sold, never below 0. Null while the bottle has not been counted.
  final int? available;

  /// Sold in the period that was asked for.
  final int sold;
  final int? lowThreshold;
  final bool isLow;
  final bool isSoldOut;

  String get title => size == null ? name : '$name · $size';
}

/// A row of stock_overview, or null for one the app cannot identify (never guessed at).
StockOverviewItem? parseStockOverviewItem(Map<String, dynamic> r) {
  final id = opsStr(r, 'bottle_id');
  if (id == null) return null;
  final tracked = opsBool(r, 'tracked');
  return StockOverviewItem(
    bottleId: id,
    name: opsStr(r, 'name') ?? 'Bottle',
    size: opsStr(r, 'size'),
    category: opsStr(r, 'category'),
    tracked: tracked,
    onHand: tracked && r['on_hand'] != null ? opsInt(r, 'on_hand') : null,
    reserved: opsInt(r, 'reserved'),
    handedOver: opsInt(r, 'handed_over'),
    available: tracked && r['available'] != null ? opsInt(r, 'available') : null,
    sold: opsInt(r, 'sold'),
    lowThreshold: r['low_threshold'] == null ? null : opsInt(r, 'low_threshold'),
    isLow: opsBool(r, 'is_low'),
    isSoldOut: opsBool(r, 'is_sold_out'),
  );
}

/// The three tabs of the brief's path: Available / Reserved / Low Stock.
enum OverviewTab {
  available('Available'),
  reserved('Reserved'),
  low('Low stock');

  const OverviewTab(this.label);

  final String label;

  static OverviewTab byLabel(String label) => values.firstWhere((t) => t.label == label, orElse: () => OverviewTab.available);
}

/// What a tab lists.
/// Available: what may still be sold (a bottle nobody counted has no limit yet, so it is listed; one that is sold out or has none left is not). Most available first, uncounted last.
/// Reserved: what is promised to a table and not handed over yet, most first. Low stock: at or below the level set, fewest first.
List<StockOverviewItem> itemsFor(OverviewTab tab, Iterable<StockOverviewItem> items) {
  final list = switch (tab) {
    OverviewTab.available => [
      for (final i in items)
        if (!i.isSoldOut && (i.available == null || i.available! > 0)) i,
    ],
    OverviewTab.reserved => [
      for (final i in items)
        if (i.reserved > 0) i,
    ],
    OverviewTab.low => [
      for (final i in items)
        if (i.isLow) i,
    ],
  };
  int byName(StockOverviewItem a, StockOverviewItem b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  list.sort(switch (tab) {
    OverviewTab.available =>
      (a, b) =>
          a.available == null && b.available == null
              ? byName(a, b)
              : a.available == null
              ? 1
              : b.available == null
              ? -1
              : (b.available!.compareTo(a.available!) != 0 ? b.available!.compareTo(a.available!) : byName(a, b)),
    OverviewTab.reserved => (a, b) => b.reserved.compareTo(a.reserved) != 0 ? b.reserved.compareTo(a.reserved) : byName(a, b),
    OverviewTab.low => (a, b) => (a.onHand ?? 0).compareTo(b.onHand ?? 0) != 0 ? (a.onHand ?? 0).compareTo(b.onHand ?? 0) : byName(a, b),
  });
  return list;
}

/// The line under a bottle on each tab.
String overviewLine(OverviewTab tab, StockOverviewItem i) {
  switch (tab) {
    case OverviewTab.available:
      if (!i.tracked) return 'Not counted yet. Count it to see how many are left.';
      return '${i.available} available to sell · ${i.onHand} in stock';
    case OverviewTab.reserved:
      return '${i.reserved} reserved, not handed over yet · ${i.handedOver} handed over';
    case OverviewTab.low:
      return '${i.onHand} in stock · low at ${i.lowThreshold}';
  }
}

/// What a tab says when it has nothing to list.
String overviewEmpty(OverviewTab tab) => switch (tab) {
  OverviewTab.available => 'Nothing is available to sell right now.',
  OverviewTab.reserved => 'Nothing is reserved. Every bottle sold to a table has been handed over.',
  OverviewTab.low => 'Nothing is low.',
};

/// The periods the most-sold list can show.
enum SoldPeriod {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90);

  const SoldPeriod(this.label, this.days);

  final String label;
  final int days;

  static SoldPeriod byLabel(String label) => values.firstWhere((p) => p.label == label, orElse: () => SoldPeriod.month);

  DateTime from(DateTime now) => now.subtract(Duration(days: days));
}

/// The most-sold bottles of the period, most first (ties by name), never more than [limit]. A bottle that sold nothing is not listed.
List<StockOverviewItem> mostSold(Iterable<StockOverviewItem> items, {int limit = 5}) {
  final sold = [
    for (final i in items)
      if (i.sold > 0) i,
  ];
  sold.sort((a, b) => b.sold.compareTo(a.sold) != 0 ? b.sold.compareTo(a.sold) : a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return sold.take(limit).toList();
}

String soldLine(StockOverviewItem i, SoldPeriod period) => '${i.sold} sold in the last ${period.label}';

/// The one sentence at the top: how many bottles are reserved in all and how many are low.
String overviewSummary(Iterable<StockOverviewItem> items) {
  final reserved = items.fold<int>(0, (t, i) => t + i.reserved);
  final low = items.where((i) => i.isLow).length;
  final parts = <String>[
    reserved == 0 ? 'Nothing is reserved' : '$reserved ${reserved == 1 ? 'bottle is' : 'bottles are'} reserved for tables',
    low == 0 ? 'nothing is low' : '$low ${low == 1 ? 'bottle is' : 'bottles are'} low',
  ];
  final text = parts.join(', ');
  return '${text[0].toUpperCase()}${text.substring(1)}.';
}
