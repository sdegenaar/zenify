// lib/zen_state/zen_logger.dart
import 'zen_config.dart';

/// Log levels
enum LogLevel { debug, info, warning, error }

/// Centralized logging system for ZenState
class ZenLogger {
  ZenLogger._(); // Private constructor

  /// Log handlers
  static void Function(String message, LogLevel level)? _logHandler;
  static void Function(String message, [dynamic error, StackTrace? stackTrace])? _errorHandler;

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
  print('ZEN DEBUG: $message');
  }
  }

  /// Log an info message
  static void logInfo(String message) {
  if (_logHandler != null) {
  _logHandler!(message, LogLevel.info);
  } else {
  print('ZEN INFO: $message');
  }
  }

  /// Log a warning message
  static void logWarning(String message) {
  if (_logHandler != null) {
  _logHandler!(message, LogLevel.warning);
  } else {
  print('ZEN WARNING: $message');
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
  print('ZEN ERROR: $message');
  if (error != null) print('Error: $error');
  if (stackTrace != null) print('StackTrace: $stackTrace');
  }
  }
}