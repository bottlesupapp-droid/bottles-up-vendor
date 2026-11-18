import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/report_email_rules.dart';

/// The calls behind e-mailing a report (website repo, 20261119100000_report_emails.sql and the `send-report-email` function). The database decides who may keep a list, who may
/// send, and which addresses a report goes to: the app never sends an address with a report.
class ReportEmailService {
  ReportEmailService({OpsRpc? rpc, RpcCaller? caller, EdgeInvoker? invoker}) : _rpc = rpc ?? OpsRpc(rpc: caller, invoker: invoker);

  final OpsRpc _rpc;

  static const _saveFailed = 'That could not be saved. Check your connection and try again.';

  Future<List<ReportRecipient>> recipients(ReportListScope scope) => _rpc.list('report_recipients', scope.params, parseReportRecipient, 'the list');

  Future<void> add(ReportListScope scope, String email) => _rpc.act(() async {
    await _rpc.call('add_report_recipient', {...scope.params, 'p_email': email.trim()});
  }, generic: _saveFailed);

  Future<void> remove(String recipientId) => _rpc.act(() async {
    await _rpc.call('remove_report_recipient', {'p_id': recipientId});
  }, generic: _saveFailed);

  /// The switch for sending this list's report automatically when the night is closed, and what the latest automatic send did.
  Future<ReportAutoStatus> autoStatus(ReportListScope scope) => _rpc.one('report_auto_status', scope.params, parseReportAutoStatus, 'the automatic sending settings');

  /// Switches it on or off. The database says no to anyone who may not e-mail this report. Returns the state it is in now.
  Future<bool> setAuto(ReportListScope scope, bool enabled) => _rpc.act(() async {
    final data = await _rpc.call('report_auto_set', {...scope.params, 'p_enabled': enabled});
    return data == true;
  }, generic: _saveFailed);

  /// The latest attempts to e-mail this report, newest first.
  Future<List<ReportDelivery>> deliveries(ReportTarget target) => _rpc.list('report_deliveries', target.deliveryParams, parseReportDelivery, 'the e-mails sent');

  /// Asks the e-mail function to send [pdf] to the list. With [again] only the addresses whose latest attempt failed. Throws an [OpsActionException] with a sentence when it cannot.
  Future<ReportSendResult> send(ReportTarget target, Uint8List pdf, {bool again = false}) async {
    try {
      final data = await _rpc.invoke('send-report-email', {...target.body(again: again), 'pdfBase64': base64Encode(pdf)});
      final parsed = parseSendResult(data);
      if (parsed == null) throw const OpsActionException('The report could not be e-mailed. Try again.');
      return parsed;
    } on OpsActionException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final said = details is Map && details['error'] is String ? details['error'] as String : null;
      throw OpsActionException(
        said ??
            switch (e.status) {
              401 => 'Sign in again to e-mail a report.',
              403 => 'You cannot e-mail this report.',
              429 => 'Too many reports were sent this hour. Try again later.',
              _ => 'The report could not be e-mailed. Check your connection and try again.',
            },
      );
    } catch (_) {
      throw const OpsActionException('The report could not be e-mailed. Check your connection and try again.');
    }
  }
}
