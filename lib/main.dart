import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Global error boundary for uncaught errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logError(details.exception, details.stack);
  };

  // Catch errors from async gaps
  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: BottlesUpVendorApp(),
        ),
      );
    },
    (error, stack) {
      _logError(error, stack);
    },
  );
}

/// Log errors for debugging and crash reporting
/// TODO: Replace debugPrint with Sentry/Crashlytics in production
void _logError(Object error, StackTrace? stack) {
  // Sanitize error message before logging
  final sanitized = ErrorHandler.sanitizeErrorMessage(error.toString());

  debugPrint('═══════════════════════════════════════');
  debugPrint('UNCAUGHT ERROR: $sanitized');
  if (stack != null) {
    debugPrint('STACK TRACE:');
    debugPrint(stack.toString());
  }
  debugPrint('═══════════════════════════════════════');

  // TODO: Send to crash reporting service in production
  // Example:
  // Sentry.captureException(error, stackTrace: stack);
  // or
  // FirebaseCrashlytics.instance.recordError(error, stack);
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
