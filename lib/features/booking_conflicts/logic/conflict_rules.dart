import '../../floor/logic/bookings_rules.dart' show formatNight;
import '../../ops/logic/ops_json.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;

// Double-booked tables (website repo, 20261113100000_oversold_booking_queue.sql). A guest pays after their 10-minute hold on a table has run out and the table has gone to someone else: Stripe
// has the money, but the table is not theirs to be promised. The database opens a conflict for the club's manager and the guest is sent no confirmation; the manager moves the booking to
// another table (the booking's own page), refunds it, or finds a table, and then closes the conflict here with a few words. The database checks the facts when it is closed.

/// How a conflict was settled. The words are the database's: `moved`, `refunded`, `kept`.
enum ConflictResolution {
  moved('moved', 'Moved to another table', 'The booking is on a table that is free. Tell the guest.'),
  refunded('refunded', 'Refunded or cancelled', 'The booking was cancelled and the guest is being paid back.'),
  kept('kept', 'The club has a table for them', 'The club found or opened another table, and the booking stays as it is.');

  const ConflictResolution(this.db, this.label, this.hint);

  final String db;
  final String label;
  final String hint;
}

class BookingConflict {
  const BookingConflict({
    required this.conflictId,
    required this.bookingId,
    required this.confirmationCode,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.tableName,
    required this.arrivalDate,
    required this.arrivalTime,
    required this.guestCount,
    required this.amountPaidCents,
    required this.tablesCounted,
    required this.tablesAvailable,
    required this.isOpen,
    required this.resolution,
    required this.resolutionNote,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String conflictId;
  final String bookingId;
  final String? confirmationCode;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String tableName;

  /// The arrival date (yyyy-mm-dd) and time (hh:mm) of the booking.
  final String arrivalDate;
  final String arrivalTime;
  final int guestCount;
  final int amountPaidCents;

  /// What was counted when it was found (paid bookings plus tables held or out of use) against what the club has.
  final int tablesCounted;
  final int tablesAvailable;
  final bool isOpen;
  final ConflictResolution? resolution;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get hasContact => customerEmail != null || customerPhone != null;
}

/// One `desk_booking_conflicts` row. A row with no id, no booking or an unknown state is dropped rather than guessed at: an unknown state must not be shown as "open" or as "settled".
BookingConflict? parseConflict(Map<String, dynamic> r) {
  final id = opsStr(r, 'conflict_id');
  final booking = opsStr(r, 'booking_id');
  final status = opsStr(r, 'status');
  if (id == null || booking == null || (status != 'open' && status != 'resolved')) return null;
  final how = opsStr(r, 'resolution');
  ConflictResolution? resolution;
  for (final c in ConflictResolution.values) {
    if (c.db == how) resolution = c;
  }
  final time = opsStr(r, 'arrival_time') ?? '';
  return BookingConflict(
    conflictId: id,
    bookingId: booking,
    confirmationCode: opsStr(r, 'confirmation_code'),
    customerName: opsStr(r, 'customer_name') ?? 'A guest',
    customerEmail: opsStr(r, 'customer_email'),
    customerPhone: opsStr(r, 'customer_phone'),
    tableName: opsStr(r, 'table_name') ?? 'A table',
    arrivalDate: opsStr(r, 'arrival_date') ?? '',
    arrivalTime: time.length >= 5 ? time.substring(0, 5) : time,
    guestCount: opsInt(r, 'guest_count'),
    amountPaidCents: opsInt(r, 'amount_paid_cents'),
    tablesCounted: opsInt(r, 'tables_counted'),
    tablesAvailable: opsInt(r, 'tables_available'),
    isOpen: status == 'open',
    resolution: resolution,
    resolutionNote: opsStr(r, 'resolution_note'),
    createdAt: opsTime(r, 'created_at'),
    resolvedAt: opsTime(r, 'resolved_at'),
  );
}

/// When and where, in words: "Sat 14 Nov · 21:00 · Gold".
String conflictWhere(BookingConflict c) {
  final date = c.arrivalDate.isEmpty ? null : formatNight(c.arrivalDate);
  return [if (date != null) date, if (c.arrivalTime.isNotEmpty) c.arrivalTime, c.tableName].join(' · ');
}

/// What is wrong, in one sentence a manager can act on.
String conflictSentence(BookingConflict c) {
  final over = '${c.tablesCounted} ${c.tablesCounted == 1 ? 'booking or hold' : 'bookings and holds'} for ${c.tablesAvailable} ${c.tablesAvailable == 1 ? 'table' : 'tables'}';
  return c.isOpen
      ? 'Paid after the table had gone to another guest: $over. No confirmation has been sent to them.'
      : 'Settled: ${c.resolution?.label.toLowerCase() ?? 'dealt with'}.';
}

/// The most the database accepts in the note, and the least.
const int conflictNoteMin = 3;
const int conflictNoteMax = 500;

/// A sentence about what is missing before the conflict can be closed, or null when it can. The database checks the same things, and the facts as well.
String? validateResolution(ConflictResolution? how, String note) {
  if (how == null) return 'Say how it was settled.';
  final t = note.trim();
  if (t.length < conflictNoteMin) return 'Say what was done, in a few words.';
  if (t.length > conflictNoteMax) return 'Keep the note to $conflictNoteMax characters or fewer.';
  return null;
}

Map<String, dynamic> resolveParams(String conflictId, ConflictResolution how, String note) => {
      'p_conflict': conflictId,
      'p_resolution': how.db,
      'p_note': note.trim(),
    };

/// How much the guest paid, for the card.
String paidLine(BookingConflict c) => 'Paid ${formatDollars(c.amountPaidCents)} · ${c.guestCount} ${c.guestCount == 1 ? 'guest' : 'guests'}';
