import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/complimentary_rules.dart';
import '../services/complimentary_service.dart';

final complimentaryServiceProvider = Provider<ComplimentaryService>((ref) => ComplimentaryService());

/// A club's offers. Read again every time the screen opens or something changes; never kept once it is gone.
final offersProvider = FutureProvider.autoDispose.family<List<OfferRow>, String>((ref, venueId) => ref.watch(complimentaryServiceProvider).list(venueId));

/// The attempts to e-mail one offer's link, newest first. Read again when its sheet opens and after a send.
final offerSendsProvider = FutureProvider.autoDispose.family<List<OfferSend>, String>((ref, offerId) => ref.watch(complimentaryServiceProvider).sends(offerId));
