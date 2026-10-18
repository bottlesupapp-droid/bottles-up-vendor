/// Where a business stands with BottlesUp's verification (brief 15 Oct, sections 4 and 5: "Awaiting verification: show status and permitted
/// draft/setup actions"). The wording is the website's (`src/lib/verification.ts`), word for word; a test compares them when the website repo
/// is checked out beside this app. Verification and setup are SEPARATE: setup never waits for review, publishing does.
enum VerificationState {
  notSubmitted('not_submitted', 'Not submitted', 'Complete the required details and submit your business for verification.'),
  underReview('under_review', 'Under review', 'We are reviewing your details. You can keep setting up your venue while you wait.'),
  moreInformationNeeded('more_information_needed', 'More information needed', 'We need a little more from you. Update your details and submit again.'),
  verified('verified', 'Verified', 'Your business is verified.');

  const VerificationState(this.db, this.label, this.summary);

  /// The value the database stores.
  final String db;
  final String label;

  /// One line telling the business where it stands and what it can do.
  final String summary;

  /// Null for a value this version of the app does not know: it is then not shown as anything it is not.
  static VerificationState? fromDb(String? value) {
    for (final s in values) {
      if (s.db == value) return s;
    }
    return null;
  }

  /// Drafting a venue or an event is allowed in every state.
  bool get canDraft => true;

  /// The business is cleared to publish (the venue's own required setup is a separate check).
  bool get cleared => this == VerificationState.verified;
}

/// One of the person's businesses as `my_businesses()` reports it (owner and organizer memberships only).
class BusinessStatus {
  const BusinessStatus({
    required this.orgId,
    required this.name,
    required this.kind,
    required this.role,
    required this.state,
    this.requestMessage,
    this.missing = const [],
    this.venueCount = 0,
    this.pendingClaims = 0,
  });

  final String orgId;
  final String name;

  /// 'venue_owner' or 'organizer'.
  final String kind;
  final String role;
  final VerificationState state;

  /// What the reviewer asked for, shown while more information is needed.
  final String? requestMessage;

  /// Keys of what is still missing before the business can be submitted.
  final List<String> missing;
  final int venueCount;
  final int pendingClaims;

  bool get isOrganizer => kind == 'organizer';
}

BusinessStatus? parseBusinessStatus(Map<String, dynamic> row) {
  final orgId = row['org_id']?.toString();
  final state = VerificationState.fromDb(row['verification_state']?.toString());
  if (orgId == null || orgId.isEmpty || state == null) return null;
  int count(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  final missing = row['missing'];
  final message = row['request_message']?.toString().trim();
  return BusinessStatus(
    orgId: orgId,
    name: row['org_name']?.toString() ?? '',
    kind: row['org_kind']?.toString() ?? '',
    role: row['role']?.toString() ?? '',
    state: state,
    requestMessage: message == null || message.isEmpty ? null : message,
    missing: missing is List ? [for (final k in missing) '$k'] : const [],
    venueCount: count(row['venue_count']),
    pendingClaims: count(row['pending_claims']),
  );
}

/// The businesses of the signed-in person that belong to [orgId]: at most one. A person can hold roles in several businesses.
BusinessStatus? statusFor(List<BusinessStatus> all, String orgId) {
  for (final b in all) {
    if (b.orgId == orgId) return b;
  }
  return null;
}

/// What is still missing before submitting, in words (the website's own messages). A key this version does not know is shown as it is, so
/// a new server-side requirement can never silently vanish from the screen.
const Map<String, String> missingMessages = {
  'legal_name': 'Add your legal business name',
  'representative_name': 'Add the name of the person representing the business',
  'representative_phone': 'Add a phone number for that person',
  'contact_email': 'Add a contact email for the business',
  'address': 'Add the business address',
  'representative_confirmed': 'Confirm that you are 18 or older and allowed to represent this business',
  'description': 'Add a short description of your business',
  'venue': 'Add a venue, or ask to claim one that already exists',
};

List<String> describeMissing(List<String> keys) => [for (final k in keys) missingMessages[k] ?? 'Complete: ${k.replaceAll('_', ' ')}'];

/// What the business can do now, and what waits for verification, as sentences (brief: "permitted draft/setup actions").
({List<String> can, List<String> waits}) whatYouCanDo(BusinessStatus b) {
  final can = <String>[
    if (b.isOrganizer) 'Create and save event drafts' else 'Set up your venues: rooms, tables, bottle menu, booking times',
    'Invite your team',
  ];
  final waits = b.state.cleared
      ? const <String>[]
      : <String>[if (b.isOrganizer) 'Publishing an event' else 'Taking a venue live'];
  return (can: can, waits: waits);
}

/// Whether the card is shown at all: a verified business has nothing to wait for.
bool showsStatusCard(BusinessStatus? b) => b != null && !b.state.cleared;
