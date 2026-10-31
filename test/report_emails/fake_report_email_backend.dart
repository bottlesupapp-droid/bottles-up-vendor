import 'dart:convert';

import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/report_emails/services/report_email_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The database's report e-mail functions and the e-mail function, as a fake, with the rules and sentences of the SQL and the TypeScript (website repo, 20261119100000_report_emails.sql and
/// supabase/functions/send-report-email, both tested there). [role] is who is signed in: 'owner', 'manager', 'organizer' or 'stranger'.
class FakeReportEmailBackend {
  FakeReportEmailBackend({this.role = 'owner'});

  String role;

  /// The lists, keyed "kind|org|venue".
  final Map<String, List<({String id, String email})>> lists = {};

  /// The log, oldest first.
  final List<({String email, String status, String? error, DateTime at, String ref})> log = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  final List<({String name, Map<String, dynamic> body})> sends = [];
  bool offline = false;
  bool missing = false;

  /// Addresses the e-mail provider refuses.
  final Set<String> failFor = {};
  int _ids = 0;
  DateTime _now = DateTime.utc(2026, 10, 30, 22, 0);

  ReportEmailService get service => ReportEmailService(rpc: OpsRpc(rpc: call, invoker: invoke));

  String _key(Map<String, dynamic> p) => '${p['p_kind']}|${p['p_org']}|${p['p_venue'] ?? ''}';

  bool _may(String kind) => switch (kind) {
        'owner_combined' => role == 'owner',
        'venue_night' => role == 'owner' || role == 'manager',
        'organizer_sales' => role == 'organizer',
        _ => false,
      };

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  void seed(String kind, String org, String? venue, List<String> emails) {
    lists['$kind|$org|${venue ?? ''}'] = [for (final e in emails) (id: 'r${++_ids}', email: e)];
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw const SocketLikeException();
    if (missing) throw PostgrestException(message: 'Could not find the function public.$function in the schema cache', code: 'PGRST202');
    final p = params ?? const <String, dynamic>{};
    switch (function) {
      case 'report_recipients':
        if (!_may(p['p_kind'] as String)) throw refuse('not allowed');
        return [
          for (final r in (lists[_key(p)] ?? const []))
            {'id': r.id, 'email': r.email, 'added_at': '2026-10-30T20:00:00Z'},
        ];
      case 'add_report_recipient':
        if (!_may(p['p_kind'] as String)) throw refuse('not allowed');
        final email = ((p['p_email'] as String?) ?? '').trim().toLowerCase();
        if (email.length > 254 || !RegExp(r'^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$').hasMatch(email)) throw refuse('enter one e-mail address, like name@company.com');
        final list = lists.putIfAbsent(_key(p), () => []);
        if (list.any((r) => r.email == email)) throw refuse('that address is already on the list');
        if (list.length >= 10) throw refuse('a list can hold at most 10 addresses: remove one first');
        final id = 'r${++_ids}';
        list.add((id: id, email: email));
        return id;
      case 'remove_report_recipient':
        for (final entry in lists.entries) {
          final i = entry.value.indexWhere((r) => r.id == p['p_id']);
          if (i >= 0) {
            if (!_may(entry.key.split('|').first)) throw refuse('not allowed');
            entry.value.removeAt(i);
            return null;
          }
        }
        throw refuse('not allowed');
      case 'report_deliveries':
        if (!_may(p['p_kind'] as String)) throw refuse('not allowed');
        final rows = log.where((d) => d.ref == p['p_ref']).toList().reversed.take(p['p_limit'] as int);
        return [
          for (final d in rows) {'email': d.email, 'status': d.status, 'error': d.error, 'sent_at': d.status == 'pending' ? null : d.at.toIso8601String(), 'created_at': d.at.toIso8601String()},
        ];
    }
    throw StateError('unexpected call $function');
  }

  /// The e-mail function. A refusal is a [FunctionException] with the sentence it answers.
  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    sends.add((name: name, body: body));
    if (offline) throw const SocketLikeException();
    final kind = body['kind'] as String;
    if (!_may(kind)) throw const FunctionException(status: 403, details: {'error': 'You cannot e-mail this report.'});
    final pdf = base64Decode(body['pdfBase64'] as String);
    if (pdf.length < 5 || String.fromCharCodes(pdf.take(5)) != '%PDF-') throw const FunctionException(status: 400, details: {'error': 'That is not a PDF.'});
    final key = '$kind|${body['orgId']}|${body['venueId'] ?? ''}';
    var addresses = [for (final r in (lists[key] ?? const [])) r.email];
    if (addresses.isEmpty) throw const FunctionException(status: 409, details: {'error': 'No one is set to receive this report. Add an e-mail address first.'});
    final ref = body['ref'] as String;
    if (body['again'] == true) {
      final latest = <String, String>{};
      for (final d in log.where((d) => d.ref == ref)) {
        latest[d.email] = d.status;
      }
      addresses = [for (final a in addresses) if (latest[a] == 'failed') a];
      if (addresses.isEmpty) throw const FunctionException(status: 409, details: {'error': 'There is nothing to send again: every address already got this report.'});
    }
    final results = <Map<String, dynamic>>[];
    var sent = 0;
    for (final a in addresses) {
      _now = _now.add(const Duration(seconds: 1));
      final ok = !failFor.contains(a);
      log.add((email: a, status: ok ? 'sent' : 'failed', error: ok ? null : 'the e-mail provider did not accept the message', at: _now, ref: ref));
      if (ok) sent++;
      results.add({'email': a, 'ok': ok});
    }
    return {'sent': sent, 'failed': addresses.length - sent, 'results': results};
  }
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
