// test/core/zen_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('ZenConfig', () {
    // Store original values to restore after tests
    late ZenLogLevel originalLogLevel;
    late bool originalEnableRxTracking;
    late bool originalStrictMode;
    late bool originalEnablePerformanceTracking;
    late bool originalEnableMetrics;
    late bool originalEnableAutoDispose;
    late Duration originalControllerCacheExpiry;
    late bool originalEnableNavigationLogging;
    late bool originalEnableRouteLogging;
    late bool originalUseRxTracking;
    late bool originalCheckForCircularDependencies;
    late bool originalEnableDependencyVisualization;

    setUp(() {
      // Store original values
      originalLogLevel = ZenConfig.logLevel;
      originalEnableRxTracking = ZenConfig.enableRxTracking;
      originalStrictMode = ZenConfig.strictMode;
      originalEnablePerformanceTracking = ZenConfig.enablePerformanceTracking;
      originalEnableMetrics = ZenConfig.enableMetrics;
      originalEnableAutoDispose = ZenConfig.enableAutoDispose;
      originalControllerCacheExpiry = ZenConfig.controllerCacheExpiry;
      originalEnableNavigationLogging = ZenConfig.enableNavigationLogging;
      originalEnableRouteLogging = ZenConfig.enableRouteLogging;
      originalUseRxTracking = ZenConfig.useRxTracking;
      originalCheckForCircularDependencies =
          ZenConfig.checkForCircularDependencies;
      originalEnableDependencyVisualization =
          ZenConfig.enableDependencyVisualization;
    });

    tearDown(() {
      // Restore original values
      ZenConfig.logLevel = originalLogLevel;
      ZenConfig.enableRxTracking = originalEnableRxTracking;
      ZenConfig.strictMode = originalStrictMode;
      ZenConfig.enablePerformanceTracking = originalEnablePerformanceTracking;
      ZenConfig.enableMetrics = originalEnableMetrics;
      ZenConfig.enableAutoDispose = originalEnableAutoDispose;
      ZenConfig.controllerCacheExpiry = originalControllerCacheExpiry;
      ZenConfig.enableNavigationLogging = originalEnableNavigationLogging;
      ZenConfig.enableRouteLogging = originalEnableRouteLogging;
      ZenConfig.useRxTracking = originalUseRxTracking;
      ZenConfig.checkForCircularDependencies =
          originalCheckForCircularDependencies;
      ZenConfig.enableDependencyVisualization =
          originalEnableDependencyVisualization;
    });

    // ========================================================================
    // LOG LEVEL TESTS
    // ========================================================================

    group('Log Levels', () {
      test('should have sensible defaults', () {
        ZenConfig.reset();
        expect(ZenConfig.logLevel, isNotNull);
        expect(ZenConfig.enableRxTracking, false);
      });

      test('should update log level', () {
        ZenConfig.logLevel = ZenLogLevel.error;
        expect(ZenConfig.logLevel, ZenLogLevel.error);

        ZenConfig.logLevel = ZenLogLevel.trace;
        expect(ZenConfig.logLevel, ZenLogLevel.trace);
      });

      test('should support legacy enableDebugLogs setter', () {
        // ignore: deprecated_member_use_from_same_package
        ZenConfig.enableDebugLogs = true;
        expect(ZenConfig.logLevel.level,
            greaterThanOrEqualTo(ZenLogLevel.debug.level));

        // ignore: deprecated_member_use_from_same_package
        ZenConfig.enableDebugLogs = false;
        expect(ZenConfig.logLevel, ZenLogLevel.warning);
      });

      test('should handle all log levels correctly', () {
        for (final level in ZenLogLevel.values) {
          ZenConfig.logLevel = level;
          expect(ZenConfig.logLevel, level);
        }
      });
    });

    // ========================================================================
    // ZENENVIRONMENT ENUM TESTS
    // ========================================================================

    group('ZenEnvironment Enum', () {
      test('should have correct string values', () {
        expect(ZenEnvironment.production.value, 'production');
        expect(ZenEnvironment.staging.value, 'staging');
        expect(ZenEnvironment.development.value, 'development');
        expect(ZenEnvironment.debug.value, 'debug');
        expect(ZenEnvironment.trace.value, 'trace');
        expect(ZenEnvironment.test.value, 'test');
      });

      test('should convert from string with exact names', () {
        expect(
            ZenEnvironment.fromString('production'), ZenEnvironment.production);
        expect(ZenEnvironment.fromString('staging'), ZenEnvironment.staging);
        expect(ZenEnvironment.fromString('development'),
            ZenEnvironment.development);
        expect(ZenEnvironment.fromString('debug'), ZenEnvironment.debug);
        expect(ZenEnvironment.fromString('trace'), ZenEnvironment.trace);
        expect(ZenEnvironment.fromString('test'), ZenEnvironment.test);
      });

      test('should convert from string with aliases', () {
        expect(ZenEnvironment.fromString('prod'), ZenEnvironment.production);
        expect(ZenEnvironment.fromString('stage'), ZenEnvironment.staging);
        expect(ZenEnvironment.fromString('dev'), ZenEnvironment.development);
      });

      test('should be case insensitive', () {
        expect(
            ZenEnvironment.fromString('PRODUCTION'), ZenEnvironment.production);
        expect(ZenEnvironment.fromString('Prod'), ZenEnvironment.production);
        expect(ZenEnvironment.fromString('DEV'), ZenEnvironment.development);
        expect(ZenEnvironment.fromString('Dev'), ZenEnvironment.development);
        expect(ZenEnvironment.fromString('STAGING'), ZenEnvironment.staging);
        expect(ZenEnvironment.fromString('Stage'), ZenEnvironment.staging);
      });

      test('should throw on unknown environment string', () {
        expect(
          () => ZenEnvironment.fromString('unknown'),
          throwsArgumentError,
        );
        expect(
          () => ZenEnvironment.fromString('invalid'),
          throwsArgumentError,
        );
      });

      test('should convert to string correctly', () {
        expect(ZenEnvironment.production.toString(), 'production');
        expect(ZenEnvironment.development.toString(), 'development');
        expect(ZenEnvironment.staging.toString(), 'staging');
      });
    });

    // ========================================================================
    // ENVIRONMENT PRESET TESTS (ENUM)
    // ========================================================================

    group('Environment Presets (Type-Safe Enum)', () {
      test('production environment should disable all debug features', () {
        ZenConfig.applyEnvironment(ZenEnvironment.production);

        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.enableRxTracking, false);
        expect(ZenConfig.enableNavigationLogging, false);
        expect(ZenConfig.enableRouteLogging, false);
        expect(ZenConfig.enablePerformanceTracking, false);
        expect(ZenConfig.enableMetrics, false);
        expect(ZenConfig.strictMode, false);
        expect(ZenConfig.checkForCircularDependencies, false);
        expect(ZenConfig.enableDependencyVisualization, false);
      });

      test('staging environment should enable moderate logging', () {
        ZenConfig.applyEnvironment(ZenEnvironment.staging);

        expect(ZenConfig.logLevel, ZenLogLevel.warning);
        expect(ZenConfig.enableRxTracking, false);
        expect(ZenConfig.enablePerformanceTracking, true);
        expect(ZenConfig.enableMetrics, true);
        expect(ZenConfig.checkForCircularDependencies, true);
      });

      test('development environment should enable most features', () {
        ZenConfig.applyEnvironment(ZenEnvironment.development);

        expect(ZenConfig.logLevel, ZenLogLevel.info);
        expect(ZenConfig.enableNavigationLogging, true);
        expect(ZenConfig.enableRouteLogging, true);
        expect(ZenConfig.enablePerformanceTracking, true);
        expect(ZenConfig.enableMetrics, true);
        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.checkForCircularDependencies, true);
        expect(ZenConfig.enableDependencyVisualization, true);
        expect(ZenConfig.enableRxTracking, false); // Still too verbose
      });

      test('debug environment should enable very detailed logging', () {
        ZenConfig.applyEnvironment(ZenEnvironment.debug);

        expect(ZenConfig.logLevel, ZenLogLevel.debug);
        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.checkForCircularDependencies, true);
        expect(ZenConfig.enableRxTracking, false); // Still separate
      });

      test('trace environment should enable everything including Rx tracking',
          () {
        ZenConfig.applyEnvironment(ZenEnvironment.trace);

        expect(ZenConfig.logLevel, ZenLogLevel.trace);
        expect(ZenConfig.enableRxTracking, true); // Only env with Rx tracking
        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.enablePerformanceTracking, true);
      });

      test('test environment should disable auto-dispose', () {
        ZenConfig.applyEnvironment(ZenEnvironment.test);

        expect(ZenConfig.enableAutoDispose, false);
        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.enableMetrics, false);
        expect(ZenConfig.logLevel, ZenLogLevel.warning);
      });
    });

    // ========================================================================
    // ENVIRONMENT PRESET TESTS (STRING - BACKWARD COMPATIBILITY)
    // ========================================================================

    group('Environment Presets (String - Legacy)', () {
      test('should accept string for backward compatibility', () {
        ZenConfig.applyEnvironment('production');
        expect(ZenConfig.logLevel, ZenLogLevel.error);

        ZenConfig.applyEnvironment('dev');
        expect(ZenConfig.logLevel, ZenLogLevel.info);
      });

      test('should accept prod as alias for production', () {
        ZenConfig.applyEnvironment('prod');
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.strictMode, false);
      });

      test('should accept stage as alias for staging', () {
        ZenConfig.applyEnvironment('stage');
        expect(ZenConfig.logLevel, ZenLogLevel.warning);
        expect(ZenConfig.enableMetrics, true);
      });

      test('should accept development as alias for dev', () {
        ZenConfig.applyEnvironment('development');
        expect(ZenConfig.logLevel, ZenLogLevel.info);
        expect(ZenConfig.strictMode, true);
      });

      test('should be case insensitive with strings', () {
        expect(() => ZenConfig.applyEnvironment('PRODUCTION'), returnsNormally);
        expect(() => ZenConfig.applyEnvironment('Dev'), returnsNormally);
        expect(() => ZenConfig.applyEnvironment('TeSt'), returnsNormally);
      });

      test('should throw on unknown environment string', () {
        expect(
          () => ZenConfig.applyEnvironment('unknown'),
          throwsArgumentError,
        );
      });
    });

    // ========================================================================
    // CUSTOM CONFIGURATION TESTS
    // ========================================================================

    group('Custom Configuration', () {
      test('should allow fine-grained control', () {
        ZenConfig.configure(
          level: ZenLogLevel.debug,
          rxTracking: true,
          performanceTracking: false,
          strict: true,
        );

        expect(ZenConfig.logLevel, ZenLogLevel.debug);
        expect(ZenConfig.enableRxTracking, true);
        expect(ZenConfig.enablePerformanceTracking, false);
        expect(ZenConfig.strictMode, true);
      });

      test('should only update specified fields', () {
        ZenConfig.reset();
        final originalCacheExpiry = ZenConfig.controllerCacheExpiry;

        ZenConfig.configure(
          level: ZenLogLevel.error,
        );

        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.controllerCacheExpiry, originalCacheExpiry);
      });

      test('should configure all parameters', () {
        ZenConfig.configure(
          level: ZenLogLevel.trace,
          rxTracking: true,
          navigationLogging: true,
          routeLogging: true,
          performanceTracking: true,
          metrics: true,
          autoDispose: false,
          cacheExpiry: const Duration(minutes: 5),
          strict: true,
          circularDependencyCheck: false,
          dependencyVisualization: true,
          useRxTrack: false,
        );

        expect(ZenConfig.logLevel, ZenLogLevel.trace);
        expect(ZenConfig.enableRxTracking, true);
        expect(ZenConfig.enableNavigationLogging, true);
        expect(ZenConfig.enableRouteLogging, true);
        expect(ZenConfig.enablePerformanceTracking, true);
        expect(ZenConfig.enableMetrics, true);
        expect(ZenConfig.enableAutoDispose, false);
        expect(ZenConfig.controllerCacheExpiry, const Duration(minutes: 5));
        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.checkForCircularDependencies, false);
        expect(ZenConfig.enableDependencyVisualization, true);
        expect(ZenConfig.useRxTracking, false);
      });

      test('should support legacy debugLogs parameter', () {
        // ignore: deprecated_member_use_from_same_package
        ZenConfig.configure(debugLogs: true);
        expect(ZenConfig.logLevel.level,
            greaterThanOrEqualTo(ZenLogLevel.debug.level));

        // ignore: deprecated_member_use_from_same_package
        ZenConfig.configure(debugLogs: false);
        expect(ZenConfig.logLevel, ZenLogLevel.warning);
      });
    });

    // ========================================================================
    // CONVENIENCE METHOD TESTS
    // ========================================================================

    group('Convenience Methods', () {
      test('configureDevelopment should apply dev environment', () {
        ZenConfig.configureDevelopment();
        expect(ZenConfig.logLevel, ZenLogLevel.info);
        expect(ZenConfig.strictMode, true);
      });

      test('configureProduction should apply prod environment', () {
        ZenConfig.configureProduction();
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.strictMode, false);
      });

      test('configureTest should apply test environment', () {
        ZenConfig.configureTest();
        expect(ZenConfig.enableAutoDispose, false);
        expect(ZenConfig.strictMode, true);
      });
    });

    // ========================================================================
    // RESET TESTS
    // ========================================================================

    group('Reset', () {
      test('should reset to default values', () {
        // Set everything to non-default values
        ZenConfig.logLevel = ZenLogLevel.trace;
        ZenConfig.enableRxTracking = true;
        ZenConfig.strictMode = true;
        ZenConfig.enablePerformanceTracking = true;
        ZenConfig.enableMetrics = true;
        ZenConfig.enableAutoDispose = false;
        ZenConfig.controllerCacheExpiry = const Duration(minutes: 5);
        ZenConfig.enableNavigationLogging = true;
        ZenConfig.enableRouteLogging = true;
        ZenConfig.useRxTracking = false;
        ZenConfig.checkForCircularDependencies = false;
        ZenConfig.enableDependencyVisualization = true;

        // Reset to defaults
        ZenConfig.reset();

        // Verify reset to default values
        expect(ZenConfig.enableRxTracking, false);
        expect(ZenConfig.strictMode, false);
        expect(ZenConfig.enablePerformanceTracking, false);
        expect(ZenConfig.enablePerformanceMetrics, false); // Alias check
        expect(ZenConfig.enableMetrics, false);
        expect(ZenConfig.enableAutoDispose, true);
        expect(ZenConfig.controllerCacheExpiry, const Duration(minutes: 10));
        expect(ZenConfig.enableNavigationLogging, false);
        expect(ZenConfig.enableRouteLogging, false);
        expect(ZenConfig.useRxTracking, true);
        expect(ZenConfig.checkForCircularDependencies, true);
        expect(ZenConfig.enableDependencyVisualization, false);
      });

      test('should reset all settings including new log level', () {
        ZenConfig.logLevel = ZenLogLevel.trace;
        ZenConfig.enableRxTracking = true;

        ZenConfig.reset();

        expect(ZenConfig.enableRxTracking, false);
        // Default log level depends on kDebugMode, so just check it's set
        expect(ZenConfig.logLevel, isNotNull);
      });
    });

    // ========================================================================
    // PERFORMANCE SETTINGS TESTS
    // ========================================================================

    group('Performance Settings', () {
      test('should have alias for performance metrics', () {
        ZenConfig.enablePerformanceMetrics = true;
        expect(ZenConfig.enablePerformanceTracking, true);

        ZenConfig.enablePerformanceTracking = false;
        expect(ZenConfig.enablePerformanceMetrics, false);
      });

      test('should toggle performance tracking independently', () {
        ZenConfig.reset();
        expect(ZenConfig.enablePerformanceTracking, false);

        ZenConfig.enablePerformanceTracking = true;
        expect(ZenConfig.enablePerformanceMetrics, true);
        expect(ZenConfig.enableMetrics, false); // Independent setting
      });
    });

    // ========================================================================
    // LEGACY COMPATIBILITY TESTS
    // ========================================================================

    group('Legacy Compatibility', () {
      test('should maintain backward compatibility with old tests', () {
        // Old test pattern: setting enableDebugLogs
        // ignore: deprecated_member_use_from_same_package
        ZenConfig.enableDebugLogs = true;
        expect(ZenConfig.strictMode, false); // Should not affect other settings

        // Old test pattern: using applyEnvironment with string
        ZenConfig.applyEnvironment('dev');
        expect(ZenConfig.enablePerformanceTracking, true);
        expect(ZenConfig.enableMetrics, true);
      });

      test('should handle old configure method signature', () {
        // Old pattern with debugLogs parameter
        ZenConfig.configure(
          // ignore: deprecated_member_use_from_same_package
          debugLogs: true,
          strict: true,
          performanceTracking: true,
          metrics: true,
        );

        expect(ZenConfig.strictMode, true);
        expect(ZenConfig.enablePerformanceTracking, true);
        expect(ZenConfig.enableMetrics, true);
      });
    });

    // ========================================================================
    // INTEGRATION TESTS
    // ========================================================================

    group('Integration', () {
      test('should maintain consistency between related settings', () {
        ZenConfig.applyEnvironment(ZenEnvironment.production);

        // In production, all debug features should be off
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.enableRxTracking, false);
        expect(ZenConfig.strictMode, false);
        expect(ZenConfig.enableNavigationLogging, false);
        expect(ZenConfig.enableRouteLogging, false);
        expect(ZenConfig.enablePerformanceTracking, false);
      });

      test('should handle rapid environment switching with enum', () {
        ZenConfig.applyEnvironment(ZenEnvironment.production);
        expect(ZenConfig.logLevel, ZenLogLevel.error);

        ZenConfig.applyEnvironment(ZenEnvironment.development);
        expect(ZenConfig.logLevel, ZenLogLevel.info);

        ZenConfig.applyEnvironment(ZenEnvironment.trace);
        expect(ZenConfig.logLevel, ZenLogLevel.trace);
        expect(ZenConfig.enableRxTracking, true);

        ZenConfig.applyEnvironment(ZenEnvironment.production);
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.enableRxTracking, false);
      });

      test('should handle rapid environment switching with strings', () {
        ZenConfig.applyEnvironment('production');
        expect(ZenConfig.logLevel, ZenLogLevel.error);

        ZenConfig.applyEnvironment('dev');
        expect(ZenConfig.logLevel, ZenLogLevel.info);

        ZenConfig.applyEnvironment('trace');
        expect(ZenConfig.logLevel, ZenLogLevel.trace);
        expect(ZenConfig.enableRxTracking, true);

        ZenConfig.applyEnvironment('production');
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.enableRxTracking, false);
      });

      test('should preserve custom settings when partially reconfiguring', () {
        ZenConfig.applyEnvironment(ZenEnvironment.development);
        expect(ZenConfig.strictMode, true);

        // Only change log level
        ZenConfig.configure(level: ZenLogLevel.error);

        // Other dev settings should be preserved
        expect(ZenConfig.logLevel, ZenLogLevel.error);
        expect(ZenConfig.strictMode, true); // Preserved
        expect(ZenConfig.enableNavigationLogging, true); // Preserved
      });

      test('should work seamlessly with enum and string interchangeably', () {
        // Start with enum
        ZenConfig.applyEnvironment(ZenEnvironment.production);
        expect(ZenConfig.logLevel, ZenLogLevel.error);

        // Switch with string
        ZenConfig.applyEnvironment('dev');
        expect(ZenConfig.logLevel, ZenLogLevel.info);

        // Switch back with enum
        ZenConfig.applyEnvironment(ZenEnvironment.staging);
        expect(ZenConfig.logLevel, ZenLogLevel.warning);

        // Use alias string
        ZenConfig.applyEnvironment('prod');
        expect(ZenConfig.logLevel, ZenLogLevel.error);
      });

      test('should throw same error for invalid string or enum conversion', () {
        expect(
          () => ZenConfig.applyEnvironment('invalid'),
          throwsArgumentError,
        );

        expect(
          () => ZenEnvironment.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    // ========================================================================
    // TYPE SAFETY TESTS
    // ========================================================================

    group('Type Safety', () {
      test('should only accept ZenEnvironment or String types', () {
        // Valid: enum
        expect(() => ZenConfig.applyEnvironment(ZenEnvironment.production),
            returnsNormally);

        // Valid: string
        expect(() => ZenConfig.applyEnvironment('production'), returnsNormally);

        // Invalid: number
        expect(() => ZenConfig.applyEnvironment(123), throwsArgumentError);

        // Invalid: null
        expect(() => ZenConfig.applyEnvironment(null), throwsArgumentError);

        // Invalid: list
        expect(() => ZenConfig.applyEnvironment([]), throwsArgumentError);
      });

      test('enum provides compile-time type safety', () {
        // This wouldn't compile if we tried to pass an invalid enum value
        ZenEnvironment env = ZenEnvironment.production;
        ZenConfig.applyEnvironment(env);
        expect(ZenConfig.logLevel, ZenLogLevel.error);
      });
    });
  });
}
