import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/business_status.dart';
import '../services/business_service.dart';

final businessServiceProvider = Provider<BusinessService>((ref) => BusinessService());

/// The verification state of one business. A failed read is an error (the card then says nothing rather than guess "verified" or "not submitted").
final businessStatusProvider = FutureProvider.autoDispose.family<BusinessStatus?, String>((ref, orgId) async {
  final all = await ref.watch(businessServiceProvider).mine();
  return statusFor(all, orgId);
});
