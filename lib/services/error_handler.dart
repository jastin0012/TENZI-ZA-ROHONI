import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

/// Centralized error handling service
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  static ErrorHandler get instance => _instance;

  final Logger _logger = Logger();
  final List<ErrorInfo> _errors = [];
  final StreamController<ErrorInfo> _errorController =
      StreamController<ErrorInfo>.broadcast();

  ErrorHandler._internal() {
    // Simple logger is used for diagnostics in this app.
    // Detailed record routing (Logger.root) from `package:logging` is not used
    // to avoid depending on that package. Use debugPrint for low-level output.
  }

  /// Handle an error with optional context
  void handleError({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    bool showUser = false,
    String? userMessage,
  }) {
    final errorInfo = ErrorInfo(
      error: error,
      stackTrace: stackTrace,
      context: context,
      timestamp: DateTime.now(),
    );

    // Log the error using package:logger's API and also print details
    final msg = context ?? 'An error occurred';
    _logger.e(msg);
    if (error != null) {
      getLogger('ErrorHandler').e('Error: $error', error: error);
    }
    if (stackTrace != null) {
      getLogger('ErrorHandler').d('Stack trace: $stackTrace');
    }

    // Store the error
    _errors.add(errorInfo);

    // Notify listeners
    _errorController.add(errorInfo);

    // Show user-friendly message if needed
    if (showUser) {
      _showErrorToUser(userMessage ?? 'An error occurred. Please try again.');
    }
  }

  /// Get a stream of errors
  Stream<ErrorInfo> get errorStream => _errorController.stream;

  /// Get all recorded errors
  List<ErrorInfo> get errors => List.unmodifiable(_errors);

  /// Show error to user using a snackbar
  void _showErrorToUser(String message, {BuildContext? context}) {
    // This can be expanded to show dialogs, snackbars, etc.
    getLogger('ErrorHandler').w('User-facing error: $message');

    // If we have a context, we can show a snackbar
    if (context != null) {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Clean up resources
  void dispose() {
    _errorController.close();
  }
}

/// Class to hold error information
class ErrorInfo {
  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final DateTime timestamp;

  ErrorInfo({
    required this.error,
    this.stackTrace,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ErrorInfo{\n'
        '  error: $error,\n'
        '  context: $context,\n'
        '  timestamp: $timestamp\n'
        '  stackTrace: $stackTrace\n'
        '}';
  }
}

/// Error boundary widget to catch and handle errors in the widget tree
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(
      BuildContext context, Object error, StackTrace? stackTrace) errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder(context, _error!, _stackTrace);
    }
    return widget.child;
  }

  // Note: Flutter's State class does not provide a didCatch override.
  // Errors are handled globally via FlutterError.onError or using try/catch
  // around individual futures. The boundary will render error UI when
  // _error is set by callers.
}

/// Helper function to run code with error handling
Future<T> runWithErrorHandling<T>(
  Future<T> Function() action, {
  String? context,
  bool showUser = false,
  String? userMessage,
}) async {
  try {
    return await action();
  } catch (error, stackTrace) {
    ErrorHandler.instance.handleError(
      error: error,
      stackTrace: stackTrace,
      context: context,
      showUser: showUser,
      userMessage: userMessage,
    );
    rethrow;
  }
}
