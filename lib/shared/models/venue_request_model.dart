// Venue Request model for organizer-to-venue proposals

enum VenueRequestStatus {
  pending,
  approved,
  declined,
}

class VenueRequest {
  final String id;
  final String venueId;
  final String organizerId;
  final Map<String, dynamic> eventProposal; // {title, description, event_date, start_time, end_time}
  final int? expectedAttendance;
  final VenueRequestStatus status;
  final String? notes;
  final String? declineReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Extracted from event_proposal for convenience
  String? get eventTitle => eventProposal['title'] as String?;
  String? get eventDescription => eventProposal['description'] as String?;
  String? get flyerUrl => eventProposal['flyer_url'] as String?;
  DateTime? get eventDate {
    final dateStr = eventProposal['event_date'];
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  const VenueRequest({
    required this.id,
    required this.venueId,
    required this.organizerId,
    required this.eventProposal,
    this.expectedAttendance,
    this.status = VenueRequestStatus.pending,
    this.notes,
    this.declineReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VenueRequest.fromJson(Map<String, dynamic> json) {
    return VenueRequest(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      organizerId: json['organizer_id'] as String,
      eventProposal: json['event_proposal'] as Map<String, dynamic>? ?? {},
      expectedAttendance: json['expected_attendance'] as int?,
      status: _parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      declineReason: json['decline_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static VenueRequestStatus _parseStatus(String? status) {
    if (status == null) return VenueRequestStatus.pending;
    try {
      return VenueRequestStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return VenueRequestStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venue_id': venueId,
      'organizer_id': organizerId,
      'event_proposal': eventProposal,
      'expected_attendance': expectedAttendance,
      'status': status.name,
      'notes': notes,
      'decline_reason': declineReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  VenueRequest copyWith({
    String? id,
    String? venueId,
    String? organizerId,
    Map<String, dynamic>? eventProposal,
    int? expectedAttendance,
    VenueRequestStatus? status,
    String? notes,
    String? declineReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VenueRequest(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      organizerId: organizerId ?? this.organizerId,
      eventProposal: eventProposal ?? this.eventProposal,
      expectedAttendance: expectedAttendance ?? this.expectedAttendance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      declineReason: declineReason ?? this.declineReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == VenueRequestStatus.pending;
  bool get isApproved => status == VenueRequestStatus.approved;
  bool get isDeclined => status == VenueRequestStatus.declined;

  @override
  String toString() {
    return 'VenueRequest(id: $id, status: ${status.name}, eventTitle: $eventTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VenueRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Request for creating a venue proposal
class CreateVenueRequestData {
  final String venueId;
  final String eventTitle;
  final String eventDescription;
  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final String? flyerUrl;
  final int expectedAttendance;
  final String? notes;

  const CreateVenueRequestData({
    required this.venueId,
    required this.eventTitle,
    required this.eventDescription,
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.flyerUrl,
    required this.expectedAttendance,
    this.notes,
  });

  Map<String, dynamic> toEventProposal() {
    return {
      'title': eventTitle,
      'description': eventDescription,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'flyer_url': flyerUrl,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'venue_id': venueId,
      'event_proposal': toEventProposal(),
      'expected_attendance': expectedAttendance,
      'notes': notes,
      'status': 'pending',
    };
  }
}
