// lib/zenify.dart
// Main barrel file for Zenify library

library;

// Core components
export 'core/core.dart';

// Dependency Injection system
export 'di/di.dart';

// Controllers
export 'controllers/controllers.dart';

// Reactive state
export 'reactive/reactive.dart';

// Widgets
export 'widgets/widgets.dart';

// Workers
export 'workers/workers.dart';

// Effects
export 'effects/effects.dart';

// Testing utilities
export 'testing/testing.dart';

// Re-export key classes for direct import convenience
export 'controllers/zen_controller.dart' show ZenController;
export 'di/zen_di.dart' show Zen;
export 'di/zen_lifecycle.dart';

// Re-export worker functions
export 'workers/zen_workers.dart' show ZenWorkers;

// Widget builders for convenient access
export 'widgets/rx_widgets.dart' show Obx;
export 'widgets/zen_builder.dart' show ZenBuilder;
export 'widgets/zen_scope_widget.dart' show ZenScopeWidget;