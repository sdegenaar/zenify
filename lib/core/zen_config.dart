// lib/zenify/zen_config.dart

/// Configuration settings for ZenState framework
class ZenConfig {
  ZenConfig._(); // Private constructor

  /// Debug settings
  static bool enableDebugLogs = false;
  static bool strictMode = false;  // Throw exceptions for misuse

  /// Performance and metrics settings
  static bool enablePerformanceTracking = false;

  /// Alias for enablePerformanceTracking to match naming in other areas
  static bool get enablePerformanceMetrics => enablePerformanceTracking;
  static set enablePerformanceMetrics(bool value) => enablePerformanceTracking = value;

  /// New metrics settings
  static bool enableMetrics = false;

  /// Auto-dispose settings
  static bool enableAutoDispose = true;
  static Duration controllerCacheExpiry = Duration(minutes: 10);

  /// Navigation and routing settings
  static bool enableNavigationLogging = false;
  static bool enableRouteLogging = false;

  /// Feature flags
  static bool useRxTracking = true;

  /// Whether to check for circular dependencies
  static bool checkForCircularDependencies = true;

  /// Whether to enable dependency visualization
  static bool enableDependencyVisualization = false;




  /// Reset all settings to defaults
  static void reset() {
    enableDebugLogs = false;
    strictMode = false;
    enablePerformanceTracking = false;
    enableMetrics = false;
    enableAutoDispose = true;
    controllerCacheExpiry = Duration(minutes: 30);
    enableNavigationLogging = false;
    enableRouteLogging = false;
    useRxTracking = true;
    enableDependencyVisualization = false;
  }

  /// Apply settings for different environments
  static void applyEnvironment(String env) {
    switch (env) {
      case 'dev':
        enableDebugLogs = true;
        strictMode = true;
        enablePerformanceTracking = true;
        enableMetrics = true;
        enableNavigationLogging = true;
        enableRouteLogging = true;
        enableDependencyVisualization = true;
        break;
      case 'test':
        enableDebugLogs = true;
        strictMode = true;
        enableAutoDispose = false;
        enableMetrics = false;
        enableNavigationLogging = false;
        enableRouteLogging = false;
        break;
      case 'prod':
        enableDebugLogs = false;
        strictMode = false;
        enablePerformanceTracking = false;
        enableMetrics = false;
        enableNavigationLogging = false;
        enableRouteLogging = false;
        break;
    }
  }

  /// Apply custom configuration
  static void configure({
    bool? debugLogs,
    bool? strict,
    bool? performanceTracking,
    bool? metrics,
    bool? autoDispose,
    Duration? cacheExpiry,
    bool? navigationLogging,
    bool? routeLogging,
    bool? rxTracking,
  }) {
    if (debugLogs != null) enableDebugLogs = debugLogs;
    if (strict != null) strictMode = strict;
    if (performanceTracking != null) enablePerformanceTracking = performanceTracking;
    if (metrics != null) enableMetrics = metrics;
    if (autoDispose != null) enableAutoDispose = autoDispose;
    if (cacheExpiry != null) controllerCacheExpiry = cacheExpiry;
    if (navigationLogging != null) enableNavigationLogging = navigationLogging;
    if (routeLogging != null) enableRouteLogging = routeLogging;
    if (rxTracking != null) useRxTracking = rxTracking;
  }

  /// Apply development configuration
  static void configureDevelopment() {
    applyEnvironment('dev');
  }

  /// Apply production configuration
  static void configureProduction() {
    applyEnvironment('prod');
  }

  /// Apply test configuration
  static void configureTest() {
    applyEnvironment('test');
  }
}