
// lib/core/zen_config.dart
import 'package:flutter/foundation.dart';
import 'zen_environment.dart';
import 'zen_log_level.dart';

/// Configuration settings for Zenify framework
class ZenConfig {
  ZenConfig._(); // Private constructor

  // ============================================================================
  // LOGGING CONFIGURATION
  // ============================================================================

  /// Current log level (default: warning for production safety)
  static ZenLogLevel logLevel =
  kDebugMode ? ZenLogLevel.info : ZenLogLevel.warning;

  /// Enable/disable Rx tracking logs separately (default: false)
  /// ⚠️ WARNING: This creates VERY verbose logs. Only enable when:
  /// - Debugging memory leaks related to observables
  /// - Verifying reactive subscriptions are properly disposed
  /// - Developing the Zenify framework itself
  static bool enableRxTracking = false;

  /// Legacy property for backward compatibility
  @Deprecated('Use logLevel instead. Will be removed in v1.0')
  static bool get enableDebugLogs => logLevel.level >= ZenLogLevel.debug.level;

  @Deprecated('Use logLevel instead. Will be removed in v1.0')
  static set enableDebugLogs(bool value) {
    logLevel = value ? ZenLogLevel.debug : ZenLogLevel.warning;
  }

  /// Navigation and routing logging
  static bool enableNavigationLogging = false;
  static bool enableRouteLogging = false;

  // ============================================================================
  // PERFORMANCE & METRICS CONFIGURATION
  // ============================================================================

  /// Enable performance tracking (primary name)
  static bool enablePerformanceTracking = false;

  /// Alias for enablePerformanceTracking to match naming in other areas
  static bool get enablePerformanceMetrics => enablePerformanceTracking;
  static set enablePerformanceMetrics(bool value) =>
      enablePerformanceTracking = value;

  /// Enable general metrics collection
  static bool enableMetrics = false;

  // ============================================================================
  // LIFECYCLE & DISPOSAL CONFIGURATION
  // ============================================================================

  /// Enable automatic disposal of controllers
  static bool enableAutoDispose = true;

  /// Alias for backward compatibility
  static bool get autoDispose => enableAutoDispose;
  static set autoDispose(bool value) => enableAutoDispose = value;

  /// How long to cache controllers before disposal
  static Duration controllerCacheExpiry = const Duration(minutes: 10);

  /// Maximum time to wait for async dispose operations (in milliseconds)
  static int disposeTimeoutMs = 5000;

  // ============================================================================
  // DEVELOPMENT & DEBUG FEATURES
  // ============================================================================

  /// Strict mode - throw exceptions for misuse
  static bool strictMode = false;

  /// Alias for consistency
  static bool get enableStrictMode => strictMode;
  static set enableStrictMode(bool value) => strictMode = value;

  /// Whether to check for circular dependencies
  static bool checkForCircularDependencies = true;

  /// Whether to enable dependency visualization
  static bool enableDependencyVisualization = false;

  /// Whether to use Rx tracking for reactive values
  static bool useRxTracking = true;

  // ============================================================================
  // UTILITY GETTERS
  // ============================================================================

  /// Check if route/navigation logging should occur
  /// This respects both the flag AND the log level
  static bool get shouldLogRoutes =>
      enableRouteLogging && ZenLogLevel.info.shouldLog(logLevel);

  static bool get shouldLogNavigation =>
      enableNavigationLogging && ZenLogLevel.info.shouldLog(logLevel);

  // ============================================================================
  // CONFIGURATION PRESETS
  // ============================================================================

  /// Reset all settings to defaults
  static void reset() {
    // Logging
    logLevel = kDebugMode ? ZenLogLevel.info : ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;

    // Performance & Metrics
    enablePerformanceTracking = false;
    enableMetrics = false;

    // Lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // Development Features
    strictMode = false;
    checkForCircularDependencies = true;
    enableDependencyVisualization = false;
    useRxTracking = true;
  }

  /// Get current configuration as a map (for debugging)
  static Map<String, dynamic> toMap() {
    return {
      'logLevel': logLevel.toString(),
      'enableRxTracking': enableRxTracking,
      'enableNavigationLogging': enableNavigationLogging,
      'enableRouteLogging': enableRouteLogging,
      'enablePerformanceTracking': enablePerformanceTracking,
      'enablePerformanceMetrics': enablePerformanceMetrics,
      'enableMetrics': enableMetrics,
      'enableAutoDispose': enableAutoDispose,
      'autoDispose': autoDispose,
      'controllerCacheExpiry': controllerCacheExpiry.toString(),
      'disposeTimeoutMs': disposeTimeoutMs,
      'strictMode': strictMode,
      'enableStrictMode': enableStrictMode,
      'checkForCircularDependencies': checkForCircularDependencies,
      'enableDependencyVisualization': enableDependencyVisualization,
      'useRxTracking': useRxTracking,
      'shouldLogRoutes': shouldLogRoutes,
      'shouldLogNavigation': shouldLogNavigation,
    };
  }

  // ============================================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================================

  /// Apply predefined environment configuration
  ///
  /// Type-safe way to configure Zenify for different environments.
  ///
  /// Example:
  /// ```dart
  /// // Type-safe (recommended)
  /// ZenConfig.applyEnvironment(ZenEnvironment.production);
  ///
  /// // String-based (legacy support)
  /// ZenConfig.applyEnvironment('production');
  /// ```
  static void applyEnvironment(dynamic environment) {
    final ZenEnvironment env;

    if (environment is ZenEnvironment) {
      env = environment;
    } else if (environment is String) {
      env = ZenEnvironment.fromString(environment);
    } else {
      throw ArgumentError(
          'Environment must be ZenEnvironment or String, got ${environment.runtimeType}');
    }

    switch (env) {
      case ZenEnvironment.production:
        _applyProductionConfig();
        break;

      case ZenEnvironment.productionVerbose:
        _applyProductionVerboseConfig();
        break;

      case ZenEnvironment.staging:
        _applyStagingConfig();
        break;

      case ZenEnvironment.development:
        _applyDevelopmentConfig();
        break;

      case ZenEnvironment.debug:
        _applyDebugConfig();
        break;

      case ZenEnvironment.trace:
        _applyTraceConfig();
        break;

      case ZenEnvironment.test:
        _applyTestConfig();
        break;
    }
  }

  // Private configuration methods for each environment

  static void _applyProductionConfig() {
    // Minimal logging
    logLevel = ZenLogLevel.error;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;

    // No performance tracking
    enablePerformanceTracking = false;
    enableMetrics = false;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // No debug features
    strictMode = false;
    checkForCircularDependencies = false;
    enableDependencyVisualization = false;
    useRxTracking = true;
  }

  static void _applyProductionVerboseConfig() {
    // Moderate logging
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;

    // Some metrics for monitoring
    enablePerformanceTracking = true;
    enableMetrics = true;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // Light debug features
    strictMode = false;
    checkForCircularDependencies = true;
    enableDependencyVisualization = false;
    useRxTracking = true;
  }

  static void _applyStagingConfig() {
    // Moderate logging
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;

    // Some metrics for monitoring
    enablePerformanceTracking = true;
    enableMetrics = true;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // Light debug features
    strictMode = false;
    checkForCircularDependencies = true;
    enableDependencyVisualization = false;
    useRxTracking = true;
  }

  static void _applyDevelopmentConfig() {
    // Detailed logging
    logLevel = ZenLogLevel.info;
    enableRxTracking = false; // Still too verbose for general dev
    enableNavigationLogging = true;
    enableRouteLogging = true;

    // Full metrics
    enablePerformanceTracking = true;
    enableMetrics = true;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // All debug features
    strictMode = true;
    checkForCircularDependencies = true;
    enableDependencyVisualization = true;
    useRxTracking = true;
  }

  static void _applyDebugConfig() {
    // Very detailed logging
    logLevel = ZenLogLevel.debug;
    enableRxTracking = false; // Enable manually if needed
    enableNavigationLogging = true;
    enableRouteLogging = true;

    // Full metrics
    enablePerformanceTracking = true;
    enableMetrics = true;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // All debug features with strict mode
    strictMode = true;
    checkForCircularDependencies = true;
    enableDependencyVisualization = true;
    useRxTracking = true;
  }

  static void _applyTraceConfig() {
    // Extreme verbosity
    logLevel = ZenLogLevel.trace;
    enableRxTracking = true; // ⚠️ VERY VERBOSE
    enableNavigationLogging = true;
    enableRouteLogging = true;

    // Full metrics
    enablePerformanceTracking = true;
    enableMetrics = true;

    // Standard lifecycle
    enableAutoDispose = true;
    controllerCacheExpiry = const Duration(minutes: 10);
    disposeTimeoutMs = 5000;

    // All debug features
    strictMode = true;
    checkForCircularDependencies = true;
    enableDependencyVisualization = true;
    useRxTracking = true;
  }

  static void _applyTestConfig() {
    // Test-friendly logging
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;

    // No metrics in tests
    enablePerformanceTracking = false;
    enableMetrics = false;

    // Disable auto-dispose for test stability
    enableAutoDispose = false;
    controllerCacheExpiry = const Duration(minutes: 30);
    disposeTimeoutMs = 10000; // Longer timeout for tests

    // Strict mode for catching errors
    strictMode = true;
    checkForCircularDependencies = true;
    enableDependencyVisualization = false;
    useRxTracking = true;
  }

  // ============================================================================
  // CUSTOM CONFIGURATION
  // ============================================================================

  /// Apply custom configuration with fine-grained control
  ///
  /// Example:
  /// ```dart
  /// ZenConfig.configure(
  ///   level: ZenLogLevel.info,
  ///   performanceTracking: true,
  ///   strict: true,
  /// );
  /// ```
  static void configure({
    // Logging
    ZenLogLevel? level,
    bool? rxTracking,
    bool? navigationLogging,
    bool? routeLogging,

    // Performance & Metrics
    bool? performanceTracking,
    bool? metrics,

    // Lifecycle
    bool? autoDispose,
    Duration? cacheExpiry,
    int? disposeTimeout,

    // Development Features
    bool? strict,
    bool? circularDependencyCheck,
    bool? dependencyVisualization,
    bool? useRxTrack,

    // Legacy support
    @Deprecated('Use level parameter instead') bool? debugLogs,
  }) {
    // Logging
    if (level != null) logLevel = level;
    if (rxTracking != null) enableRxTracking = rxTracking;
    if (navigationLogging != null) enableNavigationLogging = navigationLogging;
    if (routeLogging != null) enableRouteLogging = routeLogging;

    // Performance & Metrics
    if (performanceTracking != null) {
      enablePerformanceTracking = performanceTracking;
    }
    if (metrics != null) enableMetrics = metrics;

    // Lifecycle
    if (autoDispose != null) enableAutoDispose = autoDispose;
    if (cacheExpiry != null) controllerCacheExpiry = cacheExpiry;
    if (disposeTimeout != null) disposeTimeoutMs = disposeTimeout;

    // Development Features
    if (strict != null) strictMode = strict;
    if (circularDependencyCheck != null) {
      checkForCircularDependencies = circularDependencyCheck;
    }
    if (dependencyVisualization != null) {
      enableDependencyVisualization = dependencyVisualization;
    }
    if (useRxTrack != null) useRxTracking = useRxTrack;

    // Legacy support
    if (debugLogs != null) {
      logLevel = debugLogs ? ZenLogLevel.debug : ZenLogLevel.warning;
    }
  }

  // ============================================================================
  // CONVENIENCE METHODS (for backward compatibility)
  // ============================================================================

  /// Apply development configuration (shorthand)
  static void configureDevelopment() => applyEnvironment(ZenEnvironment.development);

  /// Apply production configuration (shorthand)
  static void configureProduction() => applyEnvironment(ZenEnvironment.production);

  /// Apply test configuration (shorthand)
  static void configureTest() => applyEnvironment(ZenEnvironment.test);
}