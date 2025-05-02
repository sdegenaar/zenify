// lib/rx_common.dart

import 'rx_notifier.dart';
import 'rx_value.dart';

/// Common extension for .obs functionality to help transition from GetX to Riverpod
enum RxType {
  local,  // ValueNotifier-based (GetX-like)
  global  // Riverpod-based
}

// Base interface for reactive types
abstract class ReactiveValue<T> {
  T get value;
  set value(T newValue);
}

/// General extension method that returns dynamic
extension ObsExtension<T> on T {
  dynamic obs([RxType type = RxType.local]) {
    return type == RxType.local
        ? Rx<T>(this)
        : RxNotifier<T>(this);
  }

  // Type-safe helper methods
  Rx<T> obsLocal() => Rx<T>(this);
  RxNotifier<T> obsGlobal() => RxNotifier<T>(this);
}

// Type-specific extensions with clear return types
extension IntObsExtension on int {
  Rx<int> obsLocal() => Rx<int>(this);
  RxNotifier<int> obsGlobal() => RxNotifier<int>(this);
}

extension DoubleObsExtension on double {
  Rx<double> obsLocal() => Rx<double>(this);
  RxNotifier<double> obsGlobal() => RxNotifier<double>(this);
}

extension BoolObsExtension on bool {
  Rx<bool> obsLocal() => Rx<bool>(this);
  RxNotifier<bool> obsGlobal() => RxNotifier<bool>(this);
}

extension StringObsExtension on String {
  Rx<String> obsLocal() => Rx<String>(this);
  RxNotifier<String> obsGlobal() => RxNotifier<String>(this);
}