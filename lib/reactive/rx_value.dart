// lib/zenify/reactive/rx_value.dart
import 'package:flutter/foundation.dart';
import 'rx_tracking.dart';

/// LOCAL STATE IMPLEMENTATION
/// A reactive value holder similar to GetX's Rx<T> but for local state only
/// Uses Flutter's ValueNotifier under the hood
class Rx<T> extends ValueNotifier<T> {
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
      notifyListeners(); // Explicitly call notifyListeners to ensure updates
    }
  }

  // Call operator (kept for backward compatibility)
  T operator () {
    // Track this value for reactivity with Obx widget
    RxTracking.track(this);
    return value;
  }

  // This is void since it's just setting a value (GetX-like syntax)
  void operator <<(T newValue) => value = newValue;
}

/// EXTENSIONS FOR LOCAL STATE (MIGRATION LEVEL 1)
/// These provide GetX-like operator syntax for local state
extension RxIntExtension on Rx<int> {
  // Update the value and return void
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

// Non-nullable type aliases (these match what's exported in zenify.dart)
typedef RxBool = Rx<bool>;
typedef RxInt = Rx<int>;
typedef RxDouble = Rx<double>;
typedef RxString = Rx<String>;

// Type aliases that match GetX style (for nullable types)
typedef RxnBool = Rx<bool?>;
typedef RxnDouble = Rx<double?>;
typedef RxnInt = Rx<int?>;
typedef RxnString = Rx<String?>;

// Factory functions for common types (similar to GetX)
Rx<bool> rxBool([bool initial = false]) => Rx<bool>(initial);
Rx<int> rxInt([int initial = 0]) => Rx<int>(initial);
Rx<double> rxDouble([double initial = 0.0]) => Rx<double>(initial);
Rx<String> rxString([String initial = '']) => Rx<String>(initial);

/// USAGE GUIDE FOR MIGRATION
/// 
/// This file implements Migration Level 1: Local state with GetX-like syntax
/// 
/// Example usage:
/// ```
/// // In a controller or widget:
/// final count = 0.obs();  // or rxInt()
/// 
/// // Update using operator syntax:
/// count + 1;  // Increments by 1
/// count << 5; // Sets to 5
/// 
/// // Access in an Obx widget:
/// Obx(() => Text('${count()}')); 
/// ```
/// 
/// For global state management with Riverpod integration,
/// use RxType.global with the .obs() method:
/// ```
/// // In a controller:
/// final count = 0.obs(RxType.global);
/// late final countProvider = count.createProvider(debugName: 'count');
/// 
/// // Access in a widget:
/// RiverpodObx((ref) => Text('${ref.watch(controller.countProvider)}'));
/// ```