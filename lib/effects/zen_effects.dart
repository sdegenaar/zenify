// lib/zenify/effects/zen_effects.dart
import 'package:flutter/foundation.dart';
import 'package:zenify/controllers/zen_controller.dart';
import 'package:zenify/core/zen_logger.dart';
import 'package:zenify/core/zen_metrics.dart';
import 'package:zenify/reactive/reactive.dart';

/// Handles asynchronous side effects with built-in loading, error, and success states
class ZenEffect<T> extends ChangeNotifier {
  final RxBool isLoading;
  final Rx<Object?> error;
  final Rx<T?> data;

  // Performance metrics
  final String name;
  final bool enableMetrics;

  // Track if success() was called, even with null data
  bool _dataWasSet = false;

  ZenEffect({
    String? name,
    T? initialData,
    this.enableMetrics = true,
  }) :
        name = name ?? 'unnamed_effect',
        isLoading = false.obs(),
        error = Rx<Object?>(null),
        data = initialData.obs() {
    // Listen to state changes to notify listeners
    isLoading.addListener(() => notifyListeners());
    error.addListener(() => notifyListeners());
    data.addListener(() => notifyListeners());

    if (initialData != null) {
      _dataWasSet = true;
    }
  }

  /// Whether the effect has error data
  bool get hasError => error.value != null;

  /// Whether the effect has result data
  /// We consider null as valid data after success() is called
  bool get hasData => data.value != null || _dataWasSet;

  /// Set the effect to loading state
  void loading() {
    if (enableMetrics) ZenMetrics.startTiming('effect.$name');
    isLoading.value = true;
    error.value = null;
    // Don't reset _dataWasSet here
  }

  /// Set the effect to success state with data
  void success(T result) {
    _dataWasSet = true; // Set this first to ensure hasData is true even for null
    data.value = result;
    isLoading.value = false;
    error.value = null;

    if (enableMetrics) {
      ZenMetrics.recordEffectSuccess(name);
      ZenMetrics.stopTiming('effect.$name');
    }

    // Explicitly notify listeners in addition to the Rx notifications
    notifyListeners();
  }

  /// Set the effect to error state
  void setError(Object? errorValue) {
    error.value = errorValue;
    isLoading.value = false;

    if (enableMetrics) {
      ZenMetrics.recordEffectFailure(name);
      ZenMetrics.stopTiming('effect.$name');
    }

    ZenLogger.logError('Effect "$name" failed', errorValue);

    // Explicitly notify listeners
    notifyListeners();
  }

  /// Run an async action with automatic state management
  Future<T?> run(Future<T> Function() action) async {
    loading();

    try {
      final result = await action();
      success(result);
      return result;
    } catch (e, stackTrace) {
      setError(e);
      ZenLogger.logError('Effect "$name" failed', e, stackTrace);
      return null;
    }
  }

  /// Reset the effect to initial state
  void reset() {
    isLoading.value = false;
    error.value = null;
    data.value = null;
    _dataWasSet = false;
    notifyListeners();
  }

  @override
  void dispose() {
    isLoading.removeListener(() => notifyListeners());
    error.removeListener(() => notifyListeners());
    data.removeListener(() => notifyListeners());
    super.dispose();
  }
}

// Extension methods for ZenController for easy effect creation
extension ZenEffectExtension on ZenController {
  ZenEffect<T> createEffect<T>({
    String? name,
    T? initialData,
    bool enableMetrics = true,
  }) {
    final effect = ZenEffect<T>(
      name: name,
      initialData: initialData,
      enableMetrics: enableMetrics,
    );

    // Auto-dispose the effect when controller is disposed
    addDisposer(() {
      effect.dispose();
    });

    return effect;
  }
}