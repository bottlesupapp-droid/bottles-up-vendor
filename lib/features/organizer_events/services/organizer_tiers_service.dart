import 'package:supabase_flutter/supabase_flutter.dart';

import '../../owner/services/db_errors.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/event_tickets_rules.dart';
import '../logic/organizer_events_rules.dart';
import 'organizer_events_service.dart';

/// The organizer's calls to the website's `list_org_tiers`, `save_org_tier` and `remove_org_tier` (website repo, 20261128100000_organizer_tickets.sql).
/// Each checks in the database that the signed-in person is the organizer of THIS business and that the event is theirs, and enforces every rule
/// (a sold type's price, the sale window, the event having ended). Nothing here decides who may do what. A failure to load is an
/// [OrganizerEventsLoadException] and a refused or failed save or removal an [OrganizerEventsActionException] with a plain sentence.
class OrganizerTiersService {
  OrganizerTiersService({SupabaseClient? client, RpcCaller? rpc})
    : _client = client,
      _rpcOverride = rpc;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  Future<T> _act<T>(Future<T> Function() call, String generic) async {
    try {
      return await call();
    } on OrganizerEventsActionException {
      rethrow;
    } catch (error) {
      if (isMissingFunction(error)) {
        throw const OrganizerEventsActionException(
          'Tickets are not set up on this server yet. Try again later.',
        );
      }
      throw OrganizerEventsActionException(
        sentence(actionMessage(error, generic: generic)),
      );
    }
  }

  Future<List<OrgTier>> tiers(String orgId, String eventId) async {
    try {
      final data = await _rpc(
        'list_org_tiers',
        params: {'p_org': orgId, 'p_event': eventId},
      );
      if (data is! List) return const [];
      return [
        for (final r in data)
          if (r is Map) ...[
            if (parseOrgTier(Map<String, dynamic>.from(r)) case final t?) t,
          ],
      ];
    } catch (error) {
      throw OrganizerEventsLoadException(
        unavailable: isMissingFunction(error),
        accessEnded: isNoAccess(error),
      );
    }
  }

  /// tierId null adds a ticket type; otherwise changes that one. Returns the type's id.
  Future<String> save(
    String orgId,
    String eventId,
    String? tierId,
    Map<String, dynamic> details,
  ) => _act(() async {
    final id = await _rpc(
      'save_org_tier',
      params: {
        'p_org': orgId,
        'p_event': eventId,
        'p_tier': tierId,
        'p_details': details,
      },
    );
    if (id is String && id.isNotEmpty) return id;
    throw const OrganizerEventsActionException(
      'The ticket type could not be saved. Try again.',
    );
  }, 'This could not be saved. Check your connection and try again.');

  Future<void> remove(String orgId, String tierId) => _act(
    () async => await _rpc(
      'remove_org_tier',
      params: {'p_org': orgId, 'p_tier': tierId},
    ),
    'This could not be removed. Try again.',
  );
}

class TierSubmitResult {
  const TierSubmitResult({required this.ok, this.problems = const []});

  final bool ok;

  /// What is wrong, in plain words, for the form to show. Empty when it was saved.
  final List<String> problems;
}

/// The form's Save: every problem is said before anything is sent; a refusal from the database comes back as a sentence for the form to show
/// (so nothing typed is lost); nothing else ever throws at the screen.
Future<TierSubmitResult> submitTierForm(
  TierForm form, {
  required String orgId,
  required OrgEvent event,
  required OrganizerTiersService service,
  OrgTier? existing,
  List<OrgTier> others = const [],
}) async {
  final problems = validateTierForm(
    form,
    event: event,
    existing: existing,
    others: others,
  );
  if (problems.isNotEmpty) {
    return TierSubmitResult(ok: false, problems: problems);
  }
  try {
    await service.save(
      orgId,
      event.eventId,
      existing?.tierId,
      tierPayload(form),
    );
    return const TierSubmitResult(ok: true);
  } on OrganizerEventsActionException catch (e) {
    return TierSubmitResult(ok: false, problems: [e.message]);
  }
}
