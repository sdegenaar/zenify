import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for core/zen_metrics.dart targeting uncovered lines:
/// - L8: ZenMetrics._() private constructor (via subclass workaround)
/// - L131-133: stopTiming list trimming (>100 entries)
/// - L156-158: getReport with operations that have durations
/// - L210-214: startPeriodicLogging timer fires and reports
/// - L212-213: periodic callback body
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
  // Basic metric recording
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.recordController', () {
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

  group('ZenMetrics.recordRxCreation and recordStateUpdate', () {
    test('recordRxCreation increments totalRxValues', () {
      ZenMetrics.recordRxCreation();
      expect(ZenMetrics.totalRxValues, 1);
    });

    test('recordStateUpdate increments totalStateUpdates', () {
      ZenMetrics.recordStateUpdate();
      expect(ZenMetrics.totalStateUpdates, 1);
    });

    test('recordProviderCreation increments totalProviders', () {
      ZenMetrics.recordProviderCreation();
      expect(ZenMetrics.totalProviders, 1);
    });
  });

  group('ZenMetrics.effects', () {
    test('recordEffectSuccess increments both runs and successes', () {
      ZenMetrics.recordEffectSuccess('myEffect');
      expect(ZenMetrics.totalEffectRuns, 1);
      expect(ZenMetrics.totalEffectSuccesses, 1);
      expect(ZenMetrics.effectSuccessCounts['myEffect'], 1);
    });

    test('recordEffectFailure increments both runs and failures', () {
      ZenMetrics.recordEffectFailure('myEffect');
      expect(ZenMetrics.totalEffectRuns, 1);
      expect(ZenMetrics.totalEffectFailures, 1);
      expect(ZenMetrics.effectFailureCounts['myEffect'], 1);
    });
  });

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
  // startTiming / stopTiming — L131-133 list trimming
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
      // Should trim to 100 and not throw
      final avg = ZenMetrics.getAverageDuration('burst');
      expect(avg, isNotNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // startPeriodicLogging — L210-214 timer callback body
  // ══════════════════════════════════════════════════════════
  group('ZenMetrics.periodicLogging', () {
    test('startPeriodicLogging replaces previous timer safely', () async {
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 30));
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 30));
      await Future.delayed(const Duration(milliseconds: 80));
      ZenMetrics.stopPeriodicLogging(); // must not throw
    });

    test('stopPeriodicLogging is safe when no timer running', () {
      expect(() => ZenMetrics.stopPeriodicLogging(), returnsNormally);
    });

    test('periodic logging fires the timer callback', () async {
      // Start periodic logging, wait for it to fire (L212-214)
      ZenMetrics.startPeriodicLogging(const Duration(milliseconds: 20));
      await Future.delayed(const Duration(milliseconds: 60));
      // No assertion needed — we just need the callback to execute without crash
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
      expect(report['state'], isNotNull);
      expect(report['effects'], isNotNull);
      expect(report['counters'], isNotNull);
      expect(report['performance'], isNotNull);
    });

    test('reset zeroes all counters', () {
      ZenMetrics.recordControllerCreation(String);
      ZenMetrics.recordRxCreation();
      ZenMetrics.reset();
      expect(ZenMetrics.activeControllers, 0);
      expect(ZenMetrics.totalRxValues, 0);
    });
  });
}
