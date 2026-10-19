import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/door_staff_rules.dart';
import '../services/door_staff_service.dart';

final doorStaffServiceProvider = Provider<DoorStaffService>((ref) => DoorStaffService());

final eventDoorStatusProvider = FutureProvider.autoDispose.family<List<EventDoorStatus>, String>((ref, orgId) => ref.watch(doorStaffServiceProvider).status(orgId));
final doorPermissionsProvider = FutureProvider.autoDispose.family<List<DoorPermission>, String>((ref, venueId) => ref.watch(doorStaffServiceProvider).permissions(venueId));
final clubDoorStaffProvider = FutureProvider.autoDispose.family<List<ClubDoorStaff>, String>((ref, venueId) => ref.watch(doorStaffServiceProvider).clubStaff(venueId));
