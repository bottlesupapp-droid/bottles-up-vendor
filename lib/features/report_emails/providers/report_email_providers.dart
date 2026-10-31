import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/report_email_rules.dart';
import '../services/report_email_service.dart';

final reportEmailServiceProvider = Provider<ReportEmailService>((ref) => ReportEmailService());

/// The addresses on one list.
final reportRecipientsProvider = FutureProvider.autoDispose.family<List<ReportRecipient>, ReportListScope>((ref, scope) => ref.watch(reportEmailServiceProvider).recipients(scope));

/// The latest attempts to e-mail one report, newest first.
final reportDeliveriesProvider = FutureProvider.autoDispose.family<List<ReportDelivery>, ReportTarget>((ref, target) => ref.watch(reportEmailServiceProvider).deliveries(target));
