// lib/core/zen_logger.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'zen_config.dart';
import 'zen_log_level.dart';

/// Log level enum for custom handlers
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Logging utility for Zenify framework
class ZenLogger {
  ZenLogger._();

  static const String _prefix = '[Zenify]';

  // Custom handlers for testing/override
  static void Function(String message, LogLevel level)? _logHandler;
  static void Function(String message, [dynamic error, StackTrace? stackTrace])?
      _errorHandler;

  // Test mode support
  static bool testMode = false;
  static void Function(String message, {String? name})? logFunction;

  /// Initialize with custom handlers (for testing)
  static void init({
    void Function(String message, LogLevel level)? logHandler,
    void Function(String message, [dynamic error, StackTrace? stackTrace])?
        errorHandler,
  }) {
    _logHandler = logHandler;
    _errorHandler = errorHandler;
  }

  /// Log an error message (always logged unless level is none)
  static void logError(String message,
      [Object? error, StackTrace? stackTrace]) {
    if (!ZenLogLevel.error.shouldLog(ZenConfig.logLevel)) return;

    // Use custom error handler if set
    if (_errorHandler != null) {
      _errorHandler!(message, error, stackTrace);
      return;
    }

    // Use custom log handler if set (for errors when error handler not available)
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.error);
      if (error != null) {
        _logHandler!('Error: $error', LogLevel.error);
      }
      if (stackTrace != null) {
        _logHandler!('StackTrace: $stackTrace', LogLevel.error);
      }
      return;
    }

    // Default logging
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix ERROR');
      } else {
        developer.log(
          message,
          name: '$_prefix ERROR',
          error: error,
          stackTrace: stackTrace,
          level: 1000, // Error level
        );
      }
    }
  }

  /// Log a ZenException with beautiful formatting
  ///
  /// This method automatically formats ZenException instances using their
  /// toString() method, which respects ZenConfig.verboseErrors setting.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final service = Zen.find<UserService>();
  /// } catch (e) {
  ///   if (e is ZenException) {
  ///     ZenLogger.logException(e);
  ///   }
  /// }
  /// ```
  static void logException(Object exception, [StackTrace? stackTrace]) {
    if (!ZenLogLevel.error.shouldLog(ZenConfig.logLevel)) return;

    // Format the exception message
    final message = exception.toString();

    // Use custom error handler if set
    if (_errorHandler != null) {
      _errorHandler!(message, exception, stackTrace);
      return;
    }

    // Use custom log handler if set
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.error);
      return;
    }

    // Default logging with formatted output
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix EXCEPTION');
      } else {
        developer.log(
          message,
          name: '$_prefix EXCEPTION',
          error: exception,
          stackTrace: stackTrace,
          level: 1000, // Error level
        );
      }
    }
  }

  /// Log a warning message
  static void logWarning(String message) {
    if (!ZenLogLevel.warning.shouldLog(ZenConfig.logLevel)) return;

    // Use custom handler if set
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.warning);
      return;
    }

    // Default logging
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix WARNING');
      } else {
        developer.log(
          message,
          name: '$_prefix WARNING',
          level: 900, // Warning level
        );
      }
    }
  }

  /// Log an info message (general information)
  static void logInfo(String message) {
    if (!ZenLogLevel.info.shouldLog(ZenConfig.logLevel)) return;

    // Use custom handler if set
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.info);
      return;
    }

    // Default logging
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix INFO');
      } else {
        developer.log(
          message,
          name: '$_prefix INFO',
          level: 800, // Info level
        );
      }
    }
  }

  /// Log a debug message (detailed debug information)
  static void logDebug(String message) {
    if (!ZenLogLevel.debug.shouldLog(ZenConfig.logLevel)) return;

    // Use custom handler if set
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.debug);
      return;
    }

    // Default logging
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix DEBUG');
      } else {
        developer.log(
          message,
          name: '$_prefix DEBUG',
          level: 700, // Debug level
        );
      }
    }
  }

  /// Log a trace message (very verbose, framework internals)
  static void logTrace(String message) {
    if (!ZenLogLevel.trace.shouldLog(ZenConfig.logLevel)) return;

    // Use custom handler if set
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.debug); // Map to debug level for handler
      return;
    }

    // Default logging
    if (kDebugMode) {
      if (testMode && logFunction != null) {
        logFunction!(message, name: '$_prefix TRACE');
      } else {
        developer.log(
          message,
          name: '$_prefix TRACE',
          level: 500, // Trace level
        );
      }
    }
  }

  /// Log Rx tracking messages (controlled by separate flag)
  /// ⚠️ This is VERY verbose and should only be enabled for debugging Rx issues
  static void logRxTracking(String message) {
    // Double check: kDebugMode AND enableRxTracking must both be true
    if (!kDebugMode || !ZenConfig.enableRxTracking) return;

    // RxTracking uses its own custom logging path (not affected by handlers)
    if (testMode && logFunction != null) {
      logFunction!('RxTracking: $message', name: '$_prefix RX');
    } else {
      developer.log(
        'RxTracking: $message',
        name: '$_prefix RX',
        level: 300, // Very verbose
      );
    }
  }

  /// Reset handlers (useful for testing cleanup)
  static void resetHandlers() {
    _logHandler = null;
    _errorHandler = null;
    testMode = false;
    logFunction = null;
  }
}
