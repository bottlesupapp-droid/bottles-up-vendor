// The venue's public profile and its floor plans (Phase 2 brief section 2). Pure Dart, tested without a screen. Each check mirrors the
// database function that finally decides (update_venue_profile in the website repo's 20261007100000_accounts_onboarding.sql, and
// save_venue_floor in 20261010100000_venue_setup.sql), so the form says what is wrong in plain words before anything is sent and the
// database still refuses anything that gets past it. A test compares the limits and the field list with those files when the website
// repo is checked out beside this app.

import 'owner_rules.dart' show validateVenueName;

class ProfileLimits {
  const ProfileLimits._();

  static const int description = 4000;
  static const int address = 300;
  static const int floorLabel = 60;

  /// Floors one venue can hold.
  static const int floors = 10;
}

// ---------------------------------------------------------------------------
// The venue profile
// ---------------------------------------------------------------------------

class VenueProfile {
  const VenueProfile({required this.id, required this.name, this.description, this.address, this.coverImageUrl, this.timeZone, this.timeZoneSupported = false});

  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? coverImageUrl;

  /// The zone the venue chose, or null when it has not chosen one (it then reads as [defaultTimeZone]).
  final String? timeZone;

  /// The server knows about venue time zones (website 20261027100000). On a server that does not, the editor shows no time zone field at all rather than one that cannot be saved.
  final bool timeZoneSupported;

  /// The zone in force: the chosen one, otherwise the default.
  String get effectiveTimeZone => timeZone ?? defaultTimeZone;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;

/// One `site_venues` row. A row without an id or a name is not a profile.
VenueProfile? parseVenueProfile(Map<String, dynamic>? r) {
  if (r == null) return null;
  final id = _text(r['id']);
  final name = _text(r['name']);
  if (id == null || name == null) return null;
  return VenueProfile(
    id: id,
    name: name,
    description: _text(r['description']),
    address: _text(r['address']),
    coverImageUrl: _text(r['cover_image_url']),
    timeZone: _text(r['time_zone']),
    // The key is there (even when empty) only when the server has the column.
    timeZoneSupported: r.containsKey('time_zone'),
  );
}

// ---------------------------------------------------------------------------
// The venue's time zone
// ---------------------------------------------------------------------------

/// What every venue reads as until it chooses (the website's `venue_timezone`, 20261027100000 and 20261023100000).
const String defaultTimeZone = 'America/Toronto';

class TimeZoneChoice {
  const TimeZoneChoice(this.zone, this.label);

  /// The place name the database stores (an IANA name, so daylight saving follows the place).
  final String zone;
  final String label;
}

/// The zones a venue can pick in the app: where BottlesUp's clubs are likely to be. The database accepts any real place name; a venue already set to another one keeps it (see [timeZoneChoicesFor]).
const List<TimeZoneChoice> venueTimeZoneChoices = [
  TimeZoneChoice('America/St_Johns', 'Newfoundland (St. John\'s)'),
  TimeZoneChoice('America/Halifax', 'Atlantic (Halifax)'),
  TimeZoneChoice('America/Toronto', 'Eastern (Toronto)'),
  TimeZoneChoice('America/Winnipeg', 'Central (Winnipeg)'),
  TimeZoneChoice('America/Regina', 'Saskatchewan (no daylight saving)'),
  TimeZoneChoice('America/Edmonton', 'Mountain (Edmonton)'),
  TimeZoneChoice('America/Vancouver', 'Pacific (Vancouver)'),
  TimeZoneChoice('America/New_York', 'Eastern (New York)'),
  TimeZoneChoice('America/Chicago', 'Central (Chicago)'),
  TimeZoneChoice('America/Denver', 'Mountain (Denver)'),
  TimeZoneChoice('America/Los_Angeles', 'Pacific (Los Angeles)'),
  TimeZoneChoice('Europe/London', 'London'),
];

/// A person's words for a zone: the label of a zone in the list, otherwise the place name itself.
String timeZoneLabel(String zone) {
  for (final c in venueTimeZoneChoices) {
    if (c.zone == zone) return c.label;
  }
  return zone;
}

/// The choices to offer for a venue now set to [current]: the list, plus the venue's own zone when it is not in it (so opening and saving never changes a zone the app does not list).
List<TimeZoneChoice> timeZoneChoicesFor(String current) => [
      ...venueTimeZoneChoices,
      if (!venueTimeZoneChoices.any((c) => c.zone == current)) TimeZoneChoice(current, current),
    ];

class ProfileForm {
  const ProfileForm({this.name = '', this.description = '', this.address = '', this.coverImageUrl = ''});

  final String name;
  final String description;
  final String address;
  final String coverImageUrl;

  ProfileForm copyWith({String? name, String? description, String? address, String? coverImageUrl}) => ProfileForm(
        name: name ?? this.name,
        description: description ?? this.description,
        address: address ?? this.address,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      );
}

ProfileForm profileFormFrom(VenueProfile p) =>
    ProfileForm(name: p.name, description: p.description ?? '', address: p.address ?? '', coverImageUrl: p.coverImageUrl ?? '');

/// Plain-language problems with the profile form; an empty list means it can be sent.
List<String> validateProfileForm(ProfileForm f) {
  final p = <String>[];
  final name = validateVenueName(f.name);
  if (name != null) p.add(name);
  if (f.description.trim().length > ProfileLimits.description) p.add('The description must be ${ProfileLimits.description} characters or fewer.');
  if (f.address.trim().length > ProfileLimits.address) p.add('The address must be ${ProfileLimits.address} characters or fewer.');
  return p;
}

/// What is sent to update_venue_profile: the four fields the form shows, and nothing else. In particular never the venue's status or
/// slug (only the BottlesUp team changes those), and never the gallery (this version does not edit it, so it is left as it is: the
/// database changes only the keys that are sent). A blank description, address or cover photo is sent as "none", so it can be cleared.
Map<String, dynamic> profilePayload(ProfileForm f) {
  String? opt(String s) => s.trim().isEmpty ? null : s.trim();
  return {
    'name': f.name.trim(),
    'description': opt(f.description),
    'address': opt(f.address),
    'cover_image_url': opt(f.coverImageUrl),
  };
}

// ---------------------------------------------------------------------------
// Floors
// ---------------------------------------------------------------------------

class FloorRow {
  const FloorRow({required this.floorId, required this.label, required this.imageUrl, this.sortOrder = 0, this.tableCount = 0});

  final String floorId;
  final String label;
  final String imageUrl;
  final int sortOrder;

  /// Tables placed on this floor. Removing the floor leaves them, unplaced.
  final int tableCount;
}

int? _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);

/// One list_venue_floors row. A row without an id or a name is dropped.
FloorRow? parseFloor(Map<String, dynamic> r) {
  final id = _text(r['floor_id']);
  final label = _text(r['label']);
  if (id == null || label == null) return null;
  return FloorRow(floorId: id, label: label, imageUrl: _text(r['image_url']) ?? '', sortOrder: _int(r['sort_order']) ?? 0, tableCount: _int(r['table_count']) ?? 0);
}

/// Plain-language problems with the floor form (the website's own words); an empty list means it can be sent.
List<String> validateFloorForm(String label, String imageUrl) {
  final p = <String>[];
  if (label.trim().isEmpty) {
    p.add('Give the floor a name, for example "Main room".');
  } else if (label.trim().length > ProfileLimits.floorLabel) {
    p.add('The name must be ${ProfileLimits.floorLabel} characters or fewer.');
  }
  if (imageUrl.trim().isEmpty) p.add('Upload the floor plan image.');
  return p;
}

/// "No tables placed", "1 table placed", "4 tables placed".
String describeFloorTables(int count) => count == 0 ? 'No tables placed' : '$count ${count == 1 ? 'table' : 'tables'} placed';
