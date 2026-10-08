// The owner's Venues and Home screens (Phase 2 brief, section 2: Owner "Home" and "Venues"): which venues a business owns, how
// far each is set up, and where guests book. Pure Dart, tested without a screen. It ports the website's src/lib/venueSetup.ts
// (the setup checklist) and src/lib/bookingLink.ts (the booking address), and reads the rows of the website's my_venues() and
// venue_setup_status() functions. The database decides which venues a person can see and what each step's state is; nothing
// here grants access.

// ---------------------------------------------------------------------------
// Venues
// ---------------------------------------------------------------------------

class OrgVenue {
  const OrgVenue({required this.id, required this.name, required this.status, this.slug, this.address});

  final String id;
  final String name;

  /// 'published' (live) or anything else (a draft).
  final String status;

  /// The part of the booking address after /venues/. Null when the database has not given one.
  final String? slug;
  final String? address;

  bool get isLive => isLiveStatus(status);

  OrgVenue withDetails({String? name, String? status, String? slug, String? address}) =>
      OrgVenue(id: id, name: name ?? this.name, status: status ?? this.status, slug: slug ?? this.slug, address: address ?? this.address);
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;

/// One my_venues() row: venue_id, venue_name, org_id, status. A row without an id is dropped. Returns the organization too, so
/// a business sees only its own venues (a person can hold roles in several organizations).
({OrgVenue venue, String orgId})? parseMyVenue(Map<String, dynamic> row) {
  final id = _text(row['venue_id']);
  if (id == null) return null;
  return (
    venue: OrgVenue(id: id, name: _text(row['venue_name']) ?? _text(row['name']) ?? 'Venue', status: _text(row['status']) ?? 'draft'),
    orgId: _text(row['org_id']) ?? '',
  );
}

/// The public page only shows a published venue, so only a published venue's booking link works.
bool isLiveStatus(String status) => status == 'published';

/// "Live" or "Draft", for the chip beside a venue's name.
String statusWord(String status) => isLiveStatus(status) ? 'Live' : 'Draft';

/// A sentence about what is wrong with a new venue's name, or null when it can be created. The database trims it and refuses an
/// empty one; the 120 limit is the one the website's forms use.
String? validateVenueName(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'Give the venue a name.';
  if (t.length > 120) return 'The name must be 120 characters or fewer.';
  return null;
}

// ---------------------------------------------------------------------------
// The setup checklist
// ---------------------------------------------------------------------------

enum SetupStatus { done, todo, unavailable }

class SetupStep {
  const SetupStep({required this.step, required this.status, required this.required, this.detail});

  final String step;
  final SetupStatus status;
  final bool required;

  /// What is missing, for a step still to do.
  final String? detail;
}

/// One venue_setup_status() row. A status this code does not know is "to do", never "done".
SetupStep? parseSetupStep(Map<String, dynamic> row) {
  final step = _text(row['step']);
  if (step == null) return null;
  final status = switch (row['status']) {
    'done' => SetupStatus.done,
    'unavailable' => SetupStatus.unavailable,
    _ => SetupStatus.todo,
  };
  return SetupStep(step: step, status: status, required: row['required'] == true, detail: _text(row['detail']));
}

class _StepMeta {
  const _StepMeta(this.label, this.description);

  final String label;
  final String description;
}

// Order here is the order shown, and follows the brief's checklist (the website's venueSetup.ts).
const Map<String, _StepMeta> _meta = {
  'profile': _StepMeta('Venue profile', 'Name, description, address and cover photo guests will see.'),
  'floor_plan': _StepMeta('Rooms and floor plan', 'Upload your floor plan so tables can be placed on it.'),
  'tables': _StepMeta('Tables and capacities', 'Table types with capacity, deposit and minimum spend.'),
  'bottles': _StepMeta('Bottle menu and stock', 'The bottles guests can pre-order or add at the table.'),
  'booking_rules': _StepMeta('Booking rules', 'The days and arrival times you accept bookings.'),
  'payments': _StepMeta('Payment configuration', 'How you collect deposits and balances.'),
  'team': _StepMeta('Team', 'Managers and staff for this venue.'),
  'notifications': _StepMeta('Notifications and reports', 'Who receives alerts and nightly reports.'),
};

final List<String> _order = _meta.keys.toList();

String stepLabel(String step) => _meta[step]?.label ?? step.replaceAll('_', ' ');
String stepDescription(String step) => _meta[step]?.description ?? '';

/// Steps in the brief's order. A step this code does not know about is kept, at the end.
List<SetupStep> orderSteps(List<SetupStep> steps) {
  int rank(String s) {
    final i = _order.indexOf(s);
    return i == -1 ? _order.length : i;
  }

  final copy = List.of(steps);
  // Dart's sort is not stable, so ties (unknown steps) keep the order they arrived in by their position.
  final position = {for (var i = 0; i < copy.length; i++) copy[i]: i};
  copy.sort((a, b) {
    final c = rank(a.step).compareTo(rank(b.step));
    return c != 0 ? c : position[a]!.compareTo(position[b]!);
  });
  return copy;
}

class SetupSummary {
  const SetupSummary({
    required this.requiredTotal,
    required this.requiredDone,
    required this.requiredTodo,
    required this.percent,
    required this.ready,
    this.nextStep,
  });

  final int requiredTotal;
  final int requiredDone;
  final int requiredTodo;

  /// 0 to 100, a whole number. Only required steps count.
  final int percent;

  /// Every required step is done.
  final bool ready;

  /// The first required step still to do, so the screen can point at it.
  final SetupStep? nextStep;
}

SetupSummary summarizeSetup(List<SetupStep> steps) {
  final required = orderSteps(steps).where((s) => s.required).toList();
  final done = required.where((s) => s.status == SetupStatus.done).length;
  final todo = required.where((s) => s.status == SetupStatus.todo).length;
  final total = required.length;
  return SetupSummary(
    requiredTotal: total,
    requiredDone: done,
    requiredTodo: todo,
    // An empty list is NOT "100% ready": nothing was measured.
    percent: total == 0 ? 0 : (done / total * 100).round(),
    ready: total > 0 && done == total,
    nextStep: required.where((s) => s.status == SetupStatus.todo).firstOrNull,
  );
}

/// Plain wording for a step's state. "Unavailable" is never shown as done or pending.
String setupStatusLabel(SetupStatus status) => switch (status) {
      SetupStatus.done => 'Done',
      SetupStatus.todo => 'To do',
      SetupStatus.unavailable => 'Coming soon',
    };

// ---------------------------------------------------------------------------
// The booking link
// ---------------------------------------------------------------------------

const String defaultSiteUrl = 'https://www.bottlesupapp.com';

/// The address links should point at. A configured value is used only if it is a plain https address; anything else (http,
/// garbage, a login embedded in it) is ignored and the real site is used, so a mistake in configuration can never put a wrong
/// or unsafe address on a printed QR code. A path or query on it is dropped: only the origin is kept.
String siteOrigin(String? configured) {
  final raw = (configured ?? '').trim();
  if (raw.isNotEmpty) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty && uri.host.contains('.')) {
      return uri.origin;
    }
  }
  return defaultSiteUrl;
}

const String _configuredSite = String.fromEnvironment('SITE_URL');

/// Where booking links point in this build: `--dart-define=SITE_URL=https://...` or the real site.
final String siteUrl = siteOrigin(_configuredSite);

/// `https://site/venues/<slug>`, or the venue id when it has no usable slug (the public page accepts both).
String bookingLink(String site, {required String id, String? slug}) {
  final usable = slug != null && RegExp(r'^[a-z0-9][a-z0-9-]*$', caseSensitive: false).hasMatch(slug) ? slug : id;
  final base = site.replaceAll(RegExp(r'/+$'), '');
  return '$base/venues/${Uri.encodeComponent(usable)}';
}

String linkNote(String status) => isLiveStatus(status)
    ? 'Guests can book through this link now.'
    : 'This link starts working when the venue goes live. Until then guests who open it will see a "not found" page.';

// ---------------------------------------------------------------------------
// Wording for a failed load
// ---------------------------------------------------------------------------

String ownerLoadMessage({required bool unavailable, required bool accessEnded}) {
  if (unavailable) return 'Venues are not set up on this server yet.';
  if (accessEnded) return 'Your access has ended, or you are signed out.';
  return 'This could not be loaded. Check your connection and try again.';
}
