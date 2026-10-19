import 'setup_forms.dart' show TableTypeRow, formatDollars;

// A venue's payment settings (developer brief 15 Oct, section 15). Pure Dart, tested without a screen.
//
// What the owner can change here is how BOTTLES are paid (website: save_venue_payment_rules, 20261020100000_venue_payment_rules.sql). It decides
// what a guest is offered at checkout from then on; a booking that already exists keeps the way it was made. Whether the deposit is credited
// against the bottle bill is shown but not changeable here: the checkout and the reconciliation read the venue's CURRENT value for every booking,
// so changing it would change bookings that already exist ("existing bookings retain their original terms"). The deposit AMOUNT is per table type
// and is edited with the tables.

enum BottlePaymentMode {
  payAhead('pay_ahead', 'Pay ahead', 'Guests pay for the bottles they choose when they book.'),
  payAtVenue('pay_at_club', 'Pay at the venue', 'Guests pay for their bottles at the venue. A required deposit is still paid online.'),
  customerChooses('both', 'Customer chooses', 'Guests choose when they book: pay for bottles now, or at the venue.');

  const BottlePaymentMode(this.db, this.label, this.explanation);

  /// The value the database stores.
  final String db;
  final String label;
  final String explanation;

  /// Null for a value this version of the app does not know: it is then not shown as one of the three.
  static BottlePaymentMode? fromDb(String? value) {
    for (final m in values) {
      if (m.db == value) return m;
    }
    return null;
  }
}

class PaymentRules {
  const PaymentRules({required this.mode, required this.depositIsCredit});

  /// Null when the database holds a value this app does not know. Nothing is pre-selected then.
  final BottlePaymentMode? mode;

  /// The deposit is credited against the bottle bill (a minimum-spend credit). Read only here.
  final bool depositIsCredit;
}

/// One row of venue_payment_rules().
PaymentRules? parsePaymentRules(Map<String, dynamic> row) {
  if (!row.containsKey('bottle_payment_mode')) return null;
  return PaymentRules(mode: BottlePaymentMode.fromDb(row['bottle_payment_mode']?.toString()), depositIsCredit: row['deposit_is_credit'] == true);
}

const String depositCreditNote =
    'Whether the deposit counts toward the bottle bill is set by the BottlesUp team. Bookings that already exist are worked out with the current setting, so it is not changed from here. Ask the team if you need it changed.';

String depositCreditLabel(bool credited) => credited
    ? 'The deposit is credited toward the bottle bill (a minimum-spend credit).'
    : 'The deposit is a separate charge and is not credited toward the bottle bill.';

/// What each table asks as a deposit, in words: "Booth: $100.00 deposit, paid online" or "Sofa: no deposit".
String depositLine(TableTypeRow t) => t.depositCents > 0 ? '${t.name}: ${formatDollars(t.depositCents)} deposit, paid online' : '${t.name}: no deposit';

/// Whether choosing [picked] would change anything. The Save button is offered only then.
bool paymentChanged(PaymentRules? saved, BottlePaymentMode? picked) => picked != null && saved?.mode != picked;

const String payoutNote = 'Payout setup (bank details, what is owed and paid out) is not available yet. It waits for the payout terms to be agreed.';

const String atVenueNote = 'Paying at the venue: your staff record each payment on the booking (cash, the venue\'s terminal, or a BottlesUp payment) with a receipt, and a manager checks it.';
