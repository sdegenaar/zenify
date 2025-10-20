// lib/core/zen_log_level.dart

/// Log levels for Zenify framework logging
///
/// Controls the verbosity of framework logs. Higher levels include all lower levels.
///
/// Example:
/// ```dart
/// // Production: Only errors
/// ZenConfig.logLevel = ZenLogLevel.error;
///
/// // Development: Info and above
/// ZenConfig.logLevel = ZenLogLevel.info;
///
/// // Debugging Rx issues: Everything including trace
/// ZenConfig.logLevel = ZenLogLevel.trace;
/// ```
enum ZenLogLevel {
  /// No logging at all (production)
  none(0),

  /// Only critical errors (recommended for production)
  error(1),

  /// Errors and warnings (recommended for production)
  warning(2),

  /// Errors, warnings, and general info (recommended for development)
  info(3),

  /// Detailed debug information (for development/debugging)
  debug(4),

  /// Very verbose including Rx tracking (only for debugging framework issues)
  /// ⚠️ WARNING: Creates excessive logs - only enable when debugging reactive state issues
  trace(5);

  const ZenLogLevel(this.level);

  final int level;

  /// Check if this log level should be logged given the configured level
  bool shouldLog(ZenLogLevel configuredLevel) {
    return level <= configuredLevel.level;
  }
}
