import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/owner_rules.dart';

/// Loading venues or their setup failed. Carries what the screen needs to say, not a stack trace.
class OwnerLoadException implements Exception {
  const OwnerLoadException({required this.unavailable, required this.accessEnded});

  /// The backend has not been given the tenancy or onboarding migrations yet. Nothing the owner can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  String get message => ownerLoadMessage(unavailable: unavailable, accessEnded: accessEnded);

  @override
  String toString() => 'OwnerLoadException($message)';
}

/// An action (adding a venue) was refused or failed; the message is a plain sentence for the person.
class OwnerActionException implements Exception {
  const OwnerActionException(this.message);

  final String message;

  @override
  String toString() => 'OwnerActionException($message)';
}

/// Reads the name, status, slug and address of venues by id. In the app it is a read of `site_venues`, which row level security
/// limits to venues the person can reach; replaced in tests.
typedef VenueRowsLoader = Future<List<Map<String, dynamic>>> Function(List<String> ids);

String _messageOf(Object error) => error is PostgrestException ? error.message : error.toString();

bool _isMissingFunction(Object error) =>
    error is PostgrestException && (error.code == '42883' || error.code == 'PGRST202' || error.code == '42P01');

bool _isNoAccess(Object error) =>
    RegExp(r'not authori[sz]ed|not allowed|access has ended|signed out|not authenticated', caseSensitive: false).hasMatch(_messageOf(error));

/// The owner's calls to the website's database functions: my_venues(), venue_setup_status(p_venue) and create_org_venue(p_org,
/// p_name). They check in the database what this person may see and do; nothing here decides that.
class OwnerService {
  OwnerService({SupabaseClient? client, RpcCaller? rpc, VenueRowsLoader? venueRows})
      : _client = client,
        _rpcOverride = rpc,
        _venueRowsOverride = venueRows;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  final VenueRowsLoader? _venueRowsOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  Future<List<Map<String, dynamic>>> _venueRows(List<String> ids) async {
    final override = _venueRowsOverride;
    if (override != null) return override(ids);
    final data = await _db.from('site_venues').select('id, name, slug, status, address').inFilter('id', ids);
    return List<Map<String, dynamic>>.from(data);
  }

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List ? [for (final r in data) if (r is Map) Map<String, dynamic>.from(r)] : const [];

  OwnerLoadException _loadFailure(Object error) => OwnerLoadException(unavailable: _isMissingFunction(error), accessEnded: _isNoAccess(error));

  /// The venues of one business, with each one's booking-address name and status. A person can hold roles in several businesses,
  /// so only the ones belonging to [orgId] are returned. If the details cannot be read the venues still come back, without a
  /// slug: the booking link then falls back to the venue id, which the public page also accepts.
  Future<List<OrgVenue>> venues(String orgId) async {
    final List<({OrgVenue venue, String orgId})> mine;
    try {
      mine = _rows(await _rpc('my_venues')).map(parseMyVenue).whereType<({OrgVenue venue, String orgId})>().where((r) => r.orgId == orgId).toList();
    } catch (error) {
      throw _loadFailure(error);
    }
    if (mine.isEmpty) return const [];

    Map<String, Map<String, dynamic>> details = {};
    try {
      details = {for (final r in await _venueRows([for (final m in mine) m.venue.id])) '${r['id']}': r};
    } catch (_) {
      // Details are an extra: the list is still true without them.
    }
    return [
      for (final m in mine)
        m.venue.withDetails(
          name: details[m.venue.id]?['name'] is String && (details[m.venue.id]!['name'] as String).isNotEmpty ? details[m.venue.id]!['name'] as String : null,
          status: details[m.venue.id]?['status'] is String ? details[m.venue.id]!['status'] as String : null,
          slug: details[m.venue.id]?['slug'] is String ? details[m.venue.id]!['slug'] as String : null,
          address: details[m.venue.id]?['address'] is String ? details[m.venue.id]!['address'] as String : null,
        ),
    ];
  }

  /// How far one venue is set up, from what really exists (floor plan, tables, bottles...).
  Future<List<SetupStep>> setupStatus(String venueId) async {
    try {
      final rows = _rows(await _rpc('venue_setup_status', params: {'p_venue': venueId}));
      return orderSteps(rows.map(parseSetupStep).whereType<SetupStep>().toList());
    } catch (error) {
      throw _loadFailure(error);
    }
  }

  /// Adds a venue to the business (the database lets only the business's owner do this). Returns the new venue's id.
  Future<String> createVenue(String orgId, String name) async {
    final problem = validateVenueName(name);
    if (problem != null) throw OwnerActionException(problem);
    try {
      final id = await _rpc('create_org_venue', params: {'p_org': orgId, 'p_name': name.trim()});
      if (id is String && id.isNotEmpty) return id;
      throw const OwnerActionException('The venue could not be added. Try again.');
    } on OwnerActionException {
      rethrow;
    } catch (error) {
      if (_isNoAccess(error)) throw const OwnerActionException("You don't have access to do that.");
      throw const OwnerActionException('The venue could not be added. Try again.');
    }
  }
}
