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
    late ZenLogLevel originalLogLevel;

    setUp(() {
      // Store original state
      originalLogLevel = ZenConfig.logLevel;

      // Set the custom log method
      ZenLogger.testMode = true;
      ZenLogger.logFunction = LogCapture.captureLog;

      // Enable all logs for testing using new log level system
      ZenConfig.logLevel = ZenLogLevel.trace;

      // Setup log capture
      capturedLogs = [];
      LogCapture.clear();

      // Set custom handlers for testing
      ZenLogger.init(logHandler: (String message, LogLevel level) {
        capturedLogs.add('[$level] $message');
      }, errorHandler: (String message,
          [dynamic error, StackTrace? stackTrace]) {
        capturedLogs.add('[error] $message');
        if (error != null) {
          capturedLogs.add('Error: $error');
        }
        if (stackTrace != null) {
          capturedLogs.add('StackTrace: Present');
        }
      });
    });

    tearDown(() {
      // Reset handlers
      ZenLogger.resetHandlers();

      // Restore log level
      ZenConfig.logLevel = originalLogLevel;
    });

    test('should log debug messages when debug logs are enabled', () {
      ZenConfig.logLevel = ZenLogLevel.trace;

      ZenLogger.logDebug('Debug message');
      ZenLogger.logInfo('Info message');
      ZenLogger.logWarning('Warning message');
      ZenLogger.logError('Error message');

      expect(capturedLogs.length, 4);
      expect(capturedLogs[0], contains('LogLevel.debug'));
      expect(capturedLogs[0], contains('Debug message'));
      expect(capturedLogs[1], contains('LogLevel.info'));
      expect(capturedLogs[1], contains('Info message'));
      expect(capturedLogs[2], contains('LogLevel.warning'));
      expect(capturedLogs[2], contains('Warning message'));
      expect(capturedLogs[3], contains('error'));
      expect(capturedLogs[3], contains('Error message'));
    });

    test('should not log debug messages when log level is too low', () {
      ZenConfig.logLevel = ZenLogLevel.info;

      ZenLogger.logDebug('Debug message');
      ZenLogger.logInfo('Info message');
      ZenLogger.logWarning('Warning message');
      ZenLogger.logError('Error message');

      // Debug should not be logged at info level
      expect(capturedLogs.length, 3);
      expect(capturedLogs[0], contains('LogLevel.info'));
      expect(capturedLogs[0], contains('Info message'));
      expect(capturedLogs[1], contains('LogLevel.warning'));
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
      ZenLogger.resetHandlers();
      LogCapture.clear();

      // Re-enable test mode
      ZenLogger.testMode = true;
      ZenLogger.logFunction = LogCapture.captureLog;

      // Test logging with fallback to internal log function
      ZenLogger.logInfo('Test message');

      // Verify log was created with fallback mechanism
      expect(LogCapture.logs.length, 1);
      expect(LogCapture.logs[0], contains('[Zenify] INFO: Test message'));
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
          errorHandler: (String message,
              [dynamic error, StackTrace? stackTrace]) {
            capturedLogs.add('Custom error handler: $message');
            if (error != null) {
              capturedLogs.add('Has error: true');
            }
            if (stackTrace != null) {
              capturedLogs.add('Has stack: true');
            }
          });

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
          errorHandler: null);

      ZenLogger.logInfo('Info with custom handler');
      ZenLogger.logWarning('Warning with custom handler');

      expect(capturedLogs.length, 2);
      expect(
          capturedLogs[0],
          contains(
              'Custom log handler: [LogLevel.info] Info with custom handler'));
      expect(
          capturedLogs[1],
          contains(
              'Custom log handler: [LogLevel.warning] Warning with custom handler'));
    });

    test(
        'should use log handler for errors when error handler is not available',
        () {
      // Clear captured logs
      capturedLogs.clear();

      // Setup with only log handler
      ZenLogger.init(
          logHandler: (String message, LogLevel level) {
            capturedLogs.add('Custom log handler: [$level] $message');
          },
          errorHandler: null);

      final error = Exception('Test error');
      final stack = StackTrace.current;

      ZenLogger.logError('Error with log handler', error, stack);

      // Should use log handler for all parts of the error
      expect(capturedLogs.length, 3);
      expect(
          capturedLogs[0],
          contains(
              'Custom log handler: [LogLevel.error] Error with log handler'));
      expect(
          capturedLogs[1],
          contains(
              'Custom log handler: [LogLevel.error] Error: Exception: Test error'));
      expect(capturedLogs[2],
          contains('Custom log handler: [LogLevel.error] StackTrace:'));
    });

    test('should respect log levels correctly', () {
      capturedLogs.clear();

      // Set to warning level
      ZenConfig.logLevel = ZenLogLevel.warning;

      ZenLogger.logDebug('Debug - should not appear');
      ZenLogger.logInfo('Info - should not appear');
      ZenLogger.logWarning('Warning - should appear');
      ZenLogger.logError('Error - should appear');

      // Only warning and error should be logged
      expect(capturedLogs.length, 2);
      expect(capturedLogs[0], contains('Warning'));
      expect(capturedLogs[1], contains('Error'));
    });

    test('should handle trace level correctly', () {
      capturedLogs.clear();

      ZenConfig.logLevel = ZenLogLevel.trace;

      ZenLogger.logTrace('Trace message');
      ZenLogger.logDebug('Debug message');

      expect(capturedLogs.length, 2);
      expect(capturedLogs[0], contains('Trace message'));
      expect(capturedLogs[1], contains('Debug message'));
    });

    test('should not log anything when level is none', () {
      capturedLogs.clear();

      ZenConfig.logLevel = ZenLogLevel.none;

      ZenLogger.logError('Error - should not appear');
      ZenLogger.logWarning('Warning - should not appear');
      ZenLogger.logInfo('Info - should not appear');

      expect(capturedLogs.length, 0);
    });

    test('should handle resetHandlers correctly', () {
      // Set handlers
      ZenLogger.init(
        logHandler: (msg, level) {},
        errorHandler: (msg, [err, stack]) {},
      );
      ZenLogger.testMode = true;
      ZenLogger.logFunction = LogCapture.captureLog;

      // Reset
      ZenLogger.resetHandlers();

      // Verify all cleared
      expect(ZenLogger.testMode, false);
      expect(ZenLogger.logFunction, isNull);
    });
  });
}
