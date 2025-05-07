// lib/controllers/zen_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';
import 'zen_di.dart';

/// Base controller class similar to GetX controller
abstract class ZenController {
  final List<VoidCallback> _disposers = [];
  final DateTime _createdAt = DateTime.now();
  bool _disposed = false;
  bool _initialized = false;
  bool _ready = false;

  DateTime get createdAt => _createdAt;
  bool get isDisposed => _disposed;
  bool get isInitialized => _initialized;
  bool get isReady => _ready;

  /// Called when the controller is first created and registered
  /// This is a good place to initialize basic properties
  @mustCallSuper
  void onInit() {
    if (_initialized) return;
    _initialized = true;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType initialized');
    }
  }

  /// Called after init, when the controller is registered and ready for use
  /// Good place to fetch data or perform actions that depend on context/widgets
  @mustCallSuper
  void onReady() {
    if (_ready) return;
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

  void addDisposer(VoidCallback callback) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to add disposer to disposed controller $runtimeType');
      return;
    }
    _disposers.add(callback);
  }

  /// Adds a Riverpod listener to the disposers
  void addListener<T>(
      ProviderListenable<T> provider,
      void Function(T) listener, {
        ProviderContainer? container
      }) {
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, value) => listener(value),
    );
    addDisposer(() => subscription.close());
  }

  // Helper to create a worker that will be auto-disposed
  VoidCallback createWorker(VoidCallback disposer) {
    addDisposer(disposer);
    return disposer;
  }

  // Maps update IDs to their listener callbacks
  final Map<String, Set<VoidCallback>> _updateListeners = {};

  /// Register a listener for a specific update ID
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

  /// Trigger an update for a specific ID
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