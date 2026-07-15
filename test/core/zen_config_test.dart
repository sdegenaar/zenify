import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  tearDown(ZenConfig.reset);

  // ══════════════════════════════════════════════════════════
  // Default values
  // ══════════════════════════════════════════════════════════
  group('ZenConfig defaults', () {
    test('enableRxTracking is false by default', () {
      expect(ZenConfig.enableRxTracking, false);
    });

    test('verboseErrors is false by default', () {
      expect(ZenConfig.verboseErrors, false);
    });

    test('enablePerformanceMetrics is false by default', () {
      expect(ZenConfig.enablePerformanceMetrics, false);
    });

    test('strictMode is false by default', () {
      expect(ZenConfig.strictMode, false);
    });

    test('checkForCircularDependencies is true by default', () {
      expect(ZenConfig.checkForCircularDependencies, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // enablePerformanceMetrics
  // ══════════════════════════════════════════════════════════
  group('ZenConfig performance metrics', () {
    test('enablePerformanceMetrics defaults to false', () {
      expect(ZenConfig.enablePerformanceMetrics, false);
    });

    test('enablePerformanceMetrics can be enabled', () {
      ZenConfig.enablePerformanceMetrics = true;
      expect(ZenConfig.enablePerformanceMetrics, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // shouldLogRoutes / shouldLogNavigation
  // ══════════════════════════════════════════════════════════
  group('ZenConfig utility getters', () {
    test('shouldLogRoutes is false when routeLogging disabled', () {
      ZenConfig.enableRouteLogging = false;
      expect(ZenConfig.shouldLogRoutes, false);
    });

    test('shouldLogNavigation is false when navigationLogging disabled', () {
      ZenConfig.enableNavigationLogging = false;
      expect(ZenConfig.shouldLogNavigation, false);
    });

    test('shouldLogRoutes is true when enabled and log level allows info', () {
      ZenConfig.enableRouteLogging = true;
      ZenConfig.logLevel = ZenLogLevel.info;
      expect(ZenConfig.shouldLogRoutes, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // toMap
  // ══════════════════════════════════════════════════════════
  group('ZenConfig.toMap', () {
    test('returns map with all expected keys', () {
      final m = ZenConfig.toMap();
      expect(m.containsKey('logLevel'), true);
      expect(m.containsKey('enableRxTracking'), true);
      expect(m.containsKey('verboseErrors'), true);
      expect(m.containsKey('enablePerformanceMetrics'), true);
      expect(m.containsKey('strictMode'), true);
    });

    test('map values reflect current config', () {
      ZenConfig.strictMode = true;
      ZenConfig.verboseErrors = true;
      final m = ZenConfig.toMap();
      expect(m['strictMode'], true);
      expect(m['verboseErrors'], true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Environment presets
  // ══════════════════════════════════════════════════════════
  group('ZenConfig.applyEnvironment', () {
    test('production env disables metrics and strict mode', () {
      ZenConfig.applyEnvironment(ZenEnvironment.production);
      expect(ZenConfig.enablePerformanceMetrics, false);
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.logLevel, ZenLogLevel.error);
    });

    test('development env enables metrics and strict mode', () {
      ZenConfig.applyEnvironment(ZenEnvironment.development);
      expect(ZenConfig.enablePerformanceMetrics, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.logLevel, ZenLogLevel.info);
    });

    test('test env enables strictMode and disables metrics', () {
      ZenConfig.applyEnvironment(ZenEnvironment.test);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enablePerformanceMetrics, false);
    });

    test('staging env enables metrics', () {
      ZenConfig.applyEnvironment(ZenEnvironment.staging);
      expect(ZenConfig.enablePerformanceMetrics, true);
    });

    test('debug env sets debug log level', () {
      ZenConfig.applyEnvironment(ZenEnvironment.debug);
      expect(ZenConfig.logLevel, ZenLogLevel.debug);
    });

    test('trace env enables Rx tracking', () {
      ZenConfig.applyEnvironment(ZenEnvironment.trace);
      expect(ZenConfig.enableRxTracking, true);
      expect(ZenConfig.logLevel, ZenLogLevel.trace);
    });

    test('productionVerbose env enables metrics without strict', () {
      ZenConfig.applyEnvironment(ZenEnvironment.productionVerbose);
      expect(ZenConfig.enablePerformanceMetrics, true);
      expect(ZenConfig.strictMode, false);
    });

    test('accepts String environment name', () {
      ZenConfig.applyEnvironment('production');
      expect(ZenConfig.logLevel, ZenLogLevel.error);
    });

    test('throws for unknown String environment', () {
      expect(
        () => ZenConfig.applyEnvironment('unknown_env'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for invalid type', () {
      expect(
        () => ZenConfig.applyEnvironment(123),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // configure()
  // ══════════════════════════════════════════════════════════
  group('ZenConfig.configure', () {
    test('sets logLevel', () {
      ZenConfig.configure(level: ZenLogLevel.error);
      expect(ZenConfig.logLevel, ZenLogLevel.error);
    });

    test('sets rxTracking', () {
      ZenConfig.configure(rxTracking: true);
      expect(ZenConfig.enableRxTracking, true);
    });

    test('sets navigationLogging', () {
      ZenConfig.configure(navigationLogging: true);
      expect(ZenConfig.enableNavigationLogging, true);
    });

    test('sets routeLogging', () {
      ZenConfig.configure(routeLogging: true);
      expect(ZenConfig.enableRouteLogging, true);
    });

    test('sets performanceTracking', () {
      ZenConfig.configure(performanceTracking: true);
      expect(ZenConfig.enablePerformanceMetrics, true);
    });

    test('sets strict mode', () {
      ZenConfig.configure(strict: true);
      expect(ZenConfig.strictMode, true);
    });

    test('sets circularDependencyCheck', () {
      ZenConfig.configure(circularDependencyCheck: false);
      expect(ZenConfig.checkForCircularDependencies, false);
    });

    test('sets dependencyVisualization', () {
      ZenConfig.configure(dependencyVisualization: true);
      expect(ZenConfig.enableDependencyVisualization, true);
    });

    test('null params leave existing values unchanged', () {
      ZenConfig.configure(strict: true);
      ZenConfig.configure(level: ZenLogLevel.warning); // only level changes
      expect(ZenConfig.strictMode, true); // unchanged
    });
  });

  // ══════════════════════════════════════════════════════════
  // Convenience shorthands
  // ══════════════════════════════════════════════════════════
  group('ZenConfig convenience shorthands', () {
    test('configureDevelopment applies development config', () {
      ZenConfig.configureDevelopment();
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.logLevel, ZenLogLevel.info);
    });

    test('configureProduction applies production config', () {
      ZenConfig.configureProduction();
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.logLevel, ZenLogLevel.error);
    });

    test('configureTest applies test config', () {
      ZenConfig.configureTest();
      expect(ZenConfig.enablePerformanceMetrics, false);
      expect(ZenConfig.strictMode, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // reset()
  // ══════════════════════════════════════════════════════════
  group('ZenConfig.reset', () {
    test('reset restores strictMode to false', () {
      ZenConfig.strictMode = true;
      ZenConfig.reset();
      expect(ZenConfig.strictMode, false);
    });

    test('reset restores enablePerformanceMetrics to false', () {
      ZenConfig.enablePerformanceMetrics = true;
      ZenConfig.reset();
      expect(ZenConfig.enablePerformanceMetrics, false);
    });

    test('reset restores enableRxTracking to false', () {
      ZenConfig.enableRxTracking = true;
      ZenConfig.reset();
      expect(ZenConfig.enableRxTracking, false);
    });
  });
}
