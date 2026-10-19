import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/night_rules.dart';

/// Hands a finished PDF to the phone's share sheet (save to Files, mail, print). Replaced in tests.
typedef ShareReport = Future<void> Function(Uint8List bytes, String fileName);

Future<void> shareReportFile(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf', name: fileName)], subject: fileName);
}

/// The calls to the website's night functions (website repo, 20261018140000_close_night_and_reports.sql). The database decides who may tick
/// the checklist, close or reopen a night and what each role may see of the report; nothing here decides any of it.
class NightService {
  NightService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<ChecklistItem>> checklist(String venueId, String night) =>
      _rpc.list('night_checklist', {'p_venue': venueId, 'p_night': night}, parseChecklistItem, 'the checklist');

  /// Returns whether anything changed (ticking twice changes nothing).
  Future<bool> check(String venueId, String night, String key, bool done) => _rpc.act(() async {
        final data = await _rpc.call('night_check', {'p_venue': venueId, 'p_night': night, 'p_key': key, 'p_done': done});
        return data == true;
      }, generic: 'That could not be saved. Check your connection and try again.');

  Future<CloseStatus> status(String venueId, String night) =>
      _rpc.one('night_close_status', {'p_venue': venueId, 'p_night': night}, parseCloseStatus, 'the state of the night');

  /// Closes the night. With things still open, [acknowledge] must be true and [note] must say why.
  Future<int> close(String venueId, String night, {bool acknowledge = false, String? note}) => _rpc.act(() async {
        final data = await _rpc.call('close_night', {
          'p_venue': venueId,
          'p_night': night,
          'p_acknowledge': acknowledge,
          'p_note': note == null || note.trim().isEmpty ? null : note.trim(),
        });
        return data is Map ? opsIntOf(data['exceptions']) : 0;
      }, generic: 'The night could not be closed. Check your connection and try again.');

  Future<void> reopen(String venueId, String night, String reason) => _rpc.act(() async {
        await _rpc.call('reopen_night', {'p_venue': venueId, 'p_night': night, 'p_reason': reason.trim()});
      }, generic: 'The night could not be reopened. Check your connection and try again.');

  Future<NightReport> report(String venueId, String night) =>
      _rpc.one('night_report', {'p_venue': venueId, 'p_night': night}, parseNightReport, 'the report');
}

int opsIntOf(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
