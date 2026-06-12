import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error handling utility for the application
///
/// Provides consistent error messages and logging across the app
class ErrorHandler {
  /// Private constructor to prevent instantiation
  ErrorHandler._();

  /// Handle Supabase errors and return user-friendly messages
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return _handleAuthException(error);
    } else if (error is PostgrestException) {
      return _handlePostgrestException(error);
    } else if (error is StorageException) {
      return _handleStorageException(error);
    } else if (error is Exception) {
      final message = error.toString();
      if (message.contains('Failed host lookup')) {
        return 'No internet connection. Please check your network.';
      } else if (message.contains('Connection refused')) {
        return 'Cannot connect to server. Please try again later.';
      } else if (message.contains('timeout')) {
        return 'Request timed out. Please try again.';
      }
      return 'An unexpected error occurred. Please try again.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Handle authentication errors
  static String _handleAuthException(AuthException error) {
    switch (error.statusCode) {
      case '400':
        if (error.message.contains('Invalid login credentials')) {
          return 'Invalid email or password.';
        } else if (error.message.contains('Email not confirmed')) {
          return 'Please verify your email address.';
        }
        return 'Invalid request. Please check your input.';
      case '401':
        return 'Unauthorized. Please log in again.';
      case '403':
        return 'Access denied.';
      case '422':
        if (error.message.contains('already registered')) {
          return 'This email is already registered.';
        }
        return 'Validation error. Please check your input.';
      case '429':
        return 'Too many requests. Please wait a moment and try again.';
      case '500':
        return 'Server error. Please try again later.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Authentication error. Please try again.';
    }
  }

  /// Handle database errors
  static String _handlePostgrestException(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    // Foreign key violations
    if (code == '23503' || message.contains('foreign key')) {
      return 'Cannot delete: This item is referenced by other records.';
    }

    // Unique constraint violations
    if (code == '23505' || message.contains('unique')) {
      return 'This record already exists.';
    }

    // Row level security violations
    if (code == '42501' || message.contains('row-level security')) {
      return 'You do not have permission to perform this action.';
    }

    // Not found
    if (code == 'PGRST116' || message.contains('not found')) {
      return 'Record not found.';
    }

    // Check constraint violations
    if (code == '23514' || message.contains('check constraint')) {
      return 'Invalid data: Please check your input values.';
    }

    return error.message.isNotEmpty
        ? error.message
        : 'Database error. Please try again.';
  }

  /// Handle storage errors
  static String _handleStorageException(StorageException error) {
    final message = error.message.toLowerCase();

    if (message.contains('file size')) {
      return 'File is too large. Please choose a smaller file.';
    } else if (message.contains('file type')) {
      return 'Invalid file type. Please choose a different file.';
    } else if (message.contains('not found')) {
      return 'File not found.';
    } else if (message.contains('permission')) {
      return 'You do not have permission to access this file.';
    }

    return error.message.isNotEmpty
        ? error.message
        : 'File upload error. Please try again.';
  }

  /// Show error snackbar to user
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getErrorMessage(error);

    // Log error for debugging (production: send to crash reporting)
    // TODO: Replace with Sentry/Crashlytics in production
    debugPrint('ERROR: $error');
    if (error is Error) {
      debugPrint('STACK TRACE: ${error.stackTrace}');
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error dialog to user
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final message = getErrorMessage(error);

    // Log error for debugging
    // TODO: Replace with Sentry/Crashlytics in production
    debugPrint('ERROR: $error');
    if (error is Error) {
      debugPrint('STACK TRACE: ${error.stackTrace}');
    }

    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Error'),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Handle async operations with consistent error handling
  ///
  /// Example:
  /// ```dart
  /// await ErrorHandler.handleAsync(
  ///   context,
  ///   operation: () => myAsyncFunction(),
  ///   onSuccess: (result) => print('Success!'),
  ///   onError: () => print('Failed'),
  /// );
  /// ```
  static Future<T?> handleAsync<T>(
    BuildContext context, {
    required Future<T> Function() operation,
    void Function(T result)? onSuccess,
    VoidCallback? onError,
    bool showLoadingIndicator = false,
  }) async {
    try {
      final result = await operation();
      onSuccess?.call(result);
      return result;
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e);
      }
      onError?.call();
      return null;
    }
  }

  /// Sanitize error messages to remove sensitive information
  /// before logging in production
  static String sanitizeErrorMessage(String message) {
    // Remove email addresses
    message = message.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      '[EMAIL]',
    );

    // Remove UUIDs
    message = message.replaceAll(
      RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'),
      '[UUID]',
    );

    // Remove phone numbers (basic pattern)
    message = message.replaceAll(
      RegExp(r'\+?[\d\s\-\(\)]{10,}'),
      '[PHONE]',
    );

    // Remove potential tokens/keys (long alphanumeric strings)
    message = message.replaceAll(
      RegExp(r'\b[A-Za-z0-9]{32,}\b'),
      '[TOKEN]',
    );

    return message;
  }
}
