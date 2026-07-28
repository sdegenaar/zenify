// lib/core/zen_config.dart
import 'package:flutter/foundation.dart';
import 'zen_environment.dart';
import 'zen_log_level.dart';

/// Configuration settings for Zenify framework
class ZenConfig {
  ZenConfig._(); // Private constructor // coverage:ignore-line

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

  /// Navigation and routing logging
  static bool enableNavigationLogging = false;
  static bool enableRouteLogging = false;

  /// Use verbose error formatting (boxed, multi-line)
  /// Default: false (compact single-line)
  ///
  /// When true, exceptions display in a detailed boxed format:
  /// ```
  /// ╔══════════════════════════════════════════════════════════╗
  /// ║ ❌ ZenDependencyNotFoundException                         ║
  /// ╠══════════════════════════════════════════════════════════╣
  /// ║ Dependency not found                                     ║
  /// ║ Type: UserService                                        ║
  /// ║ 💡 Suggestion: Zen.put(UserService());                    ║
  /// ╚══════════════════════════════════════════════════════════╝
  /// ```
  ///
  /// When false (default), exceptions use compact format:
  /// ```
  /// ❌ ZenDependencyNotFoundException: Dependency not found (Type=UserService)
  ///    💡 Zen.put(UserService());
  /// ```
  static bool verboseErrors = false;

  // ============================================================================
  // PERFORMANCE & METRICS CONFIGURATION
  // ============================================================================

  /// Enable performance metrics collection
  static bool enablePerformanceMetrics = false;

  // ============================================================================
  // DEVELOPMENT & DEBUG FEATURES
  // ============================================================================

  /// Strict mode - throw exceptions for misuse
  static bool strictMode = false;

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
    verboseErrors = false;

    // Performance & Metrics
    enablePerformanceMetrics = false;

    // Development Features
    strictMode = false;
  }

  /// Get current configuration as a map (for debugging)
  static Map<String, dynamic> toMap() {
    return {
      'logLevel': logLevel.toString(),
      'enableRxTracking': enableRxTracking,
      'enableNavigationLogging': enableNavigationLogging,
      'enableRouteLogging': enableRouteLogging,
      'verboseErrors': verboseErrors,
      'enablePerformanceMetrics': enablePerformanceMetrics,
      'strictMode': strictMode,
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
    logLevel = ZenLogLevel.error;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;
    enablePerformanceMetrics = false;
    strictMode = false;
  }

  static void _applyProductionVerboseConfig() {
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;
    enablePerformanceMetrics = true;
    strictMode = false;
  }

  static void _applyStagingConfig() {
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;
    enablePerformanceMetrics = true;
    strictMode = false;
  }

  static void _applyDevelopmentConfig() {
    logLevel = ZenLogLevel.info;
    enableRxTracking = false;
    enableNavigationLogging = true;
    enableRouteLogging = true;
    enablePerformanceMetrics = true;
    strictMode = true;
  }

  static void _applyDebugConfig() {
    logLevel = ZenLogLevel.debug;
    enableRxTracking = false;
    enableNavigationLogging = true;
    enableRouteLogging = true;
    enablePerformanceMetrics = true;
    strictMode = true;
  }

  static void _applyTraceConfig() {
    logLevel = ZenLogLevel.trace;
    enableRxTracking = true; // ⚠️ VERY VERBOSE
    enableNavigationLogging = true;
    enableRouteLogging = true;
    enablePerformanceMetrics = true;
    strictMode = true;
  }

  static void _applyTestConfig() {
    logLevel = ZenLogLevel.warning;
    enableRxTracking = false;
    enableNavigationLogging = false;
    enableRouteLogging = false;
    enablePerformanceMetrics = false;
    strictMode = true;
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
    ZenLogLevel? level,
    bool? rxTracking,
    bool? navigationLogging,
    bool? routeLogging,
    bool? performanceTracking,
    bool? strict,
  }) {
    if (level != null) logLevel = level;
    if (rxTracking != null) enableRxTracking = rxTracking;
    if (navigationLogging != null) enableNavigationLogging = navigationLogging;
    if (routeLogging != null) enableRouteLogging = routeLogging;
    if (performanceTracking != null) {
      enablePerformanceMetrics = performanceTracking;
    }
    if (strict != null) strictMode = strict;
  }

  // ============================================================================
  // CONVENIENCE METHODS (for backward compatibility)
  // ============================================================================

  /// Apply development configuration (shorthand)
  static void configureDevelopment() =>
      applyEnvironment(ZenEnvironment.development);

  /// Apply production configuration (shorthand)
  static void configureProduction() =>
      applyEnvironment(ZenEnvironment.production);

  /// Apply test configuration (shorthand)
  static void configureTest() => applyEnvironment(ZenEnvironment.test);
}
