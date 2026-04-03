import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();

  //Init
  
  // Note: Database setup is now handled manually through the setup screen
  // This prevents permission issues during app startup
  print('🚀 App initialized - Database setup available via debug tools');
  
  runApp(
    const ProviderScope(
      child: BottlesUpVendorApp(),
    ),
  );
}

class BottlesUpVendorApp extends ConsumerWidget {
  const BottlesUpVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Bottles Up Vendor',
      debugShowCheckedModeBanner: false,
      
      // Theming
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Force dark mode as requested
      
      // Routing
      routerConfig: router,
    );
  }
}
