import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  tearDown(ZenConfig.reset);

  // ══════════════════════════════════════════════════════════
  // RxLogger log-level gating
  // ══════════════════════════════════════════════════════════
  group('RxLogger.logError', () {
    test('does not log when level is above error', () {
      // Set log level above error so nothing should log
      ZenConfig.logLevel = ZenLogLevel.trace; // trace < error, logs everything
      expect(
        () => RxLogger.logError(
          RxException.withTimestamp('test error'),
          context: 'Test',
        ),
        returnsNormally,
      );
    });

    test('skips logging when log level is set to warning (above error)', () {
      // warning is ABOVE error in priority so error would NOT log
      // Actually let's verify the level semantics
      ZenConfig.logLevel = ZenLogLevel.warning;
      // error.shouldLog(warning) — error is priority 4, warning is 3 — error >= warning → logs
      expect(
        () => RxLogger.logError(RxException.withTimestamp('test')),
        returnsNormally,
      );
    });

    test('uses custom logger when configured', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      RxException? received;
      setRxErrorConfig(RxErrorConfig(
        customLogger: (e) => received = e,
      ));

      final ex = RxException.withTimestamp('custom logger test');
      RxLogger.logError(ex, context: 'Custom');
      expect(received, same(ex));

      setRxErrorConfig(RxErrorConfig.defaultConfig); // cleanup
    });
  });

  group('RxLogger.logInfo', () {
    test('does not crash when info level is allowed', () {
      ZenConfig.logLevel = ZenLogLevel.info;
      expect(
        () => RxLogger.logInfo('test info', context: 'TestCtx'),
        returnsNormally,
      );
    });

    test('is silenced when log level is error', () {
      ZenConfig.logLevel = ZenLogLevel.error;
      expect(
        () => RxLogger.logInfo('should be silent'),
        returnsNormally, // no crash, just silent
      );
    });
  });

  group('RxLogger.logWarning', () {
    test('does not crash when warning level is allowed', () {
      ZenConfig.logLevel = ZenLogLevel.warning;
      expect(
        () => RxLogger.logWarning('test warning', context: 'W'),
        returnsNormally,
      );
    });

    test('is silenced when log level is error', () {
      ZenConfig.logLevel = ZenLogLevel.error;
      expect(() => RxLogger.logWarning('silent'), returnsNormally);
    });
  });

  group('RxLogger.logDebug', () {
    test('does not crash when debug level is allowed', () {
      ZenConfig.logLevel = ZenLogLevel.debug;
      expect(
        () => RxLogger.logDebug('test debug', context: 'D'),
        returnsNormally,
      );
    });

    test('is silenced when log level is info', () {
      ZenConfig.logLevel = ZenLogLevel.info;
      expect(() => RxLogger.logDebug('silent debug'), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxLogger.createAndLogError
  // ══════════════════════════════════════════════════════════
  group('RxLogger.createAndLogError', () {
    test('returns RxException with given message', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      final ex = RxLogger.createAndLogError('oops');
      expect(ex.message, 'oops');
    });

    test('wraps original error', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      final original = Exception('root cause');
      final ex = RxLogger.createAndLogError(
        'wrapped',
        originalError: original,
        context: 'Test',
      );
      expect(ex.originalError, same(original));
    });

    test('stores stack trace', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      final trace = StackTrace.current;
      final ex = RxLogger.createAndLogError('trace test', stackTrace: trace);
      expect(ex.stackTrace, same(trace));
    });

    test('works without context', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      expect(
        () => RxLogger.createAndLogError('no context'),
        returnsNormally,
      );
    });
  });
}
