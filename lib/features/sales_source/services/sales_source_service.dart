import '../../ops/services/ops_rpc.dart';
import '../../owner/services/db_errors.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/sales_source_rules.dart';

/// The calls behind Sales Tracking (website repo, 20261121100000_sales_source.sql). The database decides who may choose a source, send a closing report, check one and read a night's sales.
class SalesSourceService {
  SalesSourceService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  static const _saveFailed = 'That could not be saved. Check your connection and try again.';

  /// Where this club's sales come from. A club that never chose is on BottlesUp entries.
  Future<SalesSource> source(String venueId) async {
    try {
      final data = await _rpc.call('venue_sales_source', {'p_venue': venueId});
      final parsed = parseSalesSource(data);
      if (parsed == null) throw StateError('no source');
      return parsed;
    } catch (error) {
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: 'the sales source');
    }
  }

  Future<void> saveSource(String venueId, SalesSource source) => _rpc.act(() async {
    await _rpc.call('save_venue_sales_source', {'p_venue': venueId, 'p_source': source.wire});
  }, generic: _saveFailed);

  /// The club's closing reports, newest night first.
  Future<List<ClosingReport>> reports(String venueId) => _rpc.list('closing_reports', {'p_venue': venueId, 'p_limit': 30}, parseClosingReport, 'the closing reports');

  /// Sends a closing report. Throws an [OpsActionException] with the database's own sentence when it is refused.
  Future<void> send(String venueId, ClosingReportForm form) => _rpc.act(() async {
    await _rpc.call('submit_closing_report', form.params(venueId));
  }, generic: 'The report could not be sent. Check your connection and try again.');

  /// Accepts or refuses a report. [note] is required to refuse.
  Future<void> review(String reportId, {required bool accept, String? note}) => _rpc.act(() async {
    await _rpc.call('review_closing_report', {'p_report': reportId, 'p_approve': accept, 'p_note': (note ?? '').trim().isEmpty ? null : note!.trim()});
  }, generic: _saveFailed);

  /// A night's sales as two labelled blocks.
  Future<NightSales> nightSales(String venueId, String night) =>
      _rpc.one('night_sales_sources', {'p_venue': venueId, 'p_night': night}, parseNightSales, 'the night\'s sales');
}
