// lib/zenify/core/core.dart
// Core infrastructure components
//
// Zenify's core provides:
// - Configuration and logging (ZenConfig, ZenLogger)
// - Dependency injection (ZenScope, ZenModule)
// - Environment management (ZenEnvironment)
// - Metrics and monitoring (ZenMetrics)
//
// Architecture: Widget tree-based hierarchy (no global state)

export 'zen_config.dart';
export 'zen_logger.dart';
export 'zen_environment.dart';
export 'zen_log_level.dart';
export 'zen_metrics.dart';
export 'zen_module.dart';
export 'zen_scope.dart';
