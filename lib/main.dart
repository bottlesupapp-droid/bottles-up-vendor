import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/supabase_config.dart';
import 'core/crash/crash_reporting.dart';
import 'core/startup/startup_error_app.dart';
import 'core/utils/error_handler.dart';

void main() {
  // Catch errors from async gaps - must wrap everything including initialization
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Global error boundary for uncaught errors. Set before start-up so errors
      // raised while initializing are logged too.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _logError(details.exception, details.stack);
      };

      // Crash reporting wraps the start-up when the build has a SENTRY_DSN; otherwise this is just _start().
      await runWithCrashReporting(appRunner: _start);
    },
    (error, stack) {
      _logError(error, stack);
    },
  );
}

/// Initializes the backend and launches the app. If initialization fails the user
/// gets a retry screen rather than a blank one.
Future<void> _start() async {
  try {
    await SupabaseConfig.initialize();
  } catch (error, stack) {
    _logError(error, stack);
    runApp(StartupErrorApp(onRetry: _start));
    return;
  }

  runApp(
    const ProviderScope(
      child: BottlesUpVendorApp(),
    ),
  );
}

/// Log errors for debugging. Crash reporting itself (Sentry, when the build has a SENTRY_DSN) hooks the framework and zone
/// handlers on its own, so uncaught errors are NOT sent from here a second time.
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
