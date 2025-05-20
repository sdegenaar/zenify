// lib/controllers/zen_controller.dart
import 'package:flutter/widgets.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';

/// Base controller class similar to GetX controller
///
/// Lifecycle methods:
/// - [onInit]: Called when the controller is first created. Override to initialize properties.
///   IMPORTANT: Always call super.onInit() at the END of your override.
/// - [onReady]: Called after init when the controller is ready. Override to load data.
///   IMPORTANT: Always call super.onReady() at the END of your override.
/// - [onDispose]: Called when the controller is disposed. Override to clean up resources.
///   IMPORTANT: Always call super.onDispose() at the END of your override.

abstract class ZenController with WidgetsBindingObserver {
  final List<VoidCallback> _disposers = [];
  final DateTime _createdAt = DateTime.now();
  bool _disposed = false;
  bool _initialized = false;
  bool _ready = false;
  bool _observingAppLifecycle = false;

  DateTime get createdAt => _createdAt;
  bool get isDisposed => _disposed;
  bool get isInitialized => _initialized;
  bool get isReady => _ready;

  /// Called when the controller is first created and registered
  /// This is a good place to initialize basic properties
  /// WARNING: Override onInit only if you call super.onInit() at the END of your override
  @mustCallSuper
  void onInit() {
    // If already initialized, don't proceed further
    if (_initialized) return;

    // Set the initialized flag
    _initialized = true;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType initialized');
    }
  }

  /// Called after init, when the controller is registered and ready for use
  /// Good place to fetch data or perform actions that depend on context/widgets
  /// WARNING: Override onReady only if you call super.onReady() at the END of your override
  @mustCallSuper
  void onReady() {
    // If already ready, don't proceed further
    if (_ready) return;

    // Set the ready flag
    _ready = true;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType ready');
    }
  }

  /// Called just before the controller is disposed
  /// Override this to add custom cleanup logic
  @mustCallSuper
  void onDispose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType onDispose called');
    }
  }

  /// Starts observing app lifecycle events
  /// Call this if you need app lifecycle callbacks
  void startObservingAppLifecycle() {
    if (_observingAppLifecycle) return;

    WidgetsBinding.instance.addObserver(this);
    _observingAppLifecycle = true;

    // Add disposer to clean up when controller is disposed
    addDisposer(() {
      if (_observingAppLifecycle) {
        WidgetsBinding.instance.removeObserver(this);
        _observingAppLifecycle = false;
      }
    });
  }

  /// Stop observing app lifecycle events
  void stopObservingAppLifecycle() {
    if (!_observingAppLifecycle) return;

    WidgetsBinding.instance.removeObserver(this);
    _observingAppLifecycle = false;
  }

  /// Called when the app is paused (background)
  @mustCallSuper
  void onPause() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType paused');
    }
  }

  /// Called when the app resumes (foreground)
  @mustCallSuper
  void onResume() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType resumed');
    }
  }

  /// Called when the app is inactive (e.g. incoming call)
  @mustCallSuper
  void onInactive() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType inactive');
    }
  }

  /// Called when the app is detached (e.g. killed)
  @mustCallSuper
  void onDetached() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType detached');
    }
  }

  /// Called when the app is hidden but still running
  /// (e.g. when showing the app switcher on iOS)
  @mustCallSuper
  void onHidden() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType hidden');
    }
  }

  /// Handles app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        onInactive();
        break;
      case AppLifecycleState.paused:
        onPause();
        break;
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.detached:
        onDetached();
        break;
      case AppLifecycleState.hidden:
        onHidden();
        break;
    }
  }

  /// Add a callback to be called when the controller is disposed
  void addDisposer(VoidCallback callback) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to add disposer to disposed controller $runtimeType');
      return;
    }
    _disposers.add(callback);
  }

  /// Add a listener to a ValueNotifier that will be auto-disposed
  /// when the controller is disposed
  void addValueListener<T>(
      ValueNotifier<T> notifier,
      void Function(T) listener) {

    void notifierListener() {
      listener(notifier.value);
    }

    notifier.addListener(notifierListener);
    addDisposer(() => notifier.removeListener(notifierListener));
  }

  // Helper to create a worker that will be auto-disposed
  VoidCallback createWorker(VoidCallback disposer) {
    addDisposer(disposer);
    return disposer;
  }

  // Maps update IDs to their listener callbacks
  final Map<String, Set<VoidCallback>> _updateListeners = {};

  /// Register a listener for a specific update ID
  /// Used by ZenBuilder for manual updates
  void addUpdateListener(String id, VoidCallback listener) {
    _updateListeners.putIfAbsent(id, () => {}).add(listener);
  }

  /// Remove a listener for a specific update ID
  void removeUpdateListener(String id, VoidCallback listener) {
    _updateListeners[id]?.remove(listener);
    if (_updateListeners[id]?.isEmpty ?? false) {
      _updateListeners.remove(id);
    }
  }

  /// Trigger an update for all listeners or specific IDs
  ///
  /// If [ids] is null or empty, all listeners will be notified.
  /// Otherwise, only listeners for the specified IDs will be notified.
  void update([List<String>? ids]) {
    if (ids == null || ids.isEmpty) {
      // Update all listeners if no IDs specified
      _updateListeners.values.expand((listeners) => listeners).forEach((listener) => listener());
    } else {
      // Update only the specified IDs
      for (final id in ids) {
        _updateListeners[id]?.forEach((listener) => listener());
      }
    }
  }

  /// Dispose the controller, cleaning up all resources
  void dispose() {
    if (_disposed) {
      ZenLogger.logWarning('Controller $runtimeType already disposed');
      return;
    }

    // Call onDispose first to allow cleaning up custom resources
    try {
      onDispose();
    } catch (e, stack) {
      ZenLogger.logError('Error in onDispose for controller $runtimeType', e, stack);
    }

    for (final disposer in _disposers) {
      try {
        disposer();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing controller $runtimeType', e, stack);
      }
    }

    _disposers.clear();
    _disposed = true;

    // Track metrics
    ZenMetrics.recordControllerDisposal(runtimeType);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType disposed');
    }
    _updateListeners.clear();
  }
}