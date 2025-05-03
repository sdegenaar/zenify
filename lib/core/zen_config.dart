// lib/zen_state/zen_config.dart

/// Configuration settings for ZenState framework
class ZenConfig {
  ZenConfig._(); // Private constructor

  /// Debug settings
  static bool enableDebugLogs = false;
  static bool strictMode = false;  // Throw exceptions for misuse

  /// Performance settings
  static bool enablePerformanceTracking = false;

  /// Alias for enablePerformanceTracking to match naming in other areas
  static bool get enablePerformanceMetrics => enablePerformanceTracking;

  /// Auto-dispose settings
  static bool enableAutoDispose = true;
  static Duration controllerCacheExpiry = Duration(minutes: 10);

  /// Feature flags
  static bool useRxTracking = true;

  /// Apply settings for different environments
  static void applyEnvironment(String env) {
    switch (env) {
      case 'dev':
        enableDebugLogs = true;
        strictMode = true;
        enablePerformanceTracking = true;
        break;
      case 'test':
        enableDebugLogs = true;
        strictMode = true;
        enableAutoDispose = false;
        break;
      case 'prod':
        enableDebugLogs = false;
        strictMode = false;
        enablePerformanceTracking = false;
        break;
    }
  }

  /// Apply custom configuration
  static void configure({
    bool? debugLogs,
    bool? strict,
    bool? performanceTracking,
    bool? autoDispose,
    Duration? cacheExpiry,
    bool? rxTracking,
  }) {
    if (debugLogs != null) enableDebugLogs = debugLogs;
    if (strict != null) strictMode = strict;
    if (performanceTracking != null) enablePerformanceTracking = performanceTracking;
    if (autoDispose != null) enableAutoDispose = autoDispose;
    if (cacheExpiry != null) controllerCacheExpiry = cacheExpiry;
    if (rxTracking != null) useRxTracking = rxTracking;
  }
}