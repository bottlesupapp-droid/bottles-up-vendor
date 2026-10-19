import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/seating_rules.dart';
import '../services/seating_service.dart';

final seatingServiceProvider = Provider<SeatingService>((ref) => SeatingService());

/// Where one booking stands. Not kept once the screen is gone.
final seatingStateProvider = FutureProvider.autoDispose.family<SeatingState, String>(
  (ref, bookingId) => ref.watch(seatingServiceProvider).state(bookingId),
);

/// What the guest has been told about one booking, and whether it has gone.
final guestMessagesProvider = FutureProvider.autoDispose.family<List<GuestMessage>, String>(
  (ref, bookingId) => ref.watch(seatingServiceProvider).messages(bookingId),
);
