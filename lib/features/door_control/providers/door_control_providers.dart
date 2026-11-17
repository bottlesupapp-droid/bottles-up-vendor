import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/door_control_rules.dart';
import '../services/door_control_service.dart';

final doorControlServiceProvider = Provider<DoorControlService>((ref) => DoorControlService());

/// The club's nights. Not kept: a figure from a minute ago is not what a manager at the door needs.
final clubNightsProvider = FutureProvider.autoDispose.family<List<ClubNight>, String>((ref, venueId) => ref.watch(doorControlServiceProvider).nights(venueId));

/// The overrides recorded for a night.
final overrideLogProvider = FutureProvider.autoDispose.family<List<OverrideLogEntry>, String>((ref, eventId) => ref.watch(doorControlServiceProvider).log(eventId));
