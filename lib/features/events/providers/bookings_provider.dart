import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
 
final bookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.getAllBookings();
}); 