// lib/core/zen_environment.dart

/// Predefined environment configurations for Zenify
///
/// Use these type-safe constants instead of hardcoded strings.
///
/// Example:
/// ```dart
/// ZenConfig.applyEnvironment(ZenEnvironment.development);
/// ```
enum ZenEnvironment {
  /// Production environment - minimal logging, no debug features
  ///
  /// Recommended for: Release builds, app store submissions
  ///
  /// Configuration:
  /// - Log Level: error
  /// - Rx Tracking: disabled
  /// - Performance Tracking: disabled
  /// - Strict Mode: disabled
  production('production'),

  /// Staging environment - moderate logging, performance metrics
  ///
  /// Recommended for: Pre-production testing, beta releases
  ///
  /// Configuration:
  /// - Log Level: warning
  /// - Rx Tracking: disabled
  /// - Performance Tracking: enabled
  /// - Strict Mode: disabled
  staging('staging'),

  /// Development environment - detailed logging, all debug features
  ///
  /// Recommended for: Active development, feature implementation
  ///
  /// Configuration:
  /// - Log Level: info
  /// - Rx Tracking: disabled (enable manually if needed)
  /// - Performance Tracking: enabled
  /// - Strict Mode: enabled
  development('development'),

  /// Debug environment - very detailed logging with strict mode
  ///
  /// Recommended for: Debugging specific issues, troubleshooting
  ///
  /// Configuration:
  /// - Log Level: debug
  /// - Rx Tracking: disabled (enable manually if needed)
  /// - Performance Tracking: enabled
  /// - Strict Mode: enabled
  debug('debug'),

  /// Trace environment - extreme verbosity including Rx tracking
  ///
  /// ⚠️ WARNING: Very verbose! Only use when debugging framework issues
  ///
  /// Recommended for: Debugging reactive state issues, memory leaks
  ///
  /// Configuration:
  /// - Log Level: trace
  /// - Rx Tracking: enabled
  /// - Performance Tracking: enabled
  /// - Strict Mode: enabled
  trace('trace'),

  /// Test environment - optimized for unit/widget testing
  ///
  /// Recommended for: Running automated tests
  ///
  /// Configuration:
  /// - Log Level: warning
  /// - Rx Tracking: disabled
  /// - Performance Tracking: disabled
  /// - Auto Dispose: disabled (for test stability)
  /// - Strict Mode: enabled
  test('test');

  const ZenEnvironment(this.value);

  /// The string value for backward compatibility
  final String value;

  /// Convert from string to enum (case-insensitive)
  ///
  /// Supports aliases:
  /// - 'prod' → production
  /// - 'stage' → staging
  /// - 'dev' → development
  static ZenEnvironment fromString(String value) {
    final normalized = value.toLowerCase();

    switch (normalized) {
      case 'production':
      case 'prod':
        return ZenEnvironment.production;

      case 'staging':
      case 'stage':
        return ZenEnvironment.staging;

      case 'development':
      case 'dev':
        return ZenEnvironment.development;

      case 'debug':
        return ZenEnvironment.debug;

      case 'trace':
        return ZenEnvironment.trace;

      case 'test':
        return ZenEnvironment.test;

      default:
        throw ArgumentError('Unknown environment: $value. '
            'Valid values: production, staging, development, debug, trace, test');
    }
  }

  @override
  String toString() => value;
}
