// lib/reactive/reactive_base.dart

/// Common base interface for reactive values
abstract class ReactiveValue<T> {
  /// Get the current value
  T get value;

  /// Set to a new value
  set value(T newValue);

  /// Call operator for consistent access patterns
  T call();

  /// Update value using a function
  void update(T Function(T value) updater);
}
