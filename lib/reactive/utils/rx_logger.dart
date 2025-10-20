// lib/reactive/utils/rx_logger.dart
import '../../core/zen_logger.dart';
import '../../core/zen_config.dart';
import '../../core/zen_log_level.dart';
import '../core/rx_error_handling.dart';

/// Centralized logging utility for the reactive system
class RxLogger {
  /// Log an RxException with context
  static void logError(RxException error, {String? context}) {
    // Use ZenConfig.logLevel instead of getRxErrorConfig().logErrors
    if (!ZenLogLevel.error.shouldLog(ZenConfig.logLevel)) return;

    final config = getRxErrorConfig();
    if (config.customLogger != null) {
      config.customLogger!(error);
    } else {
      final prefix = context != null ? 'Rx$context Error' : 'RxError';
      ZenLogger.logError('$prefix: $error');
    }
  }

  /// Log a general reactive system message
  static void logInfo(String message, {String? context}) {
    if (!ZenLogLevel.info.shouldLog(ZenConfig.logLevel)) return;

    final prefix = context != null ? 'Rx$context' : 'Rx';
    ZenLogger.logInfo('$prefix: $message');
  }

  /// Log a warning message
  static void logWarning(String message, {String? context}) {
    if (!ZenLogLevel.warning.shouldLog(ZenConfig.logLevel)) return;

    final prefix = context != null ? 'Rx$context Warning' : 'RxWarning';
    ZenLogger.logWarning('$prefix: $message');
  }

  /// Log debug information (only in debug mode)
  static void logDebug(String message, {String? context}) {
    if (!ZenLogLevel.debug.shouldLog(ZenConfig.logLevel)) return;

    final prefix = context != null ? 'Rx$context Debug' : 'RxDebug';
    ZenLogger.logDebug('$prefix: $message');
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
