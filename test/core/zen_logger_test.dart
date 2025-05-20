// test/core/zen_logger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Create a testable version of the logger that captures log output
class LogCapture {
  static final List<String> logs = [];

  static void captureLog(String message, {String? name}) {
    logs.add('${name ?? ''}: $message');
  }

  static void clear() {
    logs.clear();
  }
}

void main() {
  group('ZenLogger', () {
    // Capture log output
    late List<String> capturedLogs;
    late bool originalDebugLogsEnabled;

    setUp(() {
      // Store original state
      originalDebugLogsEnabled = ZenConfig.enableDebugLogs;

      // Set the custom log method
      ZenLogger.testMode = true;
      ZenLogger.logFunction = LogCapture.captureLog;

      // Enable debug logs for testing
      ZenConfig.enableDebugLogs = true;

      // Setup log capture
      capturedLogs = [];
      LogCapture.clear();

      // Set custom handlers for testing
      ZenLogger.init(
          logHandler: (String message, LogLevel level) {
            capturedLogs.add('[$level] $message');
          },
          errorHandler: (String message, [dynamic error, StackTrace? stackTrace]) {
            capturedLogs.add('[error] $message');
            if (error != null) {
              capturedLogs.add('Error: $error');
            }
            if (stackTrace != null) {
              capturedLogs.add('StackTrace: Present');
            }
          }
      );
    });

    tearDown(() {
      // Reset handlers to null
      ZenLogger.init(
        logHandler: null,
        errorHandler: null,
      );

      // Reset test mode
      ZenLogger.testMode = false;
      ZenLogger.logFunction = null;

      // Restore debug logs setting
      ZenConfig.enableDebugLogs = originalDebugLogsEnabled;
    });

    test('should log debug messages when debug logs are enabled', () {
      ZenConfig.enableDebugLogs = true;

      ZenLogger.logDebug('Debug message');
      ZenLogger.logInfo('Info message');
      ZenLogger.logWarning('Warning message');
      ZenLogger.logError('Error message');

      expect(capturedLogs.length, 4);
      expect(capturedLogs[0], contains('debug'));
      expect(capturedLogs[0], contains('Debug message'));
      expect(capturedLogs[1], contains('info'));
      expect(capturedLogs[1], contains('Info message'));
      expect(capturedLogs[2], contains('warning'));
      expect(capturedLogs[2], contains('Warning message'));
      expect(capturedLogs[3], contains('error'));
      expect(capturedLogs[3], contains('Error message'));
    });

    test('should not log debug messages when debug logs are disabled', () {
      ZenConfig.enableDebugLogs = false;

      ZenLogger.logDebug('Debug message');
      ZenLogger.logInfo('Info message');
      ZenLogger.logWarning('Warning message');
      ZenLogger.logError('Error message');

      expect(capturedLogs.length, 3);
      expect(capturedLogs[0], contains('info'));
      expect(capturedLogs[0], contains('Info message'));
      expect(capturedLogs[1], contains('warning'));
      expect(capturedLogs[1], contains('Warning message'));
      expect(capturedLogs[2], contains('error'));
      expect(capturedLogs[2], contains('Error message'));
    });

    test('should handle errors and stack traces', () {
      final error = Exception('Test exception');
      final stackTrace = StackTrace.current;

      ZenLogger.logError('Error with exception', error, stackTrace);

      expect(capturedLogs.length, 3);
      expect(capturedLogs[0], contains('Error with exception'));
      expect(capturedLogs[1], contains('Test exception'));
      expect(capturedLogs[2], contains('StackTrace: Present'));
    });

    test('should fallback to internal logging when no handler is set', () {
      // Remove custom handlers
      ZenLogger.init(logHandler: null, errorHandler: null);
      LogCapture.clear();

      // Test logging with fallback to internal log function
      ZenLogger.logInfo('Test message');

      // Verify log was created with fallback mechanism
      expect(LogCapture.logs.length, 1);
      expect(LogCapture.logs[0], contains('ZEN INFO: Test message'));
    });

    test('should handle null values gracefully', () {
      ZenLogger.logError('Error with null values', null, null);

      expect(capturedLogs.length, 1);
      expect(capturedLogs[0], contains('Error with null values'));
    });

    test('should use error handler for errors when available', () {
      // Clear captured logs
      capturedLogs.clear();

      // Setup with only error handler
      ZenLogger.init(
          logHandler: null,
          errorHandler: (String message, [dynamic error, StackTrace? stackTrace]) {
            capturedLogs.add('Custom error handler: $message');
            if (error != null) {
              capturedLogs.add('Has error: true');
            }
            if (stackTrace != null) {
              capturedLogs.add('Has stack: true');
            }
          }
      );

      final error = Exception('Custom error');
      final stack = StackTrace.current;

      ZenLogger.logError('Error message', error, stack);

      expect(capturedLogs.length, 3);
      expect(capturedLogs[0], contains('Custom error handler: Error message'));
      expect(capturedLogs[1], contains('Has error: true'));
      expect(capturedLogs[2], contains('Has stack: true'));
    });

    test('should use log handler for non-error logs', () {
      // Clear captured logs
      capturedLogs.clear();

      // Setup with only log handler
      ZenLogger.init(
          logHandler: (String message, LogLevel level) {
            capturedLogs.add('Custom log handler: [$level] $message');
          },
          errorHandler: null
      );

      ZenLogger.logInfo('Info with custom handler');
      ZenLogger.logWarning('Warning with custom handler');

      expect(capturedLogs.length, 2);
      expect(capturedLogs[0], contains('Custom log handler: [info] Info with custom handler'));
      expect(capturedLogs[1], contains('Custom log handler: [warning] Warning with custom handler'));
    });

    test('should use log handler for errors when error handler is not available', () {
      // Clear captured logs
      capturedLogs.clear();

      // Setup with only log handler
      ZenLogger.init(
          logHandler: (String message, LogLevel level) {
            capturedLogs.add('Custom log handler: [$level] $message');
          },
          errorHandler: null
      );

      final error = Exception('Test error');
      final stack = StackTrace.current;

      ZenLogger.logError('Error with log handler', error, stack);

      // Should use log handler for all parts of the error
      expect(capturedLogs.length, 3);
      expect(capturedLogs[0], contains('Custom log handler: [error] Error with log handler'));
      expect(capturedLogs[1], contains('Custom log handler: [error] Error: Exception: Test error'));
      expect(capturedLogs[2], contains('Custom log handler: [error] StackTrace:'));
    });
  });
}