
// lib/zen_state.dart
// Main barrel file for ZenState library

// Core components
export 'core/core.dart';

// Controllers
export 'controllers/controllers.dart';

// Reactive state
export 'reactive/reactive.dart';

// Widgets
export 'widgets/widgets.dart';

// Workers
export 'workers/workers.dart';

// Testing utilities
export 'testing/testing.dart';

// Common type aliases and utility methods
// Now just directly export from rx_value.dart where these functions are defined
export 'reactive/rx_value.dart' show
Rx,
rxBool, rxInt, rxDouble, rxString,
RxBool, RxInt, RxDouble, RxString;

// Reexport the Rx collections and convenience constructors
export 'reactive/rx_collections.dart' show
RxList, RxMap, RxSet,
rxList, rxMap, rxSet,
ListObsExtension, MapObsExtension, SetObsExtension;

// Reexport Zen class
export 'controllers/zen_controller.dart' show Zen, ZenController;

// Re-export worker functions
export 'workers/rx_workers.dart' show ZenWorkers;

// Export widget builders
export 'widgets/rx_widgets.dart' show Obx, RiverpodObx;
export 'widgets/zen_builder.dart' show ZenBuilder;