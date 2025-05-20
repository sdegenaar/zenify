// lib/reactive/rx_value.dart
import 'package:flutter/foundation.dart';
import 'reactive_base.dart';
import 'rx_tracking.dart';

/// A reactive value holder that uses Flutter's ValueNotifier under the hood
class Rx<T> extends ValueNotifier<T> implements ReactiveValue<T> {
  Rx(super.initialValue);

  // Override the value getter to automatically track access
  @override
  T get value {
    // Automatically track when value is accessed within an Obx widget
    RxTracking.track(this);
    return super.value;
  }

  @override
  set value(T newValue) {
    if (super.value != newValue) {
      super.value = newValue;
      notifyListeners();
    }
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

  // Additional operator for GetX-like syntax
  void operator <<(T newValue) => value = newValue;
}

/// General extension method for creating reactive values
extension ObsExtension<T> on T {
  Rx<T> obs() => Rx<T>(this);
}

// Type-specific extensions
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

/// Type-specific operation extensions
extension RxIntExtension on Rx<int> {
  void operator +(int value) => this.value += value;
  void operator -(int value) => this.value -= value;
  void operator *(int value) => this.value *= value;
  void operator /(int value) => this.value = (this.value / value).floor();
}

extension RxDoubleExtension on Rx<double> {
  void operator +(double value) => this.value += value;
  void operator -(double value) => this.value -= value;
  void operator *(double value) => this.value *= value;
  void operator /(double value) => this.value /= value;
}

extension RxBoolExtension on Rx<bool> {
  void toggle() => value = !value;
}

extension RxStringExtension on Rx<String> {
  void operator +(String value) => this.value += value;
  void clear() => value = '';
}

// Type aliases for convenience
typedef RxBool = Rx<bool>;
typedef RxInt = Rx<int>;
typedef RxDouble = Rx<double>;
typedef RxString = Rx<String>;

// Nullable type aliases
typedef RxnBool = Rx<bool?>;
typedef RxnDouble = Rx<double?>;
typedef RxnInt = Rx<int?>;
typedef RxnString = Rx<String?>;

// Factory functions
Rx<bool> rxBool([bool initial = false]) => Rx<bool>(initial);
Rx<int> rxInt([int initial = 0]) => Rx<int>(initial);
Rx<double> rxDouble([double initial = 0.0]) => Rx<double>(initial);
Rx<String> rxString([String initial = '']) => Rx<String>(initial);