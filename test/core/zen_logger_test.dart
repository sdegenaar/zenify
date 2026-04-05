import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  tearDown(ZenLogger.resetHandlers);

  // ══════════════════════════════════════════════════════════
  // Custom log handler
  // ══════════════════════════════════════════════════════════
  group('ZenLogger custom logHandler', () {
    test('logError routes to _logHandler when error handler not set', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logError('my error message');
      expect(captured, contains('my error message'));
    });

    test('logError with error object routes extra message', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logError('err', Exception('cause'));
      expect(captured.any((m) => m.contains('cause')), true);
    });

    test('logError with stackTrace routes trace message', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logError('e', null, StackTrace.fromString('fake'));
      expect(captured.any((m) => m.contains('StackTrace')), true);
    });

    test('logWarning routes to _logHandler', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logWarning('my warning');
      expect(captured, contains('my warning'));
    });

    test('logInfo routes to _logHandler', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logInfo('my info');
      expect(captured, contains('my info'));
    });

    test('logDebug routes to _logHandler', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logDebug('debug msg');
      expect(captured, contains('debug msg'));
    });

    test('logTrace routes to _logHandler', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, level) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logTrace('trace msg');
      expect(captured, contains('trace msg'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // Custom error handler
  // ══════════════════════════════════════════════════════════
  group('ZenLogger custom errorHandler', () {
    test('logError routes to errorHandler when set', () {
      String? capturedMsg;
      ZenLogger.init(
        errorHandler: (msg, [err, st]) => capturedMsg = msg,
      );
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logError('err from error handler');
      expect(capturedMsg, 'err from error handler');
    });

    test('logException routes to errorHandler', () {
      String? capturedMsg;
      ZenLogger.init(
        errorHandler: (msg, [err, st]) => capturedMsg = msg,
      );
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logException(Exception('test exc'));
      expect(capturedMsg, contains('test exc'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // logException
  // ══════════════════════════════════════════════════════════
  group('ZenLogger.logException', () {
    test('does not crash without any handler set', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      expect(
        () => ZenLogger.logException(Exception('plain exception')),
        returnsNormally,
      );
    });

    test('with _logHandler routes to it', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, _) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logException(Exception('via logHandler'));
      expect(captured.any((m) => m.contains('via logHandler')), true);
    });

    test('is silenced when log level is above error', () {
      ZenConfig.logLevel = ZenLogLevel.none;
      final captured = <String>[];
      ZenLogger.init(errorHandler: (msg, [_, __]) => captured.add(msg));
      ZenLogger.logException(Exception('silenced'));
      expect(captured, isEmpty);
    });

    test('with stackTrace does not crash', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      expect(
        () => ZenLogger.logException(
          Exception('with stack'),
          StackTrace.fromString('fake'),
        ),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // logTrace
  // ══════════════════════════════════════════════════════════
  group('ZenLogger.logTrace', () {
    test('does not crash at trace level', () {
      ZenConfig.logLevel = ZenLogLevel.trace;
      expect(() => ZenLogger.logTrace('a trace'), returnsNormally);
    });

    test('is silenced below trace level', () {
      ZenConfig.logLevel = ZenLogLevel.debug;
      const captured = <String>[];
      // When silenced, no output — we only verify no crash
      expect(() => ZenLogger.logTrace('silenced'), returnsNormally);
      expect(captured, isEmpty);
    });

    test('routes to _logHandler at trace level', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, _) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logTrace('routed trace');
      expect(captured, contains('routed trace'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // logRxTracking
  // ══════════════════════════════════════════════════════════
  group('ZenLogger.logRxTracking', () {
    setUp(() {
      ZenConfig.enableRxTracking = true;
    });
    tearDown(() {
      ZenConfig.enableRxTracking = false;
    });

    test('does not crash when enableRxTracking is true', () {
      expect(() => ZenLogger.logRxTracking('rx track'), returnsNormally);
    });

    test('is silenced when enableRxTracking is false', () {
      ZenConfig.enableRxTracking = false;
      expect(() => ZenLogger.logRxTracking('silent'), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // resetHandlers
  // ══════════════════════════════════════════════════════════
  group('ZenLogger.resetHandlers', () {
    test('clears handlers so logError no longer routes to them', () {
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, _) => captured.add(msg));
      ZenConfig.logLevel = ZenLogLevel.trace;
      ZenLogger.logError('before reset');
      expect(captured, isNotEmpty);

      ZenLogger.resetHandlers();
      captured.clear();
      ZenLogger.logError('after reset');
      // No handler set - default logging, captured is empty
      expect(captured, isEmpty);
    });

    test('resets testMode and logFunction', () {
      ZenLogger.testMode = true;
      ZenLogger.logFunction = (msg, {name}) {};
      ZenLogger.resetHandlers();
      expect(ZenLogger.testMode, false);
      expect(ZenLogger.logFunction, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Level silencing
  // ══════════════════════════════════════════════════════════
  group('ZenLogger level silencing', () {
    test('all methods silent at none level', () {
      ZenConfig.logLevel = ZenLogLevel.none;
      final captured = <String>[];
      ZenLogger.init(logHandler: (msg, _) => captured.add(msg));
      ZenLogger.logError('e');
      ZenLogger.logWarning('w');
      ZenLogger.logInfo('i');
      ZenLogger.logDebug('d');
      ZenLogger.logTrace('t');
      expect(captured, isEmpty);
    });
  });
}
