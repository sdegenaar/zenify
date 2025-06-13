
// lib/effects/zen_effects.dart
import '../reactive/rx_value.dart';
import '../controllers/zen_controller.dart';
import '../workers/zen_workers.dart';

/// A reactive effect that manages async operations with loading, data, and error states
/// Uses the Zen reactive system for consistent API and optimal performance
class ZenEffect<T> {
  final String name;

  final Rx<T?> _data = Rx<T?>(null);
  final RxBool _isLoading = false.obs();
  final Rx<Object?> _error = Rx<Object?>(null);
  final RxBool _dataWasSet = false.obs();

  bool _disposed = false;

  ZenEffect({required this.name});

  /// The current data value - using Rx for consistent reactive behavior
  Rx<T?> get data => _data;

  /// Whether the effect is currently loading - using RxBool for consistent reactive behavior
  RxBool get isLoading => _isLoading;

  /// The current error, if any - using Rx for consistent reactive behavior
  Rx<Object?> get error => _error;

  /// Whether data has been set at least once - using RxBool for consistent reactive behavior
  RxBool get dataWasSet => _dataWasSet;

  /// Whether the effect has data (including null data that was explicitly set)
  bool get hasData => _dataWasSet.value;

  /// Whether this effect has been disposed
  bool get isDisposed => _disposed;

  /// Set the loading state
  void loading() {
    if (_disposed) return;
    _isLoading.value = true;
    _error.value = null;
  }

  /// Set successful data
  void success(T? data) {
    if (_disposed) return;
    _data.value = data;
    _dataWasSet.value = true;
    _isLoading.value = false;
    _error.value = null;
  }

  /// Set error state
  void setError(Object error) {
    if (_disposed) return;
    _error.value = error;
    _isLoading.value = false;
  }

  /// Run an async operation with automatic state management
  /// Returns null if the effect is disposed during execution
  Future<T?> run(Future<T> Function() operation) async {
    if (_disposed) return null;

    try {
      // Set loading state first
      loading();

      // Check if disposed after setting loading state
      if (_disposed) return null;

      // Execute the operation
      final result = await operation();

      // Check if disposed after operation completes
      if (_disposed) return null;

      // Set success state with the result
      success(result);

      return result;
    } catch (e) {
      // Check if disposed before setting error
      if (_disposed) return null;

      // Set error state
      setError(e);

      // Re-throw the error so callers can handle it if needed
      rethrow;
    }
  }

  /// Reset the effect to initial state
  void reset() {
    if (_disposed) return;
    _data.value = null;
    _dataWasSet.value = false;
    _isLoading.value = false;
    _error.value = null;
  }

  /// Clear only the error state
  void clearError() {
    if (_disposed) return;
    _error.value = null;
  }

  /// Clear only the data
  void clearData() {
    if (_disposed) return;
    _data.value = null;
    _dataWasSet.value = false;
  }

  /// Dispose the effect and clean up resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _data.dispose();
    _isLoading.dispose();
    _error.dispose();
    _dataWasSet.dispose();
  }

  @override
  String toString() => 'ZenEffect<$T>(name: $name, disposed: $_disposed)';
}

/// Extension for easy effect watching with your worker system
extension ZenEffectWatch<T> on ZenEffect<T> {
  /// Unified watch method for all effect aspects using ZenWorkers directly
  void Function() watch(
      ZenController controller, {
        void Function(T?)? onData,
        void Function(bool)? onLoading,
        void Function(Object?)? onError,
        String? name,
      }) {
    if (isDisposed) {
      return () {}; // Return no-op disposer for disposed effects
    }

    final disposers = <ZenWorkerHandle>[];

    if (onData != null) {
      final handle = ZenWorkers.ever<T?>(_data, onData);
      disposers.add(handle);
    }

    if (onLoading != null) {
      final handle = ZenWorkers.ever<bool>(_isLoading, onLoading);
      disposers.add(handle);
    }

    if (onError != null) {
      final handle = ZenWorkers.ever<Object?>(_error, onError);
      disposers.add(handle);
    }

    // Return combined disposer
    return () {
      for (final handle in disposers) {
        handle.dispose();
      }
    };
  }

  /// Convenience method for watching only data changes
  void Function() watchData(ZenController controller, void Function(T?) callback, {String? name}) =>
      watch(controller, onData: callback, name: name);

  /// Convenience method for watching only loading state
  void Function() watchLoading(ZenController controller, void Function(bool) callback, {String? name}) =>
      watch(controller, onLoading: callback, name: name);

  /// Convenience method for watching only error state
  void Function() watchError(ZenController controller, void Function(Object?) callback, {String? name}) =>
      watch(controller, onError: callback, name: name);
}

/// Helper function to create effects (similar to createEffect in other frameworks)
ZenEffect<T> createEffect<T>({required String name}) {
  return ZenEffect<T>(name: name);
}