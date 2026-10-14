// The organizer's own events (Phase 2 brief section 7; client feedback of 10 Oct 2026: "Event organizer page needs a create event").
// Pure Dart, tested without a screen. A port of the website's src/lib/organizerEvents.ts: each check mirrors the database function
// that finally decides (save_org_event in the website repo's 20261013100000_organizer_events.sql), so the form says what is wrong in
// plain words before anything is sent and the database still refuses whatever gets past it. The wording is the website's, word for
// word (a test compares them when the website repo is checked out beside this app).
//
// What an organizer can do: create a DRAFT, change it, remove it. What it cannot: publish (the BottlesUp team does, in the CMS),
// change or remove a published event (tickets may have been sold), or touch another business's events. The form has no status field
// for that reason, and the payload never carries one.
//
// The cover photo is one field like any other: the form holds the address of the photo (uploaded when it is chosen) and sends it as
// `cover_image_url`; empty is sent as "none", so it can be cleared.

import 'package:intl/intl.dart';

class EventLimits {
  const EventLimits._();

  static const int title = 120;
  static const int description = 5000;
  static const int venueName = 120;
  static const int address = 200;
  static const int category = 40;
  static const int capacityMax = 100000;

  /// Events one business can hold, drafts included.
  static const int perBusiness = 200;
}

enum OrgEventStatus {
  draft,
  published;

  String get label => this == OrgEventStatus.draft ? 'Draft' : 'Published';

  /// What the status means for the organizer, in one line.
  String get note => this == OrgEventStatus.draft
      ? 'Only you can see this. The BottlesUp team publishes it when it is ready.'
      : 'Live on the website. Contact BottlesUp to change it.';
}

class OrgEvent {
  const OrgEvent({
    required this.eventId,
    required this.title,
    required this.startDate,
    required this.status,
    this.description = '',
    this.venueName = '',
    this.address,
    this.endDate,
    this.category,
    this.capacity,
    this.coverImageUrl,
    this.ticketTierCount = 0,
  });

  final String eventId;
  final String title;
  final String description;
  final String venueName;
  final String? address;
  final DateTime startDate;
  final DateTime? endDate;
  final String? category;
  final int? capacity;
  final String? coverImageUrl;
  final OrgEventStatus status;
  final int ticketTierCount;

  bool get isDraft => status == OrgEventStatus.draft;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);

/// One list_org_events row. A row without an id, a title or a start is dropped. Anything that is not exactly 'draft' is read as
/// published: drafts are the only events the organizer may change or remove, so an unknown status must never unlock that.
OrgEvent? parseOrgEvent(Map<String, dynamic> r) {
  final id = _text(r['event_id']);
  final title = _text(r['title']);
  final startRaw = _text(r['start_date']);
  final start = startRaw == null ? null : DateTime.tryParse(startRaw);
  if (id == null || title == null || start == null) return null;
  final endRaw = _text(r['end_date']);
  return OrgEvent(
    eventId: id,
    title: title,
    description: r['description'] is String ? r['description'] as String : '',
    venueName: r['venue_name'] is String ? r['venue_name'] as String : '',
    address: _text(r['address']),
    startDate: start,
    endDate: endRaw == null ? null : DateTime.tryParse(endRaw),
    category: _text(r['category']),
    capacity: _int(r['capacity']),
    coverImageUrl: _text(r['cover_image_url']),
    status: r['status'] == 'draft' ? OrgEventStatus.draft : OrgEventStatus.published,
    ticketTierCount: _int(r['ticket_tier_count']) ?? 0,
  );
}

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Text is as typed into the boxes; `starts` and `ends` are the person's own clock, as the date pickers give them.
class EventForm {
  const EventForm({
    this.title = '',
    this.description = '',
    this.venueName = '',
    this.address = '',
    this.starts,
    this.ends,
    this.category = '',
    this.capacity = '',
    this.coverImageUrl = '',
  });

  final String title;
  final String description;
  final String venueName;
  final String address;
  final DateTime? starts;
  final DateTime? ends;
  final String category;
  final String capacity;
  final String coverImageUrl;
}

EventForm eventFormFrom(OrgEvent e) => EventForm(
      title: e.title,
      description: e.description,
      venueName: e.venueName,
      address: e.address ?? '',
      starts: e.startDate.toLocal(),
      ends: e.endDate?.toLocal(),
      category: e.category ?? '',
      capacity: e.capacity == null ? '' : '${e.capacity}',
      coverImageUrl: e.coverImageUrl ?? '',
    );

/// Plain-language problems with the form; an empty list means it can be sent.
List<String> validateEventForm(EventForm f) {
  final p = <String>[];
  int len(String s) => s.trim().length;

  if (len(f.title) == 0) {
    p.add('Give the event a title.');
  } else if (len(f.title) > EventLimits.title) {
    p.add('The title must be ${EventLimits.title} characters or fewer.');
  }

  if (len(f.description) == 0) {
    p.add('Describe the event for your guests.');
  } else if (len(f.description) > EventLimits.description) {
    p.add('The description must be ${EventLimits.description} characters or fewer.');
  }

  if (len(f.venueName) == 0) {
    p.add('Say where it is held: the venue or place name.');
  } else if (len(f.venueName) > EventLimits.venueName) {
    p.add('The venue name must be ${EventLimits.venueName} characters or fewer.');
  }

  if (len(f.address) > EventLimits.address) p.add('The address must be ${EventLimits.address} characters or fewer.');
  if (len(f.category) > EventLimits.category) p.add('The category must be ${EventLimits.category} characters or fewer.');

  final start = f.starts;
  if (start == null) {
    p.add('Choose when it starts.');
  } else if (f.ends != null && !f.ends!.isAfter(start)) {
    p.add('The end must be after the start.');
  }

  if (f.capacity.trim().isNotEmpty) {
    final c = RegExp(r'^\d{1,9}$').hasMatch(f.capacity.trim()) ? int.parse(f.capacity.trim()) : null;
    if (c == null || c > EventLimits.capacityMax) p.add('Capacity must be a whole number from 0 to ${EventLimits.capacityMax}, or left empty.');
  }
  return p;
}

/// What is sent: every field the form shows (the cover photo is one of them), and nothing it does not. In particular never a status, a
/// business or a slug. Times go as UTC instants, which carry their time zone (the database refuses one without,
/// because it would guess). Only call this when [validateEventForm] returned nothing.
Map<String, dynamic> eventPayload(EventForm f) {
  String? opt(String s) => s.trim().isEmpty ? null : s.trim();
  return {
    'title': f.title.trim(),
    'description': f.description.trim(),
    'venue_name': f.venueName.trim(),
    'address': opt(f.address),
    'start_date': f.starts!.toUtc().toIso8601String(),
    'end_date': f.ends?.toUtc().toIso8601String(),
    'category': opt(f.category),
    'capacity': f.capacity.trim().isEmpty ? null : int.parse(f.capacity.trim()),
    'cover_image_url': opt(f.coverImageUrl),
  };
}

// ---------------------------------------------------------------------------
// The list
// ---------------------------------------------------------------------------

/// An event with no end is treated as lasting this long, so an overnight party is not "past" at midnight.
const int openEndedHours = 12;

bool hasEnded(OrgEvent e, DateTime now) {
  final end = e.endDate ?? e.startDate.add(const Duration(hours: openEndedHours));
  return end.isBefore(now);
}

/// Drafts first (they are the ones that need the organizer), then what is coming up soonest first, then what has happened most
/// recent first. An event with nothing in a group leaves that group empty.
({List<OrgEvent> drafts, List<OrgEvent> upcoming, List<OrgEvent> past}) groupEvents(List<OrgEvent> events, DateTime now) {
  int byStart(OrgEvent a, OrgEvent b) => a.startDate.compareTo(b.startDate);
  final drafts = events.where((e) => e.isDraft).toList()..sort(byStart);
  final live = events.where((e) => !e.isDraft);
  return (
    drafts: drafts,
    upcoming: live.where((e) => !hasEnded(e, now)).toList()..sort(byStart),
    past: live.where((e) => hasEnded(e, now)).toList()..sort((a, b) => byStart(b, a)),
  );
}

/// "Fri, Oct 24, 2031, 6:00 PM" and, when there is an end, "to 10:30 PM" (or the other day when it ends on another day).
String formatEventWhen(DateTime start, DateTime? end) {
  final full = DateFormat('EEE, MMM d, y, h:mm a', 'en_US');
  final clock = DateFormat('h:mm a', 'en_US');
  final base = full.format(start.toLocal());
  if (end == null) return base;
  final s = start.toLocal();
  final e = end.toLocal();
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  return sameDay ? '$base to ${clock.format(e)}' : '$base to ${full.format(e)}';
}

/// The database writes short lower-case sentences for developers. This makes one a sentence for a person.
String sentence(String message) {
  final t = message.trim();
  if (t.isEmpty) return 'Please try again.';
  final s = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?]$').hasMatch(s) ? s : '$s.';
}
