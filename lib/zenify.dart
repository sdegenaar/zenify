// lib/zenify.dart

/// Zenify - Modern Flutter state management
///
/// Clean, simple, powerful.
library;

// ===== CORE DI SYSTEM =====
export 'di/zen_di.dart' show Zen;
export 'di/zen_refs.dart' show Ref;
export 'di/zen_lifecycle.dart';
export 'di/zen_reactive.dart';

// ===== CONTROLLERS & SERVICES =====
export 'controllers/zen_controller.dart';
export 'controllers/zen_service.dart';
export 'controllers/zen_controller_scope.dart';
export 'controllers/zen_route_observer.dart';

// ===== SCOPES & MODULES =====
export 'core/zen_scope.dart';
export 'core/zen_module.dart';

// ===== REACTIVE SYSTEM =====
export 'reactive/reactive.dart';

// ===== WIDGETS =====
export 'widgets/builders/zen_builder.dart';
export 'widgets/components/zen_route.dart';
export 'widgets/scope/zen_scope_widget.dart';
export 'widgets/scope/zen_consumer.dart';
export 'widgets/components/zen_view.dart';
export 'widgets/builders/zen_effect_builder.dart';
export 'widgets/components/rx_widgets.dart';

// ===== WORKERS & EFFECTS =====
export 'workers/zen_workers.dart';
export 'effects/zen_effects.dart';

// Query system
export 'query/query.dart';

// ===== CONFIGURATION =====
export 'core/zen_config.dart';
export 'core/zen_environment.dart';
export 'core/zen_log_level.dart';
export 'core/zen_logger.dart';
export 'core/zen_metrics.dart';

// ===== UTILITIES =====
export 'utils/zen_scope_inspector.dart';

// ===== ERROR HANDLING =====
export 'testing/testing.dart';

// ===== MIXINS =====
export 'mixins/zen_ticker_provider.dart';

// ===== EXTENSIONS =====
export 'query/extensions/zen_scope_query_extension.dart';

// ===== DEBUG UTILITIES =====
// Separate namespace - not part of main API
export 'debug/zen_debug.dart' show ZenDebug;
