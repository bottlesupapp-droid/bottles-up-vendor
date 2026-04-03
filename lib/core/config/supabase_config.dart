import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hwmynlghrmtoufyrcihp.supabase.co',
  );
  
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', 
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3bXlubGdocm10b3VmeXJjaWhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2Mzc3ODAsImV4cCI6MjA2NzIxMzc4MH0.1VpevdV-ReX7w3QCoM0xaPjSywusUtrbrtFk9AsWNAw',
  );
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
}