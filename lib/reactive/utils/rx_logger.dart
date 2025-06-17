// lib/reactive/utils/rx_logger.dart
import 'package:flutter/foundation.dart';
import '../core/rx_error_handling.dart';

/// Centralized logging utility for the reactive system
class RxLogger {
  /// Log an RxException with context
  static void logError(RxException error, {String? context}) {
    if (!getRxErrorConfig().logErrors) return;

    final config = getRxErrorConfig();
    if (config.customLogger != null) {
      config.customLogger!(error);
    } else {
      final prefix = context != null ? 'Rx$context Error' : 'RxError';
      debugPrint('$prefix: $error');
    }
  }

  /// Log a general reactive system message
  static void logInfo(String message, {String? context}) {
    if (!getRxErrorConfig().logErrors) return; // Reuse the logErrors flag for general logging

    final prefix = context != null ? 'Rx$context' : 'Rx';
    debugPrint('$prefix: $message');
  }

  /// Log a warning message
  static void logWarning(String message, {String? context}) {
    if (!getRxErrorConfig().logErrors) return;

    final prefix = context != null ? 'Rx$context Warning' : 'RxWarning';
    debugPrint('$prefix: $message');
  }

  /// Log debug information (only in debug mode)
  static void logDebug(String message, {String? context}) {
    if (!kDebugMode || !getRxErrorConfig().logErrors) return;

    final prefix = context != null ? 'Rx$context Debug' : 'RxDebug';
    debugPrint('$prefix: $message');
  }

  /// Create an RxException and log it
  static RxException createAndLogError(
      String message, {
        Object? originalError,
        StackTrace? stackTrace,
        String? context,
      }) {
    final error = RxException.withTimestamp(
      message,
      originalError: originalError,
      stackTrace: stackTrace,
    );

    logError(error, context: context);
    return error;
  }
}