// lib/controllers/zen_controller.dart
import 'package:flutter/widgets.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';
import '../reactive/core/rx_value.dart';
import '../workers/zen_workers.dart';
import '../effects/zen_effects.dart';

/// Base controller class with automatic memory leak prevention and smart DI
abstract class ZenController with WidgetsBindingObserver {
  // Internal state tracking
  final DateTime _createdAt = DateTime.now();
  bool _disposed = false;
  bool _initialized = false;
  bool _ready = false;
  bool _observingAppLifecycle = false;

  // MEMORY LEAK PREVENTION: Auto-track reactive objects
  final List<Rx> _reactiveObjects = [];

  // Resource collections with optimized management
  final List<ZenWorkerHandle> _workers = [];
  final List<ZenWorkerGroup> _workerGroups = [];
  final List<ZenEffect> _effects = [];
  final List<void Function()> _disposers = [];

  // Maps update IDs to their listener callbacks for selective UI updates
  final Map<String, Set<VoidCallback>> _updateListeners = {};

  // Performance tracking
  int _updateCount = 0;
  int _workerCreationCount = 0;

  // Public getters
  DateTime get createdAt => _createdAt;
  bool get isDisposed => _disposed;
  bool get isInitialized => _initialized;
  bool get isReady => _ready;

  //
  // REACTIVE OBJECT AUTO-TRACKING
  //

  /// Create and auto-track a reactive variable - PREVENTS MEMORY LEAKS
  Rx<T> obs<T>(T initialValue) {
    if (_disposed) {
      throw StateError('Cannot create reactive object on disposed controller');
    }

    final rx = Rx<T>(initialValue);
    _trackReactiveObject(rx);
    return rx;
  }

  /// Create and auto-track a reactive list - PREVENTS MEMORY LEAKS
  RxList<T> obsList<T>([List<T>? initialValue]) {
    if (_disposed) {
      throw StateError('Cannot create reactive list on disposed controller');
    }

    final rxList = RxList<T>(initialValue ?? <T>[]);
    _trackReactiveObject(rxList);
    return rxList;
  }

  /// Create and auto-track a reactive map - PREVENTS MEMORY LEAKS
  RxMap<K, V> obsMap<K, V>([Map<K, V>? initialValue]) {
    if (_disposed) {
      throw StateError('Cannot create reactive map on disposed controller');
    }

    final rxMap = RxMap<K, V>(initialValue ?? <K, V>{});
    _trackReactiveObject(rxMap);
    return rxMap;
  }

  /// Create and auto-track a reactive set - PREVENTS MEMORY LEAKS
  RxSet<T> obsSet<T>([Set<T>? initialValue]) {
    if (_disposed) {
      throw StateError('Cannot create reactive set on disposed controller');
    }

    final rxSet = RxSet<T>(initialValue ?? <T>{});
    _trackReactiveObject(rxSet);
    return rxSet;
  }

  /// Manually track a reactive object (for external reactive objects)
  void trackReactive(Rx reactive) {
    if (!_disposed) {
      _trackReactiveObject(reactive);
    }
  }

  /// Internal method to track reactive objects with duplicate prevention
  void _trackReactiveObject(Rx reactive) {
    if (!_reactiveObjects.contains(reactive)) {
      _reactiveObjects.add(reactive);
      ZenLogger.logDebug(
          'Controller $runtimeType: Tracking reactive ${reactive.runtimeType} (total: ${_reactiveObjects.length})');
    }
  }

  /// Get count of tracked reactive objects for debugging
  int get reactiveObjectCount => _reactiveObjects.length;

  /// Get stats about reactive objects
  Map<String, int> get reactiveStats {
    final stats = <String, int>{};
    for (final reactive in _reactiveObjects) {
      final type = reactive.runtimeType.toString();
      stats[type] = (stats[type] ?? 0) + 1;
    }
    return stats;
  }

  //
  // LIFECYCLE METHODS
  //

  @mustCallSuper
  void onInit() {
    if (_initialized) return;
    _initialized = true;

    ZenLogger.logInfo('Controller $runtimeType initialized');

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('controller.initialized');
    }
  }

  @mustCallSuper
  void onReady() {
    if (_ready) return;
    _ready = true;

    ZenLogger.logInfo('Controller $runtimeType ready');

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('controller.ready');
    }
  }

  /// Called when the app is resumed (comes back to foreground)
  @mustCallSuper
  void onResume() {
    if (_checkDisposed('onResume')) return;

    ZenLogger.logInfo('Controller $runtimeType resumed');
    resumeAllWorkers();
  }

  /// Called when the app is paused (goes to background)
  @mustCallSuper
  void onPause() {
    if (_checkDisposed('onPause')) return;

    ZenLogger.logInfo('Controller $runtimeType paused');
    pauseAllWorkers();
  }

  /// Called when the app is inactive
  @mustCallSuper
  void onInactive() {
    if (_checkDisposed('onInactive')) return;
    ZenLogger.logDebug('Controller $runtimeType inactive');
  }

  /// Called when the app is detached
  @mustCallSuper
  void onDetached() {
    if (_checkDisposed('onDetached')) return;
    ZenLogger.logDebug('Controller $runtimeType detached');
  }

  /// Called when the app is hidden
  @mustCallSuper
  void onHidden() {
    if (_checkDisposed('onHidden')) return;
    ZenLogger.logDebug('Controller $runtimeType hidden');
  }

  /// User-defined cleanup hook - called before internal disposal
  @mustCallSuper
  void onClose() {
    ZenLogger.logDebug('Controller $runtimeType onClose called');
  }

  //
  // APP LIFECYCLE MANAGEMENT
  //

  /// Start observing app lifecycle events
  void startObservingAppLifecycle() {
    if (!_observingAppLifecycle && !_disposed) {
      WidgetsBinding.instance.addObserver(this);
      _observingAppLifecycle = true;
    }
  }

  /// Stop observing app lifecycle events
  void stopObservingAppLifecycle() {
    if (_observingAppLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingAppLifecycle = false;
    }
  }

  /// Override from WidgetsBindingObserver to handle app lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_disposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.paused:
        onPause();
        break;
      case AppLifecycleState.inactive:
        onInactive();
        break;
      case AppLifecycleState.detached:
        onDetached();
        break;
      case AppLifecycleState.hidden:
        onHidden();
        break;
    }
  }

  //
  // WORKER MANAGEMENT
  //

  /// Pause all workers managed by this controller
  void pauseAllWorkers() {
    if (_checkDisposed('pauseAllWorkers')) return;

    _batchWorkerOperation(
      (worker) => worker.pause(),
      (group) => group.pauseAll(),
    );

    ZenLogger.logDebug('Controller $runtimeType: All workers paused');
  }

  /// Resume all workers managed by this controller
  void resumeAllWorkers() {
    if (_checkDisposed('resumeAllWorkers')) return;

    _batchWorkerOperation(
      (worker) => worker.resume(),
      (group) => group.resumeAll(),
    );

    ZenLogger.logDebug('Controller $runtimeType: All workers resumed');
  }

  /// Pause workers - convenience method for UI callbacks (no parameters)
  void pauseWorkers() => pauseAllWorkers();

  /// Resume workers - convenience method for UI callbacks (no parameters)
  void resumeWorkers() => resumeAllWorkers();

  /// Get count of active watchers (useful for debugging)
  int get activeWatcherCount => _workers.where((w) => !w.isDisposed).length;

  /// Get worker statistics for debugging/monitoring
  Map<String, dynamic> getWorkerStats() {
    _cleanupDisposedWorkers();

    final workersInGroups = <ZenWorkerHandle>{};
    for (final group in _workerGroups) {
      if (!group.isDisposed) {
        workersInGroups.addAll(group.workers);
      }
    }

    final individualWorkers =
        _workers.where((w) => !workersInGroups.contains(w));
    final individualActive =
        individualWorkers.where((w) => !w.isDisposed && w.isActive).length;
    final individualPaused =
        individualWorkers.where((w) => !w.isDisposed && w.isPaused).length;

    final groupActive = _workerGroups.fold<int>(
      0,
      (sum, group) => group.isDisposed ? sum : sum + group.activeCount,
    );
    final groupPaused = _workerGroups.fold<int>(
      0,
      (sum, group) => group.isDisposed ? sum : sum + group.pausedCount,
    );
    final groupTotal = _workerGroups.fold<int>(
      0,
      (sum, group) => group.isDisposed ? sum : sum + group.length,
    );

    return {
      'individual_active': individualActive,
      'individual_paused': individualPaused,
      'group_active': groupActive,
      'group_paused': groupPaused,
      'group_total': groupTotal,
      'total_active': individualActive + groupActive,
      'total_paused': individualPaused + groupPaused,
      'worker_creation_count': _workerCreationCount,
    };
  }

  //
  // RESOURCE MANAGEMENT
  //

  /// Add a disposer function that will be called when the controller is disposed
  void addDisposer(void Function() disposer) {
    if (_checkDisposed('addDisposer')) return;
    _disposers.add(disposer);
  }

  /// Create an effect that will be auto-disposed with this controller
  ZenEffect<T> createEffect<T>({required String name}) {
    if (_checkDisposed('createEffect')) {
      throw StateError('Cannot create effect on disposed controller');
    }
    final effect = ZenEffect<T>(name: name);
    _effects.add(effect);
    return effect;
  }

  //
  // LEGACY WORKER CREATION METHODS (Preserved for backward compatibility)
  //

  /// Create workers that auto-dispose with controller
  ZenWorkerHandle watch<T>(
    ValueNotifier<T> observable,
    void Function(T) callback, {
    WorkerType type = WorkerType.ever,
    Duration? duration,
    bool Function(T)? condition,
  }) {
    return _createWorker(
        () => ZenWorkers.watch<T>(
              observable,
              callback,
              type: type,
              duration: duration,
              condition: condition,
            ),
        'watch');
  }

  /// Type-safe convenience worker methods
  ZenWorkerHandle ever<T>(ValueNotifier<T> obs, void Function(T) callback) {
    return _createWorker(() => ZenWorkers.ever<T>(obs, callback), 'ever');
  }

  ZenWorkerHandle once<T>(ValueNotifier<T> obs, void Function(T) callback) {
    return _createWorker(() => ZenWorkers.once<T>(obs, callback), 'once');
  }

  ZenWorkerHandle debounce<T>(
    ValueNotifier<T> obs,
    void Function(T) callback,
    Duration duration,
  ) {
    if (duration.isNegative || duration == Duration.zero) {
      throw ArgumentError('Debounce duration must be positive');
    }
    return _createWorker(
        () => ZenWorkers.debounce<T>(obs, callback, duration), 'debounce');
  }

  ZenWorkerHandle throttle<T>(
    ValueNotifier<T> obs,
    void Function(T) callback,
    Duration duration,
  ) {
    if (duration.isNegative || duration == Duration.zero) {
      throw ArgumentError('Throttle duration must be positive');
    }
    return _createWorker(
        () => ZenWorkers.throttle<T>(obs, callback, duration), 'throttle');
  }

  ZenWorkerHandle interval<T>(
    ValueNotifier<T> obs,
    void Function(T) callback,
    Duration duration,
  ) {
    if (duration.isNegative || duration == Duration.zero) {
      throw ArgumentError('Interval duration must be positive');
    }
    return _createWorker(
        () => ZenWorkers.interval<T>(obs, callback, duration), 'interval');
  }

  ZenWorkerHandle condition<T>(
    ValueNotifier<T> obs,
    bool Function(T) condition,
    void Function(T) callback,
  ) {
    return _createWorker(
        () => ZenWorkers.condition<T>(obs, condition, callback), 'condition');
  }

  /// Create a managed worker group
  ZenWorkerGroup createWorkerGroup() {
    if (_checkDisposed('createWorkerGroup')) {
      throw StateError('Cannot create worker group on disposed controller');
    }
    final group = ZenWorkers.group();
    _workerGroups.add(group);
    _workerCreationCount++;
    return group;
  }

  //
  // UPDATE LISTENER MANAGEMENT
  //

  /// Register a listener for a specific update ID
  void addUpdateListener(String updateId, VoidCallback listener) {
    if (_checkDisposed('addUpdateListener')) return;
    _updateListeners
        .putIfAbsent(updateId, () => <VoidCallback>{})
        .add(listener);
  }

  /// Remove a listener for a specific update ID
  void removeUpdateListener(String updateId, VoidCallback listener) {
    if (_disposed) return;

    _updateListeners[updateId]?.remove(listener);
    if (_updateListeners[updateId]?.isEmpty == true) {
      _updateListeners.remove(updateId);
    }
  }

  /// Optimized update method that can notify specific listeners or all listeners
  void update([List<String>? updateIds]) {
    if (_checkDisposed('update')) return;

    _updateCount++;

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('controller.update');
    }

    if (updateIds?.isEmpty ?? true) {
      final allListeners =
          _updateListeners.values.expand((set) => set).toList();
      _notifyListeners(allListeners);
    } else {
      final listenersToNotify = <VoidCallback>[];
      for (final updateId in updateIds!) {
        final listeners = _updateListeners[updateId];
        if (listeners != null) {
          listenersToNotify.addAll(listeners);
        }
      }
      _notifyListeners(listenersToNotify, updateIds);
    }

    if (_updateCount % 100 == 0) {
      _cleanupUpdateListeners();
    }
  }

  //
  // RESOURCE TRACKING AND DEBUGGING
  //

  /// Get comprehensive resource usage statistics
  Map<String, dynamic> getResourceStats() {
    _cleanupDisposedWorkers();

    return {
      'reactive_objects': _reactiveObjects.length,
      'reactive_types': reactiveStats,
      'workers': _workers.length,
      'worker_groups': _workerGroups.length,
      'effects': _effects.length,
      'disposers': _disposers.length,
      'update_listeners': _updateListeners.length,
      'total_listener_count':
          _updateListeners.values.fold<int>(0, (sum, set) => sum + set.length),
      'update_count': _updateCount,
      'worker_creation_count': _workerCreationCount,
      'memory_overhead_estimate': _estimateMemoryUsage(),
      'is_disposed': _disposed,
      'is_initialized': _initialized,
      'is_ready': _ready,
      'is_observing_lifecycle': _observingAppLifecycle,
      'uptime_seconds': DateTime.now().difference(_createdAt).inSeconds,
    };
  }

  /// Estimate memory usage in bytes (rough approximation)
  int _estimateMemoryUsage() {
    return (_reactiveObjects.length * 100) +
        (_workers.length * 100) +
        (_workerGroups.length * 200) +
        (_effects.length * 150) +
        (_disposers.length * 50) +
        (_updateListeners.length * 100) +
        (_updateListeners.values.fold<int>(0, (sum, set) => sum + set.length) *
            50);
  }

  //
  // ⭐ MEMORY LEAK PREVENTION: AUTO-DISPOSAL
  //

  /// Dispose all tracked reactive objects - PREVENTS MEMORY LEAKS
  void _disposeReactiveObjects() {
    if (_reactiveObjects.isNotEmpty) {
      ZenLogger.logDebug(
          'Controller $runtimeType: Disposing ${_reactiveObjects.length} reactive objects');
    }

    // Dispose all tracked reactive objects
    for (final reactive in _reactiveObjects) {
      try {
        reactive.dispose();
      } catch (e, stack) {
        ZenLogger.logError(
            'Error disposing reactive object ${reactive.runtimeType}',
            e,
            stack);
      }
    }

    _reactiveObjects.clear();

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('controller.reactive_objects_disposed');
    }
  }

  //
  // DISPOSAL - MEMORY LEAK SAFE
  //

  /// Dispose the controller and clean up ALL resources - PREVENTS MEMORY LEAKS
  @mustCallSuper
  void dispose() {
    if (_disposed) return;

    final stats = getResourceStats();
    // Changed from logDebug to logInfo - important lifecycle event
    ZenLogger.logInfo('Controller $runtimeType disposing... '
        'Resources: ${stats['reactive_objects']} reactive, ${stats['workers']} workers, '
        '${stats['effects']} effects, ${stats['disposers']} disposers');

    try {
      // Call user lifecycle method first
      onClose();
    } catch (e, stack) {
      ZenLogger.logError(
          'Error in onDispose for controller $runtimeType', e, stack);
    }

    // Mark as disposed early to prevent new operations
    _disposed = true;

    // Stop observing app lifecycle if we were
    stopObservingAppLifecycle();

    // ⭐ CRITICAL: Dispose all reactive objects first - PREVENTS MEMORY LEAKS
    _disposeReactiveObjects();

    // Dispose all workers efficiently
    _cleanupAllWorkers();

    // Dispose all effects
    _cleanupEffects();

    // Call all disposers
    _runDisposers();

    // Clear update listeners
    _updateListeners.clear();

    // Changed from logDebug to logInfo - important lifecycle event
    ZenLogger.logInfo('Controller $runtimeType disposed successfully');

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('controller.disposed');
    }
  }

  //
  // INTERNAL HELPER METHODS
  //

  /// Standard disposal check with optional operation logging
  bool _checkDisposed([String? operation]) {
    if (_disposed) {
      if (operation != null) {
        ZenLogger.logWarning(
            'Attempted $operation on disposed controller $runtimeType');
      }
      return true;
    }
    return false;
  }

  /// Optimized worker creation with validation and tracking
  ZenWorkerHandle _createWorker(ZenWorkerHandle Function() creator,
      [String? workerType]) {
    if (_checkDisposed('worker creation')) {
      throw StateError(
          'Cannot create ${workerType ?? 'worker'} on disposed controller');
    }

    final handle = creator();
    _workers.add(handle);
    _workerCreationCount++;
    return handle;
  }

  /// Batch worker operations for better performance
  void _batchWorkerOperation(
    void Function(ZenWorkerHandle) workerOp,
    void Function(ZenWorkerGroup) groupOp,
  ) {
    _cleanupDisposedWorkers();

    for (final worker in _workers) {
      if (!worker.isDisposed) {
        try {
          workerOp(worker);
        } catch (e, stack) {
          ZenLogger.logError('Error in worker operation', e, stack);
        }
      }
    }

    for (final group in _workerGroups) {
      if (!group.isDisposed) {
        try {
          groupOp(group);
        } catch (e, stack) {
          ZenLogger.logError('Error in worker group operation', e, stack);
        }
      }
    }
  }

  /// Clean up disposed workers from collections
  void _cleanupDisposedWorkers() {
    _workers.removeWhere((worker) => worker.isDisposed);
    _workerGroups.removeWhere((group) => group.isDisposed);
  }

  /// Efficiently dispose all workers
  void _cleanupAllWorkers() {
    for (final worker in _workers) {
      try {
        worker.dispose();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing worker', e, stack);
      }
    }
    _workers.clear();

    for (final group in _workerGroups) {
      try {
        group.dispose();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing worker group', e, stack);
      }
    }
    _workerGroups.clear();
  }

  /// Clean up all effects
  void _cleanupEffects() {
    for (final effect in _effects) {
      try {
        effect.dispose();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing effect', e, stack);
      }
    }
    _effects.clear();
  }

  /// Run all disposer functions
  void _runDisposers() {
    for (final disposer in _disposers) {
      try {
        disposer();
      } catch (e, stack) {
        ZenLogger.logError('Error in disposer', e, stack);
      }
    }
    _disposers.clear();
  }

  /// Notify listeners with error handling
  void _notifyListeners(List<VoidCallback> listeners,
      [List<String>? updateIds]) {
    for (final listener in listeners) {
      try {
        listener();
      } catch (e, stack) {
        final context =
            updateIds != null ? ' for IDs: ${updateIds.join(', ')}' : '';
        ZenLogger.logError('Error in update listener$context', e, stack);
      }
    }
  }

  /// Clean up disposed listeners periodically
  void _cleanupUpdateListeners() {
    _updateListeners.removeWhere((key, listeners) {
      listeners.removeWhere((listener) => false);
      return listeners.isEmpty;
    });
  }
}

/// Extension to add the `also` method for fluent API
extension FluentExtension<T> on T {
  T also(void Function(T) block) {
    block(this);
    return this;
  }
}

/// Extension for more fluent worker creation and control
extension ZenControllerWorkerExtension on ZenController {
  /// Create multiple workers in one call
  List<ZenWorkerHandle> createWorkers(
      List<ZenWorkerHandle Function()> creators) {
    if (isDisposed) {
      throw StateError('Cannot create workers on disposed controller');
    }
    return creators.map((creator) => creator()).toList();
  }

  /// Dispose specific workers
  void disposeWorkers(List<ZenWorkerHandle> workers) {
    for (final worker in workers) {
      try {
        worker.dispose();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing worker', e, stack);
      }
    }
  }

  /// Pause specific workers
  void pauseSpecificWorkers(List<ZenWorkerHandle> workers) {
    if (isDisposed) return;

    for (final worker in workers) {
      if (!worker.isDisposed) {
        try {
          worker.pause();
        } catch (e, stack) {
          ZenLogger.logError('Error pausing worker', e, stack);
        }
      }
    }
  }

  /// Resume specific workers
  void resumeSpecificWorkers(List<ZenWorkerHandle> workers) {
    if (isDisposed) return;

    for (final worker in workers) {
      if (!worker.isDisposed) {
        try {
          worker.resume();
        } catch (e, stack) {
          ZenLogger.logError('Error resuming worker', e, stack);
        }
      }
    }
  }
}

/// Advanced extension for specialized worker patterns
extension ZenControllerAdvancedExtension on ZenController {
  /// Worker that auto-disposes when a condition is met
  ZenWorkerHandle autoDispose<T>(
    ValueNotifier<T> obs,
    bool Function(T) disposeCondition,
    void Function(T) callback,
  ) {
    late ZenWorkerHandle handle;
    handle = ever<T>(obs, (value) {
      try {
        callback(value);
        if (disposeCondition(value)) {
          handle.dispose();
        }
      } catch (e, stack) {
        ZenLogger.logError('Error in autoDispose worker', e, stack);
        handle.dispose();
      }
    });
    return handle;
  }

  /// Worker that executes a limited number of times
  ZenWorkerHandle limited<T>(
    ValueNotifier<T> obs,
    void Function(T) callback,
    int maxExecutions,
  ) {
    if (maxExecutions <= 0) {
      throw ArgumentError('maxExecutions must be positive');
    }
    int count = 0;
    late ZenWorkerHandle handle;
    handle = ever<T>(obs, (value) {
      if (count < maxExecutions) {
        try {
          callback(value);
          count++;
          if (count >= maxExecutions) {
            handle.dispose();
          }
        } catch (e, stack) {
          ZenLogger.logError('Error in limited worker', e, stack);
          handle.dispose();
        }
      }
    });
    return handle;
  }
}

/// Mixin for DI integration hooks
mixin ZenDIIntegration on ZenController {
  void onDIRegistered() {
    ZenLogger.logDebug('Controller $runtimeType registered in DI system');
  }

  void onDIDisposing() {
    ZenLogger.logDebug('Controller $runtimeType disposing from DI system');
  }
}
