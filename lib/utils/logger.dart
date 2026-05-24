import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

Logger getLogger(String name) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be shown
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.none, // Replaces deprecated printTime
    ),
  );
}

void configureLogger() {
  // Configure logger settings here if needed
  // For example, you might want to disable logging in release mode
  if (kReleaseMode) {
    Logger.level = Level.warning;
  } else {
    Logger.level = Level.verbose;
  }
}

// Extension to add log methods to Object
extension ObjectLogger on Object {
  void logInfo(String message) => getLogger(runtimeType.toString()).i(message);
  void logWarning(String message) =>
      getLogger(runtimeType.toString()).w(message);
  void logError(String message, {dynamic error, StackTrace? stackTrace}) =>
      getLogger(runtimeType.toString())
          .e(message, error: error, stackTrace: stackTrace);
  void logDebug(String message) => getLogger(runtimeType.toString()).d(message);
}
