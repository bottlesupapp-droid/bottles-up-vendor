// The owner's venue setup editors: arrival times, table types and the bottle menu (Phase 2 brief, section 2). Pure Dart, tested
// without a screen. A port of the website's src/lib/venueSetupForms.ts: each check mirrors the database function that finally
// decides (save_venue_table_type, save_venue_bottle, add_venue_time_slot in the website repo's 20261010100000_venue_setup.sql),
// so the form says what is wrong in plain words before anything is sent and the database still refuses anything that gets
// past it. Money is typed in dollars and kept in whole cents, by parsing the digits, never with floating point.
//
// Photos are not part of this version: the database changes only the fields that are sent, so editing a table or a bottle here
// never touches a photo it already has.

const List<String> dayLabels = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
const List<String> dayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Monday first is how a week of opening nights is usually read; the stored day numbers stay 0 (Sunday) to 6.
const List<int> dayOrder = [1, 2, 3, 4, 5, 6, 0];

// ---------------------------------------------------------------------------
// Money and numbers
// ---------------------------------------------------------------------------

/// "1,250.50", "$90" or "90.5" as whole cents; null when blank, negative, with more than two decimals, or not a number.
int? parseMoney(String input) {
  final cleaned =
      input.trim().replaceFirst(RegExp(r'^\$'), '').replaceAll(',', '').trim();
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (m == null) return null;
  final dollars = int.parse(m.group(1)!);
  final cents = int.parse(
    (m.group(2) ?? '').padRight(2, '0'),
  ); // "5" is 50 cents, nothing is 00
  return dollars * 100 + cents;
}

/// Cents as the text for an input: "1500.00". Null is an empty box.
String moneyInput(int? cents) =>
    cents == null ? '' : (cents / 100).toStringAsFixed(2);

/// Cents for display: "$1,500.00".
String formatDollars(int cents) {
  final whole = cents ~/ 100;
  final frac = (cents % 100).toString().padLeft(2, '0');
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '\$$grouped.$frac';
}

/// A whole number written in a box ("12"), or null if blank or anything else ("1.5", "1e3", "-2", "12abc").
int? parseWhole(String input) {
  final t = input.trim();
  if (!RegExp(r'^\d{1,9}$').hasMatch(t)) return null;
  return int.parse(t);
}

// ---------------------------------------------------------------------------
// Arrival times
// ---------------------------------------------------------------------------

class ArrivalTime {
  const ArrivalTime({
    required this.slotId,
    required this.dayOfWeek,
    required this.startTime,
    this.label,
    this.bookingCount = 0,
  });

  final String slotId;

  /// 0 is Sunday.
  final int dayOfWeek;

  /// "21:00:00" as the database returns it.
  final String startTime;
  final String? label;
  final int bookingCount;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) =>
    v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);

ArrivalTime? parseArrivalTime(Map<String, dynamic> r) {
  final id = _text(r['slot_id']);
  final day = _int(r['day_of_week']);
  final time = _text(r['start_time']);
  if (id == null || day == null || day < 0 || day > 6 || time == null) {
    return null;
  }
  return ArrivalTime(
    slotId: id,
    dayOfWeek: day,
    startTime: time,
    label: _text(r['label']),
    bookingCount: _int(r['booking_count']) ?? 0,
  );
}

/// "21:00:00" or "21:00" as "9:00 PM". Anything that is not a time is returned as it came.
String formatSlotTime(String time) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
  if (m == null) return time;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return time;
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
}

class DayGroup {
  DayGroup(this.day) : label = dayLabels[day];

  final int day;
  final String label;
  final List<ArrivalTime> times = [];
}

/// Arrival times grouped by day, Monday first, earliest first within a day. Every day is present, as an empty list if need be.
List<DayGroup> groupByDay(List<ArrivalTime> slots) {
  final groups = [for (final d in dayOrder) DayGroup(d)];
  for (final g in groups) {
    g.times
      ..addAll(slots.where((s) => s.dayOfWeek == g.day))
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return groups;
}

List<String> validateSlotForm({
  required List<int> days,
  required String time,
  required String label,
}) {
  final problems = <String>[];
  if (days.isEmpty) problems.add('Choose at least one day.');
  if (days.any((d) => d < 0 || d > 6)) {
    problems.add('Choose days from the list.');
  }
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
    problems.add('Choose an arrival time.');
  }
  if (label.trim().length > 60) {
    problems.add('The note must be 60 characters or fewer.');
  }
  return problems;
}

class SlotAttempt {
  const SlotAttempt(this.day, this.error);

  final int day;

  /// Null when it was added; otherwise why it was not.
  final String? error;
}

class AttemptSummary {
  const AttemptSummary(this.title, {this.description, required this.failed});

  final String title;
  final String? description;
  final bool failed;
}

/// One sentence for a batch of adds: what was added, what already existed, and what failed.
AttemptSummary summarizeSlotAttempts(List<SlotAttempt> attempts) {
  final added = attempts.where((a) => a.error == null).length;
  final already =
      attempts
          .where(
            (a) =>
                a.error != null &&
                RegExp(
                  'already added',
                  caseSensitive: false,
                ).hasMatch(a.error!),
          )
          .toList();
  final failed =
      attempts
          .where(
            (a) =>
                a.error != null &&
                !RegExp(
                  'already added',
                  caseSensitive: false,
                ).hasMatch(a.error!),
          )
          .toList();
  String names(List<SlotAttempt> l) =>
      l.map((a) => dayLabels[a.day]).join(', ');

  if (failed.isNotEmpty) {
    return AttemptSummary(
      added > 0
          ? 'Added $added, but some could not be added'
          : 'Could not add that arrival time',
      description: '${names(failed)}: ${failed.first.error}',
      failed: true,
    );
  }
  if (added == 0) {
    return AttemptSummary(
      'Already added',
      description:
          '${names(already)} already ${already.length == 1 ? 'has' : 'have'} that arrival time.',
      failed: false,
    );
  }
  return AttemptSummary(
    added == 1 ? 'Arrival time added' : '$added arrival times added',
    description:
        already.isNotEmpty ? '${names(already)} already had it.' : null,
    failed: false,
  );
}

// ---------------------------------------------------------------------------
// Table types
// ---------------------------------------------------------------------------

enum PricingMode { flat, hourly }

class TableTypeRow {
  const TableTypeRow({
    required this.typeId,
    required this.name,
    this.description,
    required this.maxGuests,
    this.minGuests,
    required this.minSpendCents,
    required this.depositCents,
    required this.inventoryCount,
    this.badgeLabel,
    required this.isFeatured,
    required this.pricingMode,
    this.hourlyRateCents,
    this.minHours,
    this.floorId,
    this.bookingCount = 0,
  });

  final String typeId;
  final String name;
  final String? description;
  final int maxGuests;
  final int? minGuests;
  final int minSpendCents;
  final int depositCents;
  final int inventoryCount;
  final String? badgeLabel;
  final bool isFeatured;
  final PricingMode pricingMode;
  final int? hourlyRateCents;
  final int? minHours;
  final String? floorId;
  final int bookingCount;
}

TableTypeRow? parseTableType(Map<String, dynamic> r) {
  final id = _text(r['type_id']);
  final name = _text(r['name']);
  final max = _int(r['max_guests']);
  if (id == null || name == null || max == null) return null;
  return TableTypeRow(
    typeId: id,
    name: name,
    description: _text(r['description']),
    maxGuests: max,
    minGuests: _int(r['min_guests']),
    minSpendCents: _int(r['min_spend_cents']) ?? 0,
    depositCents: _int(r['deposit_cents']) ?? 0,
    inventoryCount: _int(r['inventory_count']) ?? 0,
    badgeLabel: _text(r['badge_label']),
    isFeatured: r['is_featured'] == true,
    pricingMode:
        r['pricing_mode'] == 'hourly' ? PricingMode.hourly : PricingMode.flat,
    hourlyRateCents: _int(r['hourly_rate_cents']),
    minHours: _int(r['min_hours']),
    floorId: _text(r['floor_id']),
    bookingCount: _int(r['booking_count']) ?? 0,
  );
}

class TableTypeForm {
  const TableTypeForm({
    this.name = '',
    this.description = '',
    this.maxGuests = '',
    this.minGuests = '',
    this.inventoryCount = '1',
    this.minSpend = '',
    this.deposit = '',
    this.pricingMode = PricingMode.flat,
    this.hourlyRate = '',
    this.minHours = '',
    this.badgeLabel = '',
    this.isFeatured = false,
  });

  final String name;
  final String description;
  final String maxGuests;
  final String minGuests;
  final String inventoryCount;
  final String minSpend;
  final String deposit;
  final PricingMode pricingMode;
  final String hourlyRate;
  final String minHours;
  final String badgeLabel;
  final bool isFeatured;

  TableTypeForm copyWith({
    String? name,
    String? description,
    String? maxGuests,
    String? minGuests,
    String? inventoryCount,
    String? minSpend,
    String? deposit,
    PricingMode? pricingMode,
    String? hourlyRate,
    String? minHours,
    String? badgeLabel,
    bool? isFeatured,
  }) => TableTypeForm(
    name: name ?? this.name,
    description: description ?? this.description,
    maxGuests: maxGuests ?? this.maxGuests,
    minGuests: minGuests ?? this.minGuests,
    inventoryCount: inventoryCount ?? this.inventoryCount,
    minSpend: minSpend ?? this.minSpend,
    deposit: deposit ?? this.deposit,
    pricingMode: pricingMode ?? this.pricingMode,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    minHours: minHours ?? this.minHours,
    badgeLabel: badgeLabel ?? this.badgeLabel,
    isFeatured: isFeatured ?? this.isFeatured,
  );
}

TableTypeForm tableTypeFormFrom(TableTypeRow r) => TableTypeForm(
  name: r.name,
  description: r.description ?? '',
  maxGuests: '${r.maxGuests}',
  minGuests: r.minGuests == null ? '' : '${r.minGuests}',
  inventoryCount: '${r.inventoryCount}',
  minSpend: moneyInput(r.minSpendCents),
  deposit: moneyInput(r.depositCents),
  pricingMode: r.pricingMode,
  hourlyRate: moneyInput(r.hourlyRateCents),
  minHours: r.minHours == null ? '' : '${r.minHours}',
  badgeLabel: r.badgeLabel ?? '',
  isFeatured: r.isFeatured,
);

const int _maxTableMoneyCents = 100000000;
const int _maxBottlePriceCents = 10000000;

/// Plain-language problems with the table type form; an empty list means it can be sent.
List<String> validateTableTypeForm(TableTypeForm f) {
  final p = <String>[];
  if (f.name.trim().isEmpty) {
    p.add('Give the table a name.');
  } else if (f.name.trim().length > 120) {
    p.add('The name must be 120 characters or fewer.');
  }
  if (f.description.trim().length > 2000) {
    p.add('The description must be 2000 characters or fewer.');
  }

  final max = parseWhole(f.maxGuests);
  if (max == null || max < 1 || max > 100) {
    p.add('Maximum guests must be a whole number from 1 to 100.');
  }
  if (f.minGuests.trim().isNotEmpty) {
    final min = parseWhole(f.minGuests);
    if (min == null || min < 1 || min > 100) {
      p.add(
        'Minimum guests must be a whole number from 1 to 100, or left empty.',
      );
    } else if (max != null && min > max) {
      p.add('Minimum guests cannot be more than maximum guests.');
    }
  }
  final count = parseWhole(f.inventoryCount);
  if (count == null || count > 500) {
    p.add('The number of tables must be a whole number from 0 to 500.');
  }

  for (final (label, value) in [
    ('Minimum spend', f.minSpend),
    ('Deposit', f.deposit),
  ]) {
    if (value.trim().isEmpty) continue; // empty means none
    final cents = parseMoney(value);
    if (cents == null) {
      p.add('$label must be an amount like 150 or 150.50.');
    } else if (cents > _maxTableMoneyCents) {
      p.add('$label is too large.');
    }
  }

  if (f.pricingMode == PricingMode.hourly) {
    final rate = parseMoney(f.hourlyRate);
    if (rate == null || rate < 1) {
      p.add('Enter the hourly rate, for example 200.');
    } else if (rate > _maxTableMoneyCents) {
      p.add('The hourly rate is too large.');
    }
    if (f.minHours.trim().isNotEmpty) {
      final hours = parseWhole(f.minHours);
      if (hours == null || hours < 1 || hours > 24) {
        p.add('Minimum hours must be a whole number from 1 to 24.');
      }
    }
  }
  if (f.badgeLabel.trim().length > 40) {
    p.add('The badge must be 40 characters or fewer.');
  }
  return p;
}

/// What is sent for a table type: every field the form shows, and nothing it does not (no photo, no place on a floor plan).
/// Only call this when [validateTableTypeForm] returned nothing.
Map<String, dynamic> tableTypePayload(TableTypeForm f) {
  final hourly = f.pricingMode == PricingMode.hourly;
  return {
    'name': f.name.trim(),
    'description': f.description.trim().isEmpty ? null : f.description.trim(),
    'max_guests': parseWhole(f.maxGuests),
    'min_guests': f.minGuests.trim().isEmpty ? null : parseWhole(f.minGuests),
    'inventory_count': parseWhole(f.inventoryCount),
    'min_spend_cents': f.minSpend.trim().isEmpty ? 0 : parseMoney(f.minSpend),
    'deposit_cents': f.deposit.trim().isEmpty ? 0 : parseMoney(f.deposit),
    'pricing_mode': hourly ? 'hourly' : 'flat',
    'hourly_rate_cents': hourly ? parseMoney(f.hourlyRate) : null,
    'min_hours':
        hourly
            ? (f.minHours.trim().isEmpty ? 1 : parseWhole(f.minHours))
            : null,
    'badge_label': f.badgeLabel.trim().isEmpty ? null : f.badgeLabel.trim(),
    'is_featured': f.isFeatured,
  };
}

/// One line describing what a guest pays: "Min spend $1,500.00 · deposit $500.00".
String describeTablePrice(TableTypeRow r) {
  final parts = <String>[];
  if (r.pricingMode == PricingMode.hourly && r.hourlyRateCents != null) {
    final hours = r.minHours;
    parts.add(
      '${formatDollars(r.hourlyRateCents!)} per hour${hours != null && hours > 1 ? ', $hours hour minimum' : ''}',
    );
  }
  if (r.minSpendCents > 0) {
    parts.add('min spend ${formatDollars(r.minSpendCents)}');
  }
  if (r.depositCents > 0) parts.add('deposit ${formatDollars(r.depositCents)}');
  return parts.isEmpty ? 'No minimum spend or deposit' : parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Bottles
// ---------------------------------------------------------------------------

class BottleRow {
  const BottleRow({
    required this.bottleId,
    required this.name,
    this.size,
    this.description,
    required this.priceCents,
    this.category,
    required this.isAvailable,
    required this.isSoldOut,
    this.stockQuantity,
  });

  final String bottleId;
  final String name;
  final String? size;
  final String? description;
  final int priceCents;
  final String? category;
  final bool isAvailable;
  final bool isSoldOut;
  final int? stockQuantity;
}

BottleRow? parseBottle(Map<String, dynamic> r) {
  final id = _text(r['bottle_id']);
  final name = _text(r['name']);
  final price = _int(r['price_cents']);
  if (id == null || name == null || price == null) return null;
  return BottleRow(
    bottleId: id,
    name: name,
    size: _text(r['size']),
    description: _text(r['description']),
    priceCents: price,
    category: _text(r['category']),
    isAvailable: r['is_available'] != false,
    isSoldOut: r['is_sold_out'] == true,
    stockQuantity: _int(r['stock_quantity']),
  );
}

class BottleForm {
  const BottleForm({
    this.name = '',
    this.size = '',
    this.category = '',
    this.description = '',
    this.price = '',
    this.stock = '',
    this.isAvailable = true,
    this.isSoldOut = false,
  });

  final String name;
  final String size;
  final String category;
  final String description;
  final String price;
  final String stock;
  final bool isAvailable;
  final bool isSoldOut;

  BottleForm copyWith({
    String? name,
    String? size,
    String? category,
    String? description,
    String? price,
    String? stock,
    bool? isAvailable,
    bool? isSoldOut,
  }) => BottleForm(
    name: name ?? this.name,
    size: size ?? this.size,
    category: category ?? this.category,
    description: description ?? this.description,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    isAvailable: isAvailable ?? this.isAvailable,
    isSoldOut: isSoldOut ?? this.isSoldOut,
  );
}

BottleForm bottleFormFrom(BottleRow r) => BottleForm(
  name: r.name,
  size: r.size ?? '',
  category: r.category ?? '',
  description: r.description ?? '',
  price: moneyInput(r.priceCents),
  stock: r.stockQuantity == null ? '' : '${r.stockQuantity}',
  isAvailable: r.isAvailable,
  isSoldOut: r.isSoldOut,
);

List<String> validateBottleForm(BottleForm f) {
  final p = <String>[];
  if (f.name.trim().isEmpty) {
    p.add('Give the bottle a name.');
  } else if (f.name.trim().length > 120) {
    p.add('The name must be 120 characters or fewer.');
  }
  if (f.size.trim().length > 40) {
    p.add('The size must be 40 characters or fewer.');
  }
  if (f.category.trim().length > 40) {
    p.add('The category must be 40 characters or fewer.');
  }
  if (f.description.trim().length > 1000) {
    p.add('The description must be 1000 characters or fewer.');
  }
  final price = parseMoney(f.price);
  if (price == null) {
    p.add('Enter the price as an amount like 195 or 195.50.');
  } else if (price > _maxBottlePriceCents) {
    p.add('The price is too large.');
  }
  if (f.stock.trim().isNotEmpty) {
    final stock = parseWhole(f.stock);
    if (stock == null || stock > 100000) {
      p.add(
        'Stock must be a whole number, or left empty if you do not track it.',
      );
    }
  }
  return p;
}

Map<String, dynamic> bottlePayload(BottleForm f) => {
  'name': f.name.trim(),
  'size': f.size.trim().isEmpty ? null : f.size.trim(),
  'category': f.category.trim().isEmpty ? null : f.category.trim(),
  'description': f.description.trim().isEmpty ? null : f.description.trim(),
  'price_cents': parseMoney(f.price),
  'stock_quantity': f.stock.trim().isEmpty ? null : parseWhole(f.stock),
  'is_available': f.isAvailable,
  'is_sold_out': f.isSoldOut,
};

enum BottleState { offMenu, soldOut, available }

/// What a guest sees for a bottle right now. A bottle that is off the menu is hidden, whatever its sold-out flag says.
BottleState bottleState(BottleRow r) {
  if (!r.isAvailable) return BottleState.offMenu;
  if (r.isSoldOut) return BottleState.soldOut;
  return BottleState.available;
}
