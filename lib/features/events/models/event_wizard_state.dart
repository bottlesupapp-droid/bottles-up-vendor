import 'ticket_type.dart';
import 'event_team_member.dart';

class EventBasicsData {
  final String name;
  final String? description;
  final String? categoryId;
  final String? clubId;
  final String zoneId;
  final String? city;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final String? flyerImageUrl;
  final List<String>? images;

  const EventBasicsData({
    required this.name,
    this.description,
    this.categoryId,
    this.clubId,
    required this.zoneId,
    this.city,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.flyerImageUrl,
    this.images,
  });

  EventBasicsData copyWith({
    String? name,
    String? description,
    String? categoryId,
    String? clubId,
    String? zoneId,
    String? city,
    DateTime? eventDate,
    String? startTime,
    String? endTime,
    String? flyerImageUrl,
    List<String>? images,
  }) {
    return EventBasicsData(
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      clubId: clubId ?? this.clubId,
      zoneId: zoneId ?? this.zoneId,
      city: city ?? this.city,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      flyerImageUrl: flyerImageUrl ?? this.flyerImageUrl,
      images: images ?? this.images,
    );
  }
}

class EventTableData {
  final String? id;
  final String name;
  final int capacity;
  final double price;
  final bool isVip;
  final String? locationDescription;
  final double? minimumSpend;
  final String? imageUrl;

  const EventTableData({
    this.id,
    required this.name,
    required this.capacity,
    required this.price,
    this.isVip = false,
    this.locationDescription,
    this.minimumSpend,
    this.imageUrl,
  });

  EventTableData copyWith({
    String? id,
    String? name,
    int? capacity,
    double? price,
    bool? isVip,
    String? locationDescription,
    double? minimumSpend,
    String? imageUrl,
  }) {
    return EventTableData(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      isVip: isVip ?? this.isVip,
      locationDescription: locationDescription ?? this.locationDescription,
      minimumSpend: minimumSpend ?? this.minimumSpend,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class EventBottleData {
  final String? id;
  final String name;
  final String? brand;
  final String category;
  final double price;
  final String? description;
  final String? imageUrl;

  const EventBottleData({
    this.id,
    required this.name,
    this.brand,
    required this.category,
    required this.price,
    this.description,
    this.imageUrl,
  });

  EventBottleData copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    double? price,
    String? description,
    String? imageUrl,
  }) {
    return EventBottleData(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class EventWizardState {
  final EventBasicsData? basics;
  final List<TicketType> ticketTypes;
  final List<EventTableData> tables;
  final List<EventBottleData> bottles;
  final List<EventTeamMember> teamMembers;
  final String? termsAndConditions;
  final String? specialInstructions;
  final int currentStep;

  const EventWizardState({
    this.basics,
    this.ticketTypes = const [],
    this.tables = const [],
    this.bottles = const [],
    this.teamMembers = const [],
    this.termsAndConditions,
    this.specialInstructions,
    this.currentStep = 0,
  });

  factory EventWizardState.initial() {
    return const EventWizardState();
  }

  EventWizardState copyWith({
    EventBasicsData? basics,
    List<TicketType>? ticketTypes,
    List<EventTableData>? tables,
    List<EventBottleData>? bottles,
    List<EventTeamMember>? teamMembers,
    String? termsAndConditions,
    String? specialInstructions,
    int? currentStep,
  }) {
    return EventWizardState(
      basics: basics ?? this.basics,
      ticketTypes: ticketTypes ?? this.ticketTypes,
      tables: tables ?? this.tables,
      bottles: bottles ?? this.bottles,
      teamMembers: teamMembers ?? this.teamMembers,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  bool get isBasicsComplete => basics != null;
  bool get hasTickets => ticketTypes.isNotEmpty;
  bool get hasTables => tables.isNotEmpty;
  bool get hasBottles => bottles.isNotEmpty;
  bool get hasTeam => teamMembers.isNotEmpty;

  int get totalCapacity => ticketTypes.fold(0, (sum, ticket) => sum + ticket.capacity);
}
