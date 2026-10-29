import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/payout_rules.dart';
import '../services/payout_service.dart';

final payoutServiceProvider = Provider<PayoutService>((ref) => PayoutService());

/// What the business is paid out. Never kept: the status of a payout changes in the CMS.
final myPayoutsProvider = FutureProvider.autoDispose.family<MyPayouts, String>((ref, orgId) => ref.watch(payoutServiceProvider).mine(orgId));
