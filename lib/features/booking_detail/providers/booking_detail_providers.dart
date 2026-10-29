import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/booking_detail_rules.dart';
import '../services/booking_detail_service.dart';

final bookingDetailServiceProvider = Provider<BookingDetailService>((ref) => BookingDetailService());

final bookingGuestsProvider = FutureProvider.autoDispose.family<BookingGuests, String>((ref, bookingId) => ref.watch(bookingDetailServiceProvider).guests(bookingId));

final bookingActivityProvider = FutureProvider.autoDispose.family<List<ActivityEntry>, String>((ref, bookingId) => ref.watch(bookingDetailServiceProvider).activity(bookingId));

/// The guest's bottle sign for one booking, or null when there is none.
final bookingSignProvider = FutureProvider.autoDispose.family<String?, String>((ref, bookingId) => ref.watch(bookingDetailServiceProvider).sign(bookingId));
