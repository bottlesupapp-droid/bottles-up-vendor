import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/sign_rules.dart';
import '../services/bottle_sign_service.dart';

final bottleSignServiceProvider = Provider<BottleSignService>((ref) => BottleSignService());

final signSettingsProvider = FutureProvider.autoDispose.family<SignSettings, String>((ref, venueId) => ref.watch(bottleSignServiceProvider).settings(venueId));

final pendingSignsProvider = FutureProvider.autoDispose.family<List<PendingSign>, String>((ref, venueId) => ref.watch(bottleSignServiceProvider).pending(venueId));

/// The lines a screen holds, as the key for reading their signs together. Two screens holding the same lines share one read.
class LineIds {
  LineIds(Iterable<String> ids) : ids = List.unmodifiable(ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    if (other is! LineIds || other.ids.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (other.ids[i] != ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ids);
}

/// The signs of those lines by line id. A line that is not in the answer has no sign and cannot take one.
final lineSignsProvider = FutureProvider.autoDispose.family<Map<String, LineSign>, LineIds>((ref, lines) => ref.watch(bottleSignServiceProvider).lineSigns(lines.ids));
