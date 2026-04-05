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

    test('enablePerformanceTracking is false by default', () {
      expect(ZenConfig.enablePerformanceTracking, false);
    });

    test('enableAutoDispose is true by default', () {
      expect(ZenConfig.enableAutoDispose, true);
    });

    test('strictMode is false by default', () {
      expect(ZenConfig.strictMode, false);
    });

    test('checkForCircularDependencies is true by default', () {
      expect(ZenConfig.checkForCircularDependencies, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Aliases round-trip
  // ══════════════════════════════════════════════════════════
  group('ZenConfig aliases', () {
    test('enablePerformanceMetrics alias maps to enablePerformanceTracking',
        () {
      ZenConfig.enablePerformanceMetrics = true;
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enablePerformanceMetrics, true);
    });

    test('autoDispose alias maps to enableAutoDispose', () {
      ZenConfig.autoDispose = false;
      expect(ZenConfig.enableAutoDispose, false);
      expect(ZenConfig.autoDispose, false);
    });

    test('enableStrictMode alias maps to strictMode', () {
      ZenConfig.enableStrictMode = true;
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enableStrictMode, true);
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
      expect(m.containsKey('enablePerformanceTracking'), true);
      expect(m.containsKey('enableAutoDispose'), true);
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
      expect(ZenConfig.enablePerformanceTracking, false);
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.logLevel, ZenLogLevel.error);
    });

    test('development env enables metrics and strict mode', () {
      ZenConfig.applyEnvironment(ZenEnvironment.development);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.logLevel, ZenLogLevel.info);
    });

    test('test env enables strictMode and disables autoDispose', () {
      ZenConfig.applyEnvironment(ZenEnvironment.test);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enableAutoDispose, false);
    });

    test('staging env enables metrics', () {
      ZenConfig.applyEnvironment(ZenEnvironment.staging);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enableMetrics, true);
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
      expect(ZenConfig.enablePerformanceTracking, true);
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
      expect(ZenConfig.enablePerformanceTracking, true);
    });

    test('sets metrics', () {
      ZenConfig.configure(metrics: true);
      expect(ZenConfig.enableMetrics, true);
    });

    test('sets autoDispose', () {
      ZenConfig.configure(autoDispose: false);
      expect(ZenConfig.enableAutoDispose, false);
    });

    test('sets cacheExpiry', () {
      ZenConfig.configure(cacheExpiry: const Duration(hours: 1));
      expect(ZenConfig.controllerCacheExpiry.inHours, 1);
    });

    test('sets disposeTimeout', () {
      ZenConfig.configure(disposeTimeout: 9999);
      expect(ZenConfig.disposeTimeoutMs, 9999);
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

    test('sets useRxTrack', () {
      ZenConfig.configure(useRxTrack: false);
      expect(ZenConfig.useRxTracking, false);
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
      expect(ZenConfig.enableAutoDispose, false);
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

    test('reset restores enableAutoDispose to true', () {
      ZenConfig.enableAutoDispose = false;
      ZenConfig.reset();
      expect(ZenConfig.enableAutoDispose, true);
    });

    test('reset restores enablePerformanceTracking to false', () {
      ZenConfig.enablePerformanceTracking = true;
      ZenConfig.reset();
      expect(ZenConfig.enablePerformanceTracking, false);
    });
  });
}
