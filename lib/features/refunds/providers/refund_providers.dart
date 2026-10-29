import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/refund_rules.dart';
import '../services/refund_service.dart';

final refundServiceProvider = Provider<RefundService>((ref) => RefundService());

/// The venue's refund policy. Not kept: a policy read from a minute ago is not what guests are shown now.
final refundPolicyProvider = FutureProvider.autoDispose.family<RefundPolicy, String>((ref, venueId) => ref.watch(refundServiceProvider).policy(venueId));

/// All of the venue's refund requests (the screen filters them), waiting ones first.
final refundRequestsProvider = FutureProvider.autoDispose.family<List<RefundRequest>, String>((ref, venueId) => ref.watch(refundServiceProvider).requests(venueId));

/// What one booking's policy says now and what can still be refunded.
final refundOptionsProvider = FutureProvider.autoDispose.family<RefundOptions, String>((ref, bookingId) => ref.watch(refundServiceProvider).options(bookingId));
