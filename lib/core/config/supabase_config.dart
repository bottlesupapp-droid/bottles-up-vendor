import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    // Validate required environment variables
    if (url.isEmpty) {
      throw Exception(
        'SUPABASE_URL is not configured!\n'
        'Please run with: flutter run --dart-define-from-file=env.json\n'
        'See env.example.json for required configuration.',
      );
    }

    if (anonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY is not configured!\n'
        'Please run with: flutter run --dart-define-from-file=env.json\n'
        'See env.example.json for required configuration.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
}