import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/walkin_rules.dart';
import '../services/walkin_service.dart';

final walkinServiceProvider = Provider<WalkinService>((ref) => WalkinService());

class WalkinQuery {
  const WalkinQuery(this.venueId, this.night);

  final String venueId;
  final String night;

  @override
  bool operator ==(Object other) => other is WalkinQuery && other.venueId == venueId && other.night == night;

  @override
  int get hashCode => Object.hash(venueId, night);
}

/// What is left to give a walk-in on one night. Never kept: a stale count is how a table is sold twice.
final walkinOptionsProvider =
    FutureProvider.autoDispose.family<List<WalkinSlot>, WalkinQuery>((ref, q) => ref.watch(walkinServiceProvider).options(q.venueId, q.night));
