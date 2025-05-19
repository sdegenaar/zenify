// lib/zen_state/zen_logger.dart
import 'dart:developer' as developer;
import 'zen_config.dart';

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error;

  @override
  String toString() => name;
}


/// Centralized logging system for ZenState
class ZenLogger {
  ZenLogger._(); // Private constructor

  /// Log handlers
  static void Function(String message, LogLevel level)? _logHandler;
  static void Function(String message, [dynamic error, StackTrace? stackTrace])? _errorHandler;

  /// Test mode flag
  static bool testMode = false;

  /// Custom log function for testing
  static void Function(String message, {String? name})? logFunction;

  /// Initialize the logger with custom handlers
  static void init({
    void Function(String message, LogLevel level)? logHandler,
    void Function(String message, [dynamic error, StackTrace?])? errorHandler,
  }) {
    _logHandler = logHandler;
    _errorHandler = errorHandler;
  }

  /// Log a debug message (only in debug mode)
  static void logDebug(String message) {
    if (!ZenConfig.enableDebugLogs) return;

    if (_logHandler != null) {
      _logHandler!(message, LogLevel.debug);
    } else {
      _log('DEBUG', message);
    }
  }

  /// Log an info message
  static void logInfo(String message) {
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.info);
    } else {
      _log('INFO', message);
    }
  }

  /// Log a warning message
  static void logWarning(String message) {
    if (_logHandler != null) {
      _logHandler!(message, LogLevel.warning);
    } else {
      _log('WARNING', message);
    }
  }

  /// Log an error message with optional error object and stack trace
  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_errorHandler != null) {
      _errorHandler!(message, error, stackTrace);
    } else if (_logHandler != null) {
      _logHandler!(message, LogLevel.error);
      if (error != null) _logHandler!('Error: $error', LogLevel.error);
      if (stackTrace != null) _logHandler!('StackTrace: $stackTrace', LogLevel.error);
    } else {
      _log('ERROR', message);
      if (error != null) _log('ERROR', 'Error: $error');
      if (stackTrace != null) _log('ERROR', 'StackTrace: $stackTrace');
    }
  }

  /// Internal logging method that avoids direct print statements
  static void _log(String level, String message) {
    // Use custom log function in test mode
    if (testMode && logFunction != null) {
      logFunction!('ZEN $level: $message', name: 'ZenState');
    } else {
      // Use developer.log in debug mode, which shows up in dev tools
      // but doesn't trigger the avoid_print lint
      developer.log('ZEN $level: $message', name: 'ZenState');
    }
  }
}