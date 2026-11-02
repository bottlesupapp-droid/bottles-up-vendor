import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/sales_source/services/sales_source_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The database's sales source functions as a fake, with the rules and sentences of the SQL (website repo, 20261121100000_sales_source.sql, tested there). [role] is who is signed in: 'owner', 'manager',
/// 'verifier', 'server' or 'stranger'.
class FakeSalesBackend {
  FakeSalesBackend({this.role = 'manager'});

  String role;
  String me = 'me';

  /// What the club chose; null until it does (and then the answer is 'entries').
  String? source;

  /// The reports, oldest first. 'by' is who sent it.
  final List<Map<String, dynamic>> reports = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;

  /// What BottlesUp recorded for the night (the server works it out; the fake just answers).
  Map<String, dynamic> recorded = {
    'label': 'Recorded sales',
    'basis': 'What BottlesUp recorded: table bookings, their bottles and the payments taken.',
    'bookings': 3,
    'gross_cents': 63000,
    'discount_cents': 3000,
    'refund_cents': 5000,
    'net_cents': 55000,
    'collected_cents': 42000,
    'unpaid_cents': 20000,
    'as_of': '2026-11-01T22:00:00Z',
  };
  int _ids = 0;

  SalesSourceService get service => SalesSourceService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  bool get _reads => role == 'owner' || role == 'manager' || role == 'verifier';
  bool get _edits => role == 'owner' || role == 'manager';
  bool get _reviews => role == 'owner' || role == 'verifier';

  /// Puts a report in the list as if [by] had sent it.
  Map<String, dynamic> seed({String night = '2026-10-31', int version = 1, String status = 'submitted', int gross = 80000, int discount = 5000, int refund = 0, bool includes = false, String? note, String by = 'someone', String? reviewNote}) {
    final row = {
      'id': 'r${++_ids}',
      'business_night': night,
      'version': version,
      'status': status,
      'period_start': '${night}T20:00:00Z',
      'period_end': '${DateTime.parse(night).add(const Duration(days: 1)).toIso8601String().substring(0, 10)}T04:00:00Z',
      'gross_cents': gross,
      'discount_cents': discount,
      'refund_cents': refund,
      'net_cents': gross - discount - refund,
      'includes_bottlesup': includes,
      'note': note,
      'submitted_at': '2026-11-01T01:00:00Z',
      'reviewed_at': status == 'reviewed' || status == 'rejected' ? '2026-11-01T12:00:00Z' : null,
      'review_note': reviewNote,
      'by': by,
    };
    reports.add(row);
    return row;
  }

  Map<String, dynamic>? _live(String night) {
    for (final r in reports.reversed) {
      if (r['business_night'] == night && r['status'] != 'superseded') return r;
    }
    return null;
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw const SocketLikeException();
    if (missing) throw PostgrestException(message: 'Could not find the function public.$function in the schema cache', code: 'PGRST202');
    final p = params ?? const <String, dynamic>{};
    switch (function) {
      case 'venue_sales_source':
        if (!_reads) throw refuse('not allowed');
        return source ?? 'entries';
      case 'save_venue_sales_source':
        if (!_edits) throw refuse('not allowed');
        final s = p['p_source'];
        if (s == null) throw refuse('choose a sales source');
        if (s == 'pos') throw refuse('Connected POS is not available yet: no point-of-sale provider is connected');
        if (s != 'entries' && s != 'upload') throw refuse('the sales source is BottlesUp entries or a closing report upload');
        source = s as String;
        return s;
      case 'submit_closing_report':
        if (!_edits) throw refuse('not allowed');
        if ((source ?? 'entries') != 'upload') throw refuse('this club does not use closing report uploads: change Sales Tracking first');
        final gross = p['p_gross_cents'] as int?;
        if (gross == null || gross < 0) throw refuse('enter the gross sales for the period');
        final disc = (p['p_discount_cents'] as int?) ?? 0;
        final ref = (p['p_refund_cents'] as int?) ?? 0;
        if (disc < 0 || ref < 0) throw refuse('discounts and refunds cannot be negative');
        if (disc + ref > gross) throw refuse('discounts and refunds cannot be more than the gross sales');
        if (p['p_includes_bottlesup'] == null) throw refuse('say whether the figures include what BottlesUp recorded');
        final night = p['p_night'] as String;
        final prev = _live(night);
        if (prev != null) prev['status'] = 'superseded';
        final row = seed(
          night: night,
          version: (prev == null ? 0 : (prev['version'] as int)) + 1,
          gross: gross,
          discount: disc,
          refund: ref,
          includes: p['p_includes_bottlesup'] as bool,
          note: p['p_note'] as String?,
          by: me,
        );
        return row['id'];
      case 'review_closing_report':
        final r = reports.where((x) => x['id'] == p['p_report']).firstOrNull;
        if (r == null || !_reviews) throw refuse('not allowed');
        if (r['by'] == me) throw refuse('someone else must review a report you sent');
        if (r['status'] == 'superseded') throw refuse('a newer report replaced this one');
        if (r['status'] != 'submitted') throw refuse('this report has already been ${r['status'] == 'reviewed' ? 'accepted' : 'not accepted'}');
        final approve = p['p_approve'] as bool?;
        if (approve == null) throw refuse('accept the report or say why not');
        final note = (p['p_note'] as String?)?.trim();
        if (!approve && (note == null || note.length < 5)) throw refuse('say why the report is not accepted (at least 5 characters)');
        r['status'] = approve ? 'reviewed' : 'rejected';
        r['reviewed_at'] = '2026-11-02T10:00:00Z';
        r['review_note'] = note;
        return r['status'];
      case 'closing_reports':
        if (!_reads) throw refuse('not allowed');
        final rows = [...reports]..sort((a, b) {
            final c = (b['business_night'] as String).compareTo(a['business_night'] as String);
            return c != 0 ? c : (b['version'] as int).compareTo(a['version'] as int);
          });
        return [
          for (final r in rows.take((p['p_limit'] as int?) ?? 30))
            {
              ...r,
              'mine': r['by'] == me,
              'can_review': _reviews && r['status'] == 'submitted' && r['by'] != me,
            }..remove('by'),
        ];
      case 'night_sales_sources':
        if (!_reads) throw refuse('not allowed');
        final r = _live(p['p_night'] as String);
        final net = recorded['net_cents'] as int;
        Map<String, dynamic>? reported;
        if (r != null) {
          final includes = r['includes_bottlesup'] as bool;
          final rnet = r['net_cents'] as int;
          reported = {
            'label': 'Venue-reported sales',
            'basis': 'The club\'s own end-of-night report. It is not live bar sales.',
            'report_id': r['id'],
            'version': r['version'],
            'status': r['status'],
            'period_start': r['period_start'],
            'period_end': r['period_end'],
            'gross_cents': r['gross_cents'],
            'discount_cents': r['discount_cents'],
            'refund_cents': r['refund_cents'],
            'net_cents': rnet,
            'includes_bottlesup': includes,
            'bar_and_other_cents': includes ? (rnet - net < 0 ? 0 : rnet - net) : rnet,
            'smaller_than_recorded': includes && rnet < net,
            'submitted_at': r['submitted_at'],
            'reviewed_at': r['reviewed_at'],
            'verification': switch (r['status']) { 'reviewed' => 'Checked', 'rejected' => 'Not accepted', _ => 'Waiting to be checked' },
          };
        }
        final s = source ?? 'entries';
        return {
          'business_night': p['p_night'],
          'source': s,
          'source_label': s == 'upload' ? 'Closing report upload' : 'BottlesUp entries',
          'recorded': recorded,
          'venue_reported': reported,
        };
    }
    throw StateError('unexpected call $function');
  }
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
