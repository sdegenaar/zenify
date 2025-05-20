// test/core/zen_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/core/zen_config.dart';

void main() {
  group('ZenConfig', () {
    // Store original values to restore after tests
    late bool originalEnableDebugLogs;
    late bool originalStrictMode;
    late bool originalEnablePerformanceTracking;
    late bool originalEnableMetrics;
    late bool originalEnableAutoDispose;
    late Duration originalControllerCacheExpiry;
    late bool originalEnableNavigationLogging;
    late bool originalEnableRouteLogging;
    late bool originalUseRxTracking;

    setUp(() {
      // Store original values
      originalEnableDebugLogs = ZenConfig.enableDebugLogs;
      originalStrictMode = ZenConfig.strictMode;
      originalEnablePerformanceTracking = ZenConfig.enablePerformanceTracking;
      originalEnableMetrics = ZenConfig.enableMetrics;
      originalEnableAutoDispose = ZenConfig.enableAutoDispose;
      originalControllerCacheExpiry = ZenConfig.controllerCacheExpiry;
      originalEnableNavigationLogging = ZenConfig.enableNavigationLogging;
      originalEnableRouteLogging = ZenConfig.enableRouteLogging;
      originalUseRxTracking = ZenConfig.useRxTracking;
    });

    tearDown(() {
      // Restore original values
      ZenConfig.enableDebugLogs = originalEnableDebugLogs;
      ZenConfig.strictMode = originalStrictMode;
      ZenConfig.enablePerformanceTracking = originalEnablePerformanceTracking;
      ZenConfig.enableMetrics = originalEnableMetrics;
      ZenConfig.enableAutoDispose = originalEnableAutoDispose;
      ZenConfig.controllerCacheExpiry = originalControllerCacheExpiry;
      ZenConfig.enableNavigationLogging = originalEnableNavigationLogging;
      ZenConfig.enableRouteLogging = originalEnableRouteLogging;
      ZenConfig.useRxTracking = originalUseRxTracking;
    });

    test('should reset to default values', () {
      // First set everything to non-default values
      ZenConfig.enableDebugLogs = true;
      ZenConfig.strictMode = true;
      ZenConfig.enablePerformanceTracking = true;
      ZenConfig.enableMetrics = true;
      ZenConfig.enableAutoDispose = false;
      ZenConfig.controllerCacheExpiry = Duration(minutes: 5);
      ZenConfig.enableNavigationLogging = true;
      ZenConfig.enableRouteLogging = true;
      ZenConfig.useRxTracking = false;

      // Reset to defaults
      ZenConfig.reset();

      // Verify reset to default values
      expect(ZenConfig.enableDebugLogs, false);
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.enablePerformanceTracking, false);
      expect(ZenConfig.enablePerformanceMetrics, false); // Alias check
      expect(ZenConfig.enableMetrics, false);
      expect(ZenConfig.enableAutoDispose, true);
      expect(ZenConfig.controllerCacheExpiry, Duration(minutes: 30));
      expect(ZenConfig.enableNavigationLogging, false);
      expect(ZenConfig.enableRouteLogging, false);
      expect(ZenConfig.useRxTracking, true);
    });

    test('should update values when modified', () {
      // Modify values
      ZenConfig.enableDebugLogs = true;
      ZenConfig.strictMode = true;
      ZenConfig.enablePerformanceTracking = true;
      ZenConfig.enableMetrics = true;
      ZenConfig.enableAutoDispose = false;
      ZenConfig.controllerCacheExpiry = Duration(minutes: 5);
      ZenConfig.enableNavigationLogging = true;
      ZenConfig.enableRouteLogging = true;
      ZenConfig.useRxTracking = false;

      // Verify values were updated
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enablePerformanceMetrics, true); // Alias check
      expect(ZenConfig.enableMetrics, true);
      expect(ZenConfig.enableAutoDispose, false);
      expect(ZenConfig.controllerCacheExpiry, Duration(minutes: 5));
      expect(ZenConfig.enableNavigationLogging, true);
      expect(ZenConfig.enableRouteLogging, true);
      expect(ZenConfig.useRxTracking, false);
    });

    test('should apply development configuration shortcut method', () {
      // Apply development configuration
      ZenConfig.configureDevelopment();

      // Verify development values
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enablePerformanceMetrics, true); // Alias check
      expect(ZenConfig.enableMetrics, true);
      expect(ZenConfig.enableNavigationLogging, true);
      expect(ZenConfig.enableRouteLogging, true);
    });

    test('should apply production configuration shortcut method', () {
      // Apply production configuration
      ZenConfig.configureProduction();

      // Verify production values
      expect(ZenConfig.enableDebugLogs, false);
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.enablePerformanceTracking, false);
      expect(ZenConfig.enablePerformanceMetrics, false); // Alias check
      expect(ZenConfig.enableMetrics, false);
      expect(ZenConfig.enableNavigationLogging, false);
      expect(ZenConfig.enableRouteLogging, false);
    });

    test('should apply test configuration shortcut method', () {
      // Apply test configuration
      ZenConfig.configureTest();

      // Verify test values
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enableAutoDispose, false);
      expect(ZenConfig.enableMetrics, false);
      expect(ZenConfig.enableNavigationLogging, false);
      expect(ZenConfig.enableRouteLogging, false);
    });

    test('should apply custom configuration with all parameters', () {
      // Apply custom configuration
      ZenConfig.configure(
        debugLogs: true,
        strict: true,
        performanceTracking: true,
        metrics: true,
        autoDispose: false,
        cacheExpiry: Duration(minutes: 5),
        navigationLogging: true,
        routeLogging: true,
        rxTracking: false,
      );

      // Verify custom values
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enablePerformanceMetrics, true); // Alias check
      expect(ZenConfig.enableMetrics, true);
      expect(ZenConfig.enableAutoDispose, false);
      expect(ZenConfig.controllerCacheExpiry, Duration(minutes: 5));
      expect(ZenConfig.enableNavigationLogging, true);
      expect(ZenConfig.enableRouteLogging, true);
      expect(ZenConfig.useRxTracking, false);
    });

    test('should only update specified values in custom configuration', () {
      // Reset to defaults first
      ZenConfig.reset();

      // Apply partial custom configuration
      ZenConfig.configure(
        debugLogs: true,
        metrics: true,
        navigationLogging: true,
      );

      // Verify that only specified values changed
      expect(ZenConfig.enableDebugLogs, true); // Changed
      expect(ZenConfig.strictMode, false); // Default
      expect(ZenConfig.enablePerformanceTracking, false); // Default
      expect(ZenConfig.enablePerformanceMetrics, false); // Default (alias)
      expect(ZenConfig.enableMetrics, true); // Changed
      expect(ZenConfig.enableAutoDispose, true); // Default
      expect(ZenConfig.controllerCacheExpiry, Duration(minutes: 30)); // Default
      expect(ZenConfig.enableNavigationLogging, true); // Changed
      expect(ZenConfig.enableRouteLogging, false); // Default
      expect(ZenConfig.useRxTracking, true); // Default
    });

    test('enablePerformanceMetrics setter should update enablePerformanceTracking', () {
      // Set via the setter
      ZenConfig.enablePerformanceMetrics = true;
      expect(ZenConfig.enablePerformanceTracking, true);

      ZenConfig.enablePerformanceMetrics = false;
      expect(ZenConfig.enablePerformanceTracking, false);
    });

    test('should apply environment configuration with different environments', () {
      // Test with 'dev' environment
      ZenConfig.applyEnvironment('dev');
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enablePerformanceTracking, true);
      expect(ZenConfig.enableMetrics, true);
      expect(ZenConfig.enableNavigationLogging, true);
      expect(ZenConfig.enableRouteLogging, true);

      // Test with 'test' environment
      ZenConfig.applyEnvironment('test');
      expect(ZenConfig.enableDebugLogs, true);
      expect(ZenConfig.strictMode, true);
      expect(ZenConfig.enableAutoDispose, false);
      expect(ZenConfig.enableMetrics, false);

      // Test with 'prod' environment
      ZenConfig.applyEnvironment('prod');
      expect(ZenConfig.enableDebugLogs, false);
      expect(ZenConfig.strictMode, false);
      expect(ZenConfig.enablePerformanceTracking, false);
      expect(ZenConfig.enableMetrics, false);
      expect(ZenConfig.enableNavigationLogging, false);
      expect(ZenConfig.enableRouteLogging, false);
    });
  });
}