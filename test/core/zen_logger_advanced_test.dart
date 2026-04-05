import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenLogger targeting uncovered testMode branches.
/// Uncovered lines: 17(constructor), 66, 115, 141, 165, 189, 213, 232
/// All are the `testMode && logFunction != null` fast paths.
void main() {
  setUp(() {
    ZenLogger.testMode = true;
    ZenLogger.logFunction = (message, {String? name}) {/* capture */};
    ZenConfig.configure(level: ZenLogLevel.trace, rxTracking: true);
  });

  tearDown(() {
    ZenLogger.resetHandlers();
    ZenConfig.reset();
  });

  group('ZenLogger testMode paths', () {
    test('logError uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logError('Test error message');
      expect(captured, contains('Test error message'));
    });

    test('logError with error object uses logFunction', () {
      final messages = <String>[];
      ZenLogger.logFunction = (msg, {String? name}) => messages.add(msg);
      ZenLogger.logError('Something failed', Exception('boom'));
      expect(messages, isNotEmpty);
      expect(messages.first, contains('Something failed'));
    });

    test('logException uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logException(Exception('test exception'));
      expect(captured, contains('test exception'));
    });

    test('logWarning uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logWarning('Watch out!');
      expect(captured, 'Watch out!');
    });

    test('logInfo uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logInfo('Info message');
      expect(captured, 'Info message');
    });

    test('logDebug uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logDebug('Debug details');
      expect(captured, 'Debug details');
    });

    test('logTrace uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logTrace('Trace entry');
      expect(captured, 'Trace entry');
    });

    test('logRxTracking uses logFunction when testMode=true', () {
      var captured = '';
      ZenLogger.logFunction = (msg, {String? name}) => captured = msg;
      ZenLogger.logRxTracking('rx event');
      expect(captured, contains('rx event'));
    });
  });

  group('ZenLogger custom handlers', () {
    test('custom logHandler overrides default logging', () {
      final messages = <String>[];
      ZenLogger.init(logHandler: (msg, level) => messages.add(msg));
      ZenLogger.logInfo('custom handler message');
      expect(messages, contains('custom handler message'));
    });

    test('custom errorHandler overrides default error logging', () {
      dynamic capturedError;
      ZenLogger.init(
        errorHandler: (msg, [err, st]) => capturedError = err,
      );
      ZenLogger.logError('Failed', Exception('handler error'));
      expect(capturedError.toString(), contains('handler error'));
    });

    test('logHandler catches exception messages', () {
      final messages = <String>[];
      ZenLogger.init(logHandler: (msg, level) => messages.add(msg));
      ZenLogger.logError('error via handler', Exception('ex'));
      expect(messages.any((m) => m.contains('error via handler')), true);
    });

    test('resetHandlers clears all custom handlers', () {
      ZenLogger.init(logHandler: (_, __) {});
      ZenLogger.resetHandlers();
      // After reset, testMode=false, no handlers — should not crash
      expect(() => ZenLogger.logInfo('after reset'), returnsNormally);
    });
  });

  group('ZenLogger.logError with stackTrace via logHandler', () {
    test(
        'logHandler called for stackTrace when logHandler set and no errorHandler',
        () {
      final messages = <String>[];
      ZenLogger.init(logHandler: (msg, level) => messages.add(msg));
      try {
        throw Exception('trigger stack trace');
      } catch (e, st) {
        ZenLogger.logError('logged with stack', e, st);
      }
      // Message should appear via logHandler
      expect(messages.any((m) => m.contains('logged with stack')), true);
    });
  });
}
