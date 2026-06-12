import 'package:flutter_test/flutter_test.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:bottles_up_vendor/shared/models/event.dart';
import 'package:bottles_up_vendor/shared/models/booking_model.dart';

void main() {
  group('Model Serialization Tests', () {
    group('UserModel', () {
      test('UserModel can be created and serialized', () {
        // Create a user
        final user = UserModel(
          id: 'test-id-123',
          email: 'test@example.com',
          name: 'Test User',
          phone: '+1234567890',
          createdAt: DateTime(2024, 1, 1),
          isActive: true,
        );

        // Verify fields
        expect(user.id, 'test-id-123');
        expect(user.email, 'test@example.com');
        expect(user.name, 'Test User');
        expect(user.phone, '+1234567890');
        expect(user.isActive, true);
      });

      test('UserModel toJson and fromJson works', () {
        final originalUser = UserModel(
          id: 'test-id-456',
          email: 'user@example.com',
          name: 'User Name',
          phone: '+9876543210',
          createdAt: DateTime(2024, 1, 1),
          profileImageUrl: 'https://example.com/image.jpg',
          bio: 'Test bio',
          isActive: true,
          clubIds: ['club1', 'club2'],
        );

        // Serialize to JSON
        final json = originalUser.toJson();

        // Verify JSON structure
        expect(json['id'], 'test-id-456');
        expect(json['email'], 'user@example.com');
        expect(json['name'], 'User Name');
        expect(json['phone'], '+9876543210');
        expect(json['profileImageUrl'], 'https://example.com/image.jpg');

        // Deserialize from JSON
        final deserializedUser = UserModel.fromJson(json);

        // Verify deserialized object matches original
        expect(deserializedUser.id, originalUser.id);
        expect(deserializedUser.email, originalUser.email);
        expect(deserializedUser.name, originalUser.name);
        expect(deserializedUser.phone, originalUser.phone);
        expect(deserializedUser.profileImageUrl, originalUser.profileImageUrl);
      });
    });

    group('Event', () {
      test('Event can be created with required fields', () {
        final event = Event(
          id: 'event-123',
          name: 'Test Event',
          description: 'Event description',
          userId: 'user-123',
          zoneId: 'zone-123',
          eventDate: DateTime(2024, 12, 31),
          startTime: '20:00',
          endTime: '23:30',
          ticketPrice: 50.0,
          maxCapacity: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(event.id, 'event-123');
        expect(event.name, 'Test Event');
        expect(event.description, 'Event description');
        expect(event.userId, 'user-123');
        expect(event.ticketPrice, 50.0);
        expect(event.maxCapacity, 100);
      });

      test('Event toJson and fromJson works', () {
        final originalEvent = Event(
          id: 'event-456',
          name: 'Concert Night',
          description: 'Live music event',
          userId: 'user-456',
          zoneId: 'zone-456',
          eventDate: DateTime(2024, 6, 15),
          startTime: '21:00',
          endTime: '02:00',
          ticketPrice: 75.0,
          maxCapacity: 200,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dressCode: 'Smart Casual',
          minAge: 21,
        );

        // Serialize to JSON
        final json = originalEvent.toJson();

        // Verify JSON structure
        expect(json['id'], 'event-456');
        expect(json['name'], 'Concert Night');
        expect(json['dress_code'], 'Smart Casual');
        expect(json['min_age'], 21);

        // Deserialize from JSON
        final deserializedEvent = Event.fromJson(json);

        // Verify deserialized object matches original
        expect(deserializedEvent.id, originalEvent.id);
        expect(deserializedEvent.name, originalEvent.name);
        expect(deserializedEvent.dressCode, originalEvent.dressCode);
        expect(deserializedEvent.minAge, originalEvent.minAge);
      });
    });

    group('BookingModel', () {
      test('BookingModel can be created', () {
        final booking = BookingModel(
          id: 'booking-123',
          userId: 'user-123',
          eventId: 'event-123',
          customerName: 'John Doe',
          customerEmail: 'john@example.com',
          totalAmount: 100.0,
          status: 'confirmed',
          createdAt: DateTime.now(),
        );

        expect(booking.id, 'booking-123');
        expect(booking.customerName, 'John Doe');
        expect(booking.totalAmount, 100.0);
        expect(booking.status, 'confirmed');
      });

      test('BookingModel toJson and fromJson works', () {
        final originalBooking = BookingModel(
          id: 'booking-456',
          userId: 'user-456',
          eventId: 'event-456',
          customerName: 'Jane Smith',
          customerEmail: 'jane@example.com',
          totalAmount: 150.0,
          status: 'pending',
          createdAt: DateTime(2024, 3, 15),
        );

        // Serialize to JSON
        final json = originalBooking.toJson();

        // Verify JSON structure
        expect(json['id'], 'booking-456');
        expect(json['customer_name'], 'Jane Smith');
        expect(json['total_amount'], 150.0);

        // Deserialize from JSON
        final deserializedBooking = BookingModel.fromJson(json);

        // Verify deserialized object matches original
        expect(deserializedBooking.id, originalBooking.id);
        expect(deserializedBooking.customerName, originalBooking.customerName);
        expect(deserializedBooking.totalAmount, originalBooking.totalAmount);
      });
    });
  });
}
