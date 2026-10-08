// The manager's Floor screen (Phase 2 brief, section 2: Manager "Floor"): the reservations of the manager's club, night by
// night. Pure Dart, tested without a screen. It is a port of the website's src/lib/bookingsView.ts and the database function
// list_venue_bookings (20261011100000_venue_bookings.sql in the website repo): which nights to look at, how a stored status
// reads, how a night's bookings are grouped and counted. The database decides who may see a venue's bookings and which night
// each one belongs to; nothing here grants access.

// ---------------------------------------------------------------------------
// The business night
// ---------------------------------------------------------------------------

/// A venue's night runs past midnight: a table booked for 1:00 AM is Saturday night's party but is stored with Sunday's date.
/// Any slot starting before this time belongs to the previous night. The same rule as the website, the edge functions and
/// the database function; a test compares it with the SQL when the website repo is checked out beside this app.
const String afterMidnightCutoff = '06:00:00';

String _pad(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}';

/// The business night (yyyy-mm-dd) a local moment belongs to: before 06:00 it is still the previous night.
String currentNight(DateTime now) {
  final time = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  final today = isoDate(now);
  // Calendar arithmetic, not "minus 24 hours": on the night clocks change a local day is 23 or 25 hours long.
  return time.compareTo(afterMidnightCutoff) < 0 ? addDays(today, -1) : today;
}

// ---------------------------------------------------------------------------
// A booking and its status
// ---------------------------------------------------------------------------

class BookingRow {
  const BookingRow({
    required this.bookingId,
    required this.nightDate,
    required this.startTime,
    this.slotLabel,
    required this.tableName,
    required this.guestCount,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.status,
    this.confirmationCode,
    this.checkedInAt,
    required this.amountTotalCents,
    required this.depositCents,
    required this.currency,
  });

  final String bookingId;

  /// The business night, not the calendar date it is stored under.
  final String nightDate;

  /// "21:00:00".
  final String startTime;
  final String? slotLabel;
  final String tableName;
  final int guestCount;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;

  /// As stored: paid, pending, failed, refunded, cancelled.
  final String status;
  final String? confirmationCode;
  final DateTime? checkedInAt;
  final int amountTotalCents;
  final int depositCents;
  final String currency;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;
int _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : 0);

/// One list_venue_bookings row. A row without an id or a night is dropped rather than guessed.
BookingRow? parseBookingRow(Map<String, dynamic> r) {
  final id = r['booking_id'];
  final night = r['night_date'];
  if (id is! String || night is! String || _parseIso(night) == null) return null;
  return BookingRow(
    bookingId: id,
    nightDate: night,
    startTime: _text(r['start_time']) ?? '',
    slotLabel: _text(r['slot_label']),
    tableName: _text(r['table_name']) ?? '',
    guestCount: _int(r['guest_count']),
    customerName: _text(r['customer_name']) ?? '',
    customerEmail: _text(r['customer_email']) ?? '',
    customerPhone: _text(r['customer_phone']),
    status: _text(r['status']) ?? '',
    confirmationCode: _text(r['confirmation_code']),
    checkedInAt: r['checked_in_at'] is String ? DateTime.tryParse(r['checked_in_at'] as String) : null,
    amountTotalCents: _int(r['amount_total_cents']),
    depositCents: _int(r['deposit_cents']),
    currency: _text(r['currency']) ?? 'cad',
  );
}

enum StatusTone { good, wait, bad, neutral }

class StatusInfo {
  const StatusInfo(this.label, this.tone, {required this.confirmed});

  final String label;
  final StatusTone tone;

  /// Counts as a booking the venue should expect: paid, and not cancelled or refunded.
  final bool confirmed;
}

/// What a stored status means to a venue. A status this code has not seen is shown as it is, never as confirmed.
StatusInfo statusInfo(String status) {
  switch (status) {
    case 'paid':
      return const StatusInfo('Confirmed', StatusTone.good, confirmed: true);
    case 'pending':
      return const StatusInfo('Awaiting payment', StatusTone.wait, confirmed: false);
    case 'failed':
      return const StatusInfo('Payment failed', StatusTone.bad, confirmed: false);
    case 'refunded':
      return const StatusInfo('Refunded', StatusTone.neutral, confirmed: false);
    case 'cancelled':
      return const StatusInfo('Cancelled', StatusTone.neutral, confirmed: false);
    default:
      final label = status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1);
      return StatusInfo(label, StatusTone.neutral, confirmed: false);
  }
}

enum BookingFilter { confirmed, all }

List<BookingRow> applyFilter(List<BookingRow> rows, BookingFilter filter) =>
    filter == BookingFilter.all ? List.of(rows) : rows.where((r) => statusInfo(r.status).confirmed).toList();

// ---------------------------------------------------------------------------
// Grouping and counting
// ---------------------------------------------------------------------------

const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Saturday Oct 10". A date this cannot read is returned as it came.
String formatNight(String iso) {
  final d = _parseIso(iso);
  if (d == null) return iso;
  return '${_weekdays[d.weekday - 1]} ${_months[d.month - 1]} ${d.day}';
}

/// "Sat Oct 10": the short form, for a button too narrow for the whole name.
String formatNightShort(String iso) {
  final d = _parseIso(iso);
  if (d == null) return iso;
  return '${_weekdays[d.weekday - 1].substring(0, 3)} ${_months[d.month - 1]} ${d.day}';
}

/// "21:00:00" or "21:00" as "9:00 PM". Anything that is not a time is returned as it came.
String formatTimeSlot(String startTime) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(startTime);
  if (m == null) return startTime;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return startTime;
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${_pad(min)} ${h < 12 ? 'AM' : 'PM'}';
}

/// A phone number as a phone can dial it: digits, and a leading "+" for an international number. "+1 (555) 010-0100" becomes
/// "+15550100100". Null when there are too few digits to be a number, so a stray "-" never becomes a call link.
String? dialable(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 5) return null;
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// "$1,200.00 CAD" is how the website writes it; the same here so the two never disagree.
String formatMoney(int cents, String currency) => '\$${(cents / 100).toStringAsFixed(2)} ${currency.toUpperCase()}';

class NightGroup {
  NightGroup(this.night) : label = formatNight(night);

  final String night;
  final String label;
  final List<BookingRow> rows = [];

  /// Guests in the confirmed bookings of this night.
  int guests = 0;
}

/// Rows grouped by night, in the order they arrive (the database already sorts them).
List<NightGroup> groupByNight(List<BookingRow> rows) {
  final groups = <NightGroup>[];
  for (final row in rows) {
    var group = groups.where((g) => g.night == row.nightDate).firstOrNull;
    if (group == null) {
      group = NightGroup(row.nightDate);
      groups.add(group);
    }
    group.rows.add(row);
    if (statusInfo(row.status).confirmed) group.guests += row.guestCount;
  }
  return groups;
}

class Summary {
  const Summary({required this.bookings, required this.guests, required this.checkedIn, required this.awaitingPayment});

  /// Confirmed bookings.
  final int bookings;

  /// Guests across the confirmed bookings.
  final int guests;

  /// Confirmed bookings whose guests have already arrived.
  final int checkedIn;

  /// Started but not paid. These may be abandoned checkouts, so they are not counted as bookings.
  final int awaitingPayment;
}

Summary summarize(List<BookingRow> rows) {
  var bookings = 0, guests = 0, checkedIn = 0, awaiting = 0;
  for (final r in rows) {
    if (statusInfo(r.status).confirmed) {
      bookings++;
      guests += r.guestCount;
      if (r.checkedInAt != null) checkedIn++;
    } else if (r.status == 'pending') {
      awaiting++;
    }
  }
  return Summary(bookings: bookings, guests: guests, checkedIn: checkedIn, awaitingPayment: awaiting);
}

// ---------------------------------------------------------------------------
// Which nights
// ---------------------------------------------------------------------------

/// The most nights the database answers for at once, and the most rows it returns. Reaching the row limit means there may be more.
const int maxNights = 93;
const int rowLimit = 1000;

class NightRange {
  const NightRange(this.from, this.to);

  final String from;
  final String to;

  @override
  bool operator ==(Object other) => other is NightRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from..$to';
}

DateTime? _parseIso(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  // DateTime rolls 2026-02-30 into March; a real date survives the round trip.
  return dt.year == y && dt.month == mo && dt.day == d ? dt : null;
}

String addDays(String iso, int days) {
  final d = _parseIso(iso);
  if (d == null) throw ArgumentError('not a date: $iso');
  return isoDate(d.add(Duration(days: days)));
}

/// Number of nights from `from` to `to`, both included. Zero when either is not a date.
int nightCount(NightRange range) {
  final a = _parseIso(range.from), b = _parseIso(range.to);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays + 1;
}

/// A sentence about what is wrong with the range, or null when it can be asked for.
String? validateRange(NightRange range) {
  if (_parseIso(range.from) == null || _parseIso(range.to) == null) return 'Choose a start and an end date.';
  if (range.to.compareTo(range.from) < 0) return 'The end date is before the start date.';
  if (nightCount(range) > maxNights) return 'Choose at most $maxNights nights at a time.';
  return null;
}

DateTime? parseNight(String iso) => _parseIso(iso);

enum PresetId { tonight, next7, next30, last7 }

class Preset {
  const Preset(this.id, this.label, this.range);

  final PresetId id;
  final String label;
  final NightRange range;
}

/// Ready-made ranges, counted in business nights: before 06:00 it is still the previous night.
List<Preset> presets(DateTime now) {
  final tonight = currentNight(now);
  return [
    Preset(PresetId.tonight, 'Tonight', NightRange(tonight, tonight)),
    Preset(PresetId.next7, 'Next 7 nights', NightRange(tonight, addDays(tonight, 6))),
    Preset(PresetId.next30, 'Next 30 nights', NightRange(tonight, addDays(tonight, 29))),
    Preset(PresetId.last7, 'Last 7 nights', NightRange(addDays(tonight, -7), addDays(tonight, -1))),
  ];
}

// ---------------------------------------------------------------------------
// Wording for a failed load
// ---------------------------------------------------------------------------

String floorLoadMessage({required bool unavailable, required bool accessEnded}) {
  if (unavailable) return 'Bookings are not set up on this server yet.';
  if (accessEnded) return 'Your access has ended, or you are signed out.';
  return 'Bookings could not be loaded. Check your connection and try again.';
}
