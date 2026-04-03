class EventTeamMember {
  final String id;
  final String eventId;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventTeamMember({
    required this.id,
    required this.eventId,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventTeamMember.fromJson(Map<String, dynamic> json) {
    return EventTeamMember(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventTeamMember copyWith({
    String? id,
    String? eventId,
    String? name,
    String? email,
    String? phone,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventTeamMember(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Common team roles
class TeamRole {
  static const String coordinator = 'Coordinator';
  static const String security = 'Security';
  static const String bartender = 'Bartender';
  static const String host = 'Host';
  static const String manager = 'Manager';
  static const String staff = 'Staff';
  static const String photographer = 'Photographer';
  static const String dj = 'DJ';

  static const List<String> allRoles = [
    coordinator,
    security,
    bartender,
    host,
    manager,
    staff,
    photographer,
    dj,
  ];
}
