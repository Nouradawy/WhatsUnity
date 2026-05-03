import 'package:flutter/foundation.dart';

/// A utility class for controlled logging across the application.
/// 
/// Logs are only outputted in debug mode ([kDebugMode]).
/// In release builds, all logging methods are effectively no-ops.
class AppLogger {
  AppLogger._();

  /// Logs a debug message.
  /// [tag] should usually be the class or page name.
  static void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('[DEBUG]$prefix $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Logs an error message.
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('[ERROR]$prefix $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Logs an informational message.
  static void i(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('[INFO]$prefix $message');
    }
  }

  /// Logs a warning message.
  static void w(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('[WARN]$prefix $message');
    }
  }
}
