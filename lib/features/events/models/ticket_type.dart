class TicketType {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final int capacity;
  final int soldCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.price,
    required this.capacity,
    this.soldCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      capacity: json['capacity'] as int,
      soldCount: json['sold_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'description': description,
      'price': price,
      'capacity': capacity,
      'sold_count': soldCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TicketType copyWith({
    String? id,
    String? eventId,
    String? name,
    String? description,
    double? price,
    int? capacity,
    int? soldCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketType(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      soldCount: soldCount ?? this.soldCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get availableTickets => capacity - soldCount;
  bool get isSoldOut => soldCount >= capacity;
  double get percentageSold => capacity > 0 ? (soldCount / capacity) * 100 : 0;
}
