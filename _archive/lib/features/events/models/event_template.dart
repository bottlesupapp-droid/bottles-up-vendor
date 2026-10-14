class EventTemplate {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final String? categoryId;
  final double? defaultTicketPrice;
  final int? defaultCapacity;
  final String? flyerImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventTemplate({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    this.categoryId,
    this.defaultTicketPrice,
    this.defaultCapacity,
    this.flyerImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventTemplate.fromJson(Map<String, dynamic> json) {
    return EventTemplate(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      defaultTicketPrice: json['default_ticket_price'] != null
          ? (json['default_ticket_price'] as num).toDouble()
          : null,
      defaultCapacity: json['default_capacity'] as int?,
      flyerImageUrl: json['flyer_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'default_ticket_price': defaultTicketPrice,
      'default_capacity': defaultCapacity,
      'flyer_image_url': flyerImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
