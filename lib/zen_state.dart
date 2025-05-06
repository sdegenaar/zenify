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

//Effects
export 'effects/effects.dart';

// Testing utilities
export 'testing/testing.dart';

// Export the common reactive interfaces and types (existing ones)
export 'reactive/rx_common.dart' show
ReactiveValue,
RxType,
ObsExtension,
IntObsExtension, DoubleObsExtension, BoolObsExtension, StringObsExtension;

// Rx value primitives (Level 1: Local state)
export 'reactive/rx_value.dart' show
Rx,
rxBool, rxInt, rxDouble, rxString,
RxBool, RxInt, RxDouble, RxString,
RxnBool, RxnDouble, RxnInt, RxnString,
RxIntExtension, RxDoubleExtension, RxBoolExtension, RxStringExtension;

// RxNotifier (Level 2: Transitional Riverpod)
export 'reactive/rx_notifier.dart' show
RxNotifier,
RiverpodRxBool, RiverpodRxInt, RiverpodRxDouble, RiverpodRxString,
RxNotifierIntExtension, RxNotifierDoubleExtension,
RxNotifierBoolExtension, RxNotifierStringExtension;

// Reactive collections
export 'reactive/rx_collections.dart' show
RxList, RxMap, RxSet,
rxList, rxMap, rxSet,
ListObsExtension, MapObsExtension, SetObsExtension;

// Tracking system (used internally, but exposed for extensions)
export 'reactive/rx_tracking.dart' show RxTracking;

// Reexport Zen class and controller
export 'controllers/zen_controller.dart' show ZenController;

// Re-export worker functions
export 'workers/rx_workers.dart' show ZenWorkers;

// Export widget builders
export 'widgets/rx_widgets.dart' show Obx, RiverpodObx;
export 'widgets/zen_builder.dart' show ZenBuilder;