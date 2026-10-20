import '../../owner/logic/setup_forms.dart' show formatDollars;

// What BottlesUp pays out to a venue's business or an organizer, as that business sees it (developer brief 15 Oct 2026, sections 20 and 31; the client's answers of 20 Oct and the
// owner's decision that BottlesUp controls the payout account, its percentage and the weekday in the CMS). Pure Dart, tested without a screen. Everything here is READ ONLY: the app
// collects no bank details and records no payout; BottlesUp checks the account, makes the transfer and records it with a reference (website repo,
// 20261025100000_payout_settings_and_ledger.sql, my_payouts).

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
String? _text(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

enum PayoutAccountStatus {
  incomplete('incomplete', 'Not set up yet', 'BottlesUp has not finished checking your payout details. Nothing can be paid out until they are.'),
  underReview('under_review', 'Under review', 'BottlesUp is checking your payout details.'),
  ready('ready', 'Ready', 'Your payout account is ready to receive payments.'),
  actionRequired('action_required', 'Action needed', 'BottlesUp needs something from you before it can pay out.');

  const PayoutAccountStatus(this.db, this.label, this.explanation);

  final String db;
  final String label;
  final String explanation;

  static PayoutAccountStatus? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }
}

enum PayoutItemStatus {
  pending('pending', 'Being prepared'),
  processing('processing', 'On its way'),
  paid('paid', 'Paid'),
  failed('failed', 'Did not go through');

  const PayoutItemStatus(this.db, this.label);

  final String db;
  final String label;

  static PayoutItemStatus? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }
}

class PayoutAccount {
  const PayoutAccount({required this.status, this.holder, this.maskedAccount, this.note});

  final PayoutAccountStatus status;
  final String? holder;

  /// Only ever a masked account ("•••• 1234"); the database refuses a full number.
  final String? maskedAccount;

  /// What BottlesUp needs done, in its words.
  final String? note;
}

class PayoutSettings {
  const PayoutSettings({required this.method, required this.commissionSet, this.commissionBps, required this.weekday, required this.holdDays, this.nextPayoutOn, required this.ownArrangement});

  final String method;

  /// BottlesUp has chosen its percentage. Until it has, none is shown.
  final bool commissionSet;
  final int? commissionBps;

  /// 0 Sunday ... 6 Saturday.
  final int weekday;
  final int holdDays;
  final String? nextPayoutOn;

  /// This business has its own arrangement instead of the standard one.
  final bool ownArrangement;
}

class PayoutWaiting {
  const PayoutWaiting({required this.bookings, required this.grossCents});

  final int bookings;
  final int grossCents;
}

class PayoutItem {
  const PayoutItem({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.grossCents,
    required this.commissionCents,
    required this.adjustmentCents,
    this.adjustmentNote,
    required this.netCents,
    required this.status,
    this.expectedOn,
    this.reference,
    this.paidAt,
    this.failureNote,
  });

  final String id;
  final String periodStart;
  final String periodEnd;
  final int grossCents;
  final int commissionCents;
  final int adjustmentCents;
  final String? adjustmentNote;
  final int netCents;
  final PayoutItemStatus status;
  final String? expectedOn;
  final String? reference;
  final DateTime? paidAt;
  final String? failureNote;
}

/// What `my_payouts` answers for a business.
class MyPayouts {
  const MyPayouts({required this.isVenueBusiness, required this.account, required this.settings, this.waiting, required this.items});

  /// The business runs venues (table money). An organizer's ticket earnings are not part of this yet.
  final bool isVenueBusiness;
  final PayoutAccount account;
  final PayoutSettings settings;
  final PayoutWaiting? waiting;
  final List<PayoutItem> items;
}

PayoutItem? parsePayoutItem(Map<String, dynamic> r) {
  final id = _text(r['id']);
  final start = _text(r['period_start']);
  final end = _text(r['period_end']);
  final gross = _int(r['gross_cents']);
  final commission = _int(r['commission_cents']);
  final net = _int(r['net_cents']);
  final status = PayoutItemStatus.fromDb(_text(r['status']));
  if (id == null || start == null || end == null || gross == null || commission == null || net == null || status == null) return null;
  final paid = _text(r['paid_at']);
  return PayoutItem(
    id: id,
    periodStart: start,
    periodEnd: end,
    grossCents: gross,
    commissionCents: commission,
    adjustmentCents: _int(r['adjustments_cents']) ?? 0,
    adjustmentNote: _text(r['adjustment_note']),
    netCents: net,
    status: status,
    expectedOn: _text(r['expected_on']),
    reference: _text(r['reference']),
    paidAt: paid == null ? null : DateTime.tryParse(paid)?.toLocal(),
    failureNote: _text(r['failure_note']),
  );
}

MyPayouts? parseMyPayouts(dynamic data) {
  if (data is! Map) return null;
  final r = Map<String, dynamic>.from(data);
  final account = r['account'];
  final settings = r['settings'];
  if (account is! Map || settings is! Map) return null;
  final status = PayoutAccountStatus.fromDb(_text(account['status']));
  final weekday = _int(settings['payout_weekday']);
  final hold = _int(settings['hold_days']);
  if (status == null || weekday == null || weekday < 0 || weekday > 6 || hold == null) return null;
  final waiting = r['waiting'];
  final items = r['items'];
  return MyPayouts(
    isVenueBusiness: r['org_kind'] == 'venue_owner',
    account: PayoutAccount(status: status, holder: _text(account['account_holder']), maskedAccount: _text(account['masked_account']), note: _text(account['note'])),
    settings: PayoutSettings(
      method: _text(settings['payout_method']) ?? 'manual_transfer',
      commissionSet: settings['commission_set'] == true,
      commissionBps: _int(settings['commission_bps']),
      weekday: weekday,
      holdDays: hold,
      nextPayoutOn: _text(settings['next_payout_on']),
      ownArrangement: settings['own_arrangement'] == true,
    ),
    waiting: waiting is Map ? PayoutWaiting(bookings: _int(waiting['bookings']) ?? 0, grossCents: _int(waiting['gross_cents']) ?? 0) : null,
    items: items is List ? [for (final i in items) if (i is Map) parsePayoutItem(Map<String, dynamic>.from(i))].whereType<PayoutItem>().toList() : const [],
  );
}

const List<String> weekdayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// 1250 basis points = "12.5%", 1000 = "10%", 0 = "0%".
String percentFromBps(int bps) {
  final whole = bps ~/ 100;
  final frac = bps % 100;
  if (frac == 0) return '$whole%';
  final f = frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '');
  return '$whole.$f%';
}

/// "Friday 24 October 2026" for an ISO date. A date this cannot read is returned as it came.
String payoutDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12) return iso;
  final wd = DateTime.utc(y, mo, d).weekday % 7;
  return '${weekdayNames[wd]} $d ${months[mo - 1]} $y';
}

/// The arrangement in words: when, how long the money waits and BottlesUp's share.
List<String> settingsLines(PayoutSettings s) => [
      'BottlesUp pays out every ${weekdayNames[s.weekday]}, by bank transfer.',
      s.holdDays == 0 ? 'Money is included as soon as the night is over.' : 'Money waits ${s.holdDays} ${s.holdDays == 1 ? 'day' : 'days'} after the night before it is included.',
      s.commissionSet && s.commissionBps != null ? 'BottlesUp keeps ${percentFromBps(s.commissionBps!)} of what it pays out.' : 'BottlesUp has not set its percentage yet.',
      if (s.ownArrangement) 'This is an arrangement made for your business.',
    ];

String waitingLine(PayoutWaiting w) => w.bookings == 0
    ? 'Nothing is waiting for the next payout.'
    : '${w.bookings} ${w.bookings == 1 ? 'booking' : 'bookings'} with ${formatDollars(w.grossCents)} collected online ${w.bookings == 1 ? 'is' : 'are'} waiting for the next payout. This is an estimate, before BottlesUp\'s percentage.';

const String clubCashNote = 'Money you collect at the club (cash, or your own card machine) is recorded by your staff and is never paid to you again by BottlesUp.';

/// One payout in a sentence for the list.
String itemHeadline(PayoutItem i) => '${payoutDate(i.periodStart)} to ${payoutDate(i.periodEnd)}';

String itemMoneyLine(PayoutItem i) {
  final parts = [
    '${formatDollars(i.grossCents)} collected',
    '${formatDollars(i.commissionCents)} BottlesUp',
    if (i.adjustmentCents != 0) '${i.adjustmentCents > 0 ? '+' : '-'}${formatDollars(i.adjustmentCents.abs())} adjustment',
  ];
  return parts.join(' · ');
}

String itemStatusLine(PayoutItem i) => switch (i.status) {
      PayoutItemStatus.pending => i.expectedOn == null ? 'Being prepared' : 'Being prepared: expected ${payoutDate(i.expectedOn!)}',
      PayoutItemStatus.processing => i.expectedOn == null ? 'On its way' : 'On its way: expected ${payoutDate(i.expectedOn!)}',
      PayoutItemStatus.paid => 'Paid${i.paidAt == null ? '' : ' on ${payoutDate(i.paidAt!.toIso8601String())}'}${i.reference == null ? '' : ' · reference ${i.reference}'}',
      PayoutItemStatus.failed => 'Did not go through${i.failureNote == null ? '' : ': ${i.failureNote}'}. BottlesUp will be in touch.',
    };

/// What an organizer is told: their ticket earnings are not part of payouts yet.
const String organizerNote = 'Ticket earnings are not paid out from here yet. When settlements are ready they will appear in this list.';
