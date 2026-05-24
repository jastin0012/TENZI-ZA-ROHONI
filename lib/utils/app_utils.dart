import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/main_layout.dart';
import 'package:tenzi_za_rohoni/services/error_handler.dart';

/// A utility class for common app operations
class AppUtils {
  /// Shows a snackbar with the given message
  static void showSnackBar({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    try {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
    } catch (e, stack) {
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error showing snackbar',
      );
    }
  }

  /// Shows an error message to the user
  static void showError({
    required BuildContext context,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    ErrorHandler.instance.handleError(
      error: error,
      stackTrace: stackTrace,
      context: 'UI Error: $message',
      showUser: true,
      userMessage: message,
    );
    
    showSnackBar(
      context: context,
      message: message,
      backgroundColor: Colors.red,
    );
  }

  /// Wraps a widget with common error boundaries and safe area
  static Widget wrapWithErrorBoundary({
    required Widget child,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return ErrorBoundary(
      errorBuilder: errorBuilder ?? _defaultErrorBuilder,
      child: SafeArea(
        child: child,
      ),
    );
  }

  /// Default error builder for error boundaries
  static Widget _defaultErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (!kReleaseMode) ...[
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Try to recover by rebuilding the widget
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const MainLayout(),
                        ),
                      );
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension methods for BuildContext
extension ContextExtensions on BuildContext {
  /// Shows a snackbar with the given message
  void showSnackBar({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    AppUtils.showSnackBar(
      context: this,
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  /// Shows an error message
  void showError({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    AppUtils.showError(
      context: this,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
