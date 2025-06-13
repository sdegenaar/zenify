// lib/reactive/rx_value.dart
import 'package:flutter/foundation.dart';
import 'reactive_base.dart';
import 'rx_tracking.dart';

/// A reactive value holder that uses Flutter's ValueNotifier under the hood
class Rx<T> extends ValueNotifier<T> implements ReactiveValue<T> {
  bool _disposed = false;

  Rx(super.initialValue);

  /// Whether this Rx instance has been disposed
  bool get isDisposed => _disposed;

  // Override the value getter to automatically track access
  @override
  T get value {
    // Automatically track when value is accessed within an Obx widget
    RxTracking.track(this);
    return super.value;
  }

  @override
  set value(T newValue) {
    // Let ValueNotifier handle the equality check and notification
    super.value = newValue;
  }

  // Call operator for ReactiveValue interface
  @override
  T call() {
    RxTracking.track(this);
    return value;
  }

  // Update method for ReactiveValue interface
  @override
  void update(T Function(T value) updater) {
    final newValue = updater(value);
    value = newValue;
  }

  /// Update the value only if it's different (explicit equality check)
  void updateIfChanged(T newValue) {
    if (value == newValue) return;
    value = newValue;
  }

  /// Refresh/notify listeners even if value hasn't changed
  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  @override
  String toString() => 'Rx<$T>($value, disposed: $_disposed)';
}

// ============================================================================
// CREATION EXTENSIONS
// ============================================================================

/// General extension method for creating reactive values
extension ObsExtension<T> on T {
  Rx<T> obs() => Rx<T>(this);
}

// Type-specific extensions for primitives
extension IntObsExtension on int {
  Rx<int> obs() => Rx<int>(this);
}

extension DoubleObsExtension on double {
  Rx<double> obs() => Rx<double>(this);
}

extension BoolObsExtension on bool {
  Rx<bool> obs() => Rx<bool>(this);
}

extension StringObsExtension on String {
  Rx<String> obs() => Rx<String>(this);
}

// Collection extensions that return the typedef types
extension ListObsExtension<T> on List<T> {
  RxList<T> obs() => Rx<List<T>>(this);
}

extension MapObsExtension<K, V> on Map<K, V> {
  RxMap<K, V> obs() => Rx<Map<K, V>>(this);
}

extension SetObsExtension<T> on Set<T> {
  RxSet<T> obs() => Rx<Set<T>>(this);
}

// ============================================================================
// TYPE ALIASES
// ============================================================================

typedef RxBool = Rx<bool>;
typedef RxInt = Rx<int>;
typedef RxDouble = Rx<double>;
typedef RxString = Rx<String>;
typedef RxList<T> = Rx<List<T>>;
typedef RxMap<K, V> = Rx<Map<K, V>>;
typedef RxSet<T> = Rx<Set<T>>;

// Nullable type aliases
typedef RxnBool = Rx<bool?>;
typedef RxnDouble = Rx<double?>;
typedef RxnInt = Rx<int?>;
typedef RxnString = Rx<String?>;

// ============================================================================
// FACTORY FUNCTIONS
// ============================================================================

/// Creates a reactive boolean value
Rx<bool> rxBool([bool initial = false]) => Rx<bool>(initial);

/// Creates a reactive integer value
Rx<int> rxInt([int initial = 0]) => Rx<int>(initial);

/// Creates a reactive double value
Rx<double> rxDouble([double initial = 0.0]) => Rx<double>(initial);

/// Creates a reactive string value
Rx<String> rxString([String initial = '']) => Rx<String>(initial);

/// Creates a reactive list
Rx<List<T>> rxList<T>([List<T>? initial]) => Rx<List<T>>(initial ?? <T>[]);

/// Creates a reactive map
Rx<Map<K, V>> rxMap<K, V>([Map<K, V>? initial]) =>
    Rx<Map<K, V>>(initial ?? <K, V>{});

/// Creates a reactive set
Rx<Set<T>> rxSet<T>([Set<T>? initial]) => Rx<Set<T>>(initial ?? <T>{});

// Nullable factory functions
Rx<bool?> rxnBool([bool? initial]) => Rx<bool?>(initial);
Rx<int?> rxnInt([int? initial]) => Rx<int?>(initial);
Rx<double?> rxnDouble([double? initial]) => Rx<double?>(initial);
Rx<String?> rxnString([String? initial]) => Rx<String?>(initial);