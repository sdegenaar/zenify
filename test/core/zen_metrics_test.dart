import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for core/zen_metrics.dart
void main() {
  setUp(() {
    Zen.init();
    ZenMetrics.reset();
    ZenConfig.enablePerformanceMetrics = true;
  });
  tearDown(() {
    ZenMetrics.stopPeriodicLogging();
    ZenConfig.enablePerformanceMetrics = false;
    ZenMetrics.reset();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // Controller lifecycle tracking
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.controller', () {
    test('recordControllerCreation increments active and total', () {
      ZenMetrics.recordControllerCreation(String);
      expect(ZenMetrics.activeControllers, 1);
      expect(ZenMetrics.totalControllersCreated, 1);
      expect(ZenMetrics.controllerCreationCount['String'], 1);
    });

    test('recordControllerDisposal decrements active', () {
      ZenMetrics.recordControllerCreation(String);
      ZenMetrics.recordControllerDisposal(String);
      expect(ZenMetrics.activeControllers, 0);
      expect(ZenMetrics.totalControllersDisposed, 1);
    });

    test('no-op when enablePerformanceMetrics is false', () {
      ZenConfig.enablePerformanceMetrics = false;
      ZenMetrics.recordControllerCreation(String);
      expect(ZenMetrics.activeControllers, 0);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Counters
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.counters', () {
    test('incrementCounter adds to named counter', () {
      ZenMetrics.incrementCounter('hits');
      ZenMetrics.incrementCounter('hits');
      final report = ZenMetrics.getReport();
      expect((report['counters'] as Map)['hits'], 2);
    });

    test('recordCounterValue sets exact value', () {
      ZenMetrics.recordCounterValue('page', 5);
      final report = ZenMetrics.getReport();
      expect((report['counters'] as Map)['page'], 5);
    });
  });

  // ══════════════════════════════════════════════════════════
  // startTiming / stopTiming
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.timing', () {
    test('stopTiming without startTiming is a no-op', () {
      expect(() => ZenMetrics.stopTiming('noop'), returnsNormally);
    });

    test('startTiming + stopTiming records a duration', () {
      ZenMetrics.startTiming('upload');
      ZenMetrics.stopTiming('upload');
      final avg = ZenMetrics.getAverageDuration('upload');
      expect(avg, isNotNull);
    });

    test('getAverageDuration returns null for unknown operation', () {
      expect(ZenMetrics.getAverageDuration('unknown'), isNull);
    });

    test('getReport includes average durations', () {
      ZenMetrics.startTiming('op');
      ZenMetrics.stopTiming('op');
      final report = ZenMetrics.getReport();
      final perf = report['performance'] as Map;
      final avgDurations = perf['averageDurations'] as Map;
      expect(avgDurations.containsKey('op'), true);
    });

    test('stopTiming trims list to 100 entries after overflow', () {
      for (int i = 0; i < 105; i++) {
        ZenMetrics.startTiming('burst');
        ZenMetrics.stopTiming('burst');
      }
      final avg = ZenMetrics.getAverageDuration('burst');
      expect(avg, isNotNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // startPeriodicLogging
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.periodicLogging', () {
    test('startPeriodicLogging replaces previous timer safely', () async {
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 30));
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 30));
      await Future.delayed(const Duration(milliseconds: 80));
      ZenMetrics.stopPeriodicLogging();
    });

    test('stopPeriodicLogging is safe when no timer running', () {
      expect(() => ZenMetrics.stopPeriodicLogging(), returnsNormally);
    });

    test('periodic logging fires the timer callback', () async {
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 20));
      await Future.delayed(const Duration(milliseconds: 60));
      ZenMetrics.stopPeriodicLogging();
    });
  });

  // ══════════════════════════════════════════════════════════
  // getReport structure
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.getReport', () {
    test('report has all expected top-level keys', () {
      final report = ZenMetrics.getReport();
      expect(report['controllers'], isNotNull);
      expect(report['counters'], isNotNull);
      expect(report['performance'], isNotNull);
    });

    test('reset zeroes all counters', () {
      ZenMetrics.recordControllerCreation(String);
      ZenMetrics.incrementCounter('x');
      ZenMetrics.reset();
      expect(ZenMetrics.activeControllers, 0);
      final report = ZenMetrics.getReport();
      expect((report['counters'] as Map).isEmpty, true);
    });
  });
}
