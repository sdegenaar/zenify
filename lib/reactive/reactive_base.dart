// lib/reactive/reactive_base.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Type of reactive implementation
enum ReactiveImplementation {
  /// Local state (ValueNotifier-based)
  local,

  /// Global state (Riverpod StateNotifier-based)
  global
}

/// Common base interface for reactive values
///
/// This interface provides a consistent API across different
/// reactive implementations
abstract class ReactiveBase<T> {
  /// Get the current value
  T get value;

  /// Set to a new value
  void set value(T newValue);

  /// Call operator for consistent access patterns
  T call();

  /// Update value using a function
  void update(T Function(T value) updater);

  /// Get the implementation type (local or global)
  ReactiveImplementation get implementationType;
}