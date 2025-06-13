// lib/reactive/rx_type_extensions.dart
import 'rx_value.dart';
import 'rx_tracking.dart';

/// Integer-specific reactive operations
extension RxIntExtension on Rx<int> {
  void increment([int by = 1]) => value += by;
  void decrement([int by = 1]) => value -= by;
  void multiply(int factor) => value *= factor;
  void divide(int divisor) => value = (value / divisor).floor();

  bool get isEven {
    RxTracking.track(this);
    return value.isEven;
  }

  bool get isOdd {
    RxTracking.track(this);
    return value.isOdd;
  }

  bool get isNegative {
    RxTracking.track(this);
    return value.isNegative;
  }

  int get abs {
    RxTracking.track(this);
    return value.abs();
  }
}

/// Double-specific reactive operations
extension RxDoubleExtension on Rx<double> {
  void increment([double by = 1.0]) => value += by;
  void decrement([double by = 1.0]) => value -= by;
  void multiply(double factor) => value *= factor;
  void divide(double divisor) => value /= divisor;

  bool get isNegative {
    RxTracking.track(this);
    return value.isNegative;
  }

  bool get isInfinite {
    RxTracking.track(this);
    return value.isInfinite;
  }

  bool get isNaN {
    RxTracking.track(this);
    return value.isNaN;
  }

  bool get isFinite {
    RxTracking.track(this);
    return value.isFinite;
  }

  double get abs {
    RxTracking.track(this);
    return value.abs();
  }
}

/// Boolean-specific reactive operations
extension RxBoolExtension on Rx<bool> {
  void toggle() => value = !value;
  void setTrue() => value = true;
  void setFalse() => value = false;
}

/// String-specific reactive operations
extension RxStringExtension on Rx<String> {
  void append(String text) => value += text;
  void prepend(String text) => value = text + value;
  void clear() => value = '';
  void toLowerCase() => value = value.toLowerCase();
  void toUpperCase() => value = value.toUpperCase();
  void trim() => value = value.trim();
  void replaceAll(Pattern from, String replace) =>
      value = value.replaceAll(from, replace);
  void replaceFirst(Pattern from, String to, [int startIndex = 0]) =>
      value = value.replaceFirst(from, to, startIndex);

  // Reactive string properties
  int get length {
    RxTracking.track(this);
    return value.length;
  }

  bool get isEmpty {
    RxTracking.track(this);
    return value.isEmpty;
  }

  bool get isNotEmpty {
    RxTracking.track(this);
    return value.isNotEmpty;
  }

  List<String> split(Pattern pattern) {
    RxTracking.track(this);
    return value.split(pattern);
  }

  String substring(int start, [int? end]) {
    RxTracking.track(this);
    return value.substring(start, end);
  }

  bool contains(Pattern other, [int startIndex = 0]) {
    RxTracking.track(this);
    return value.contains(other, startIndex);
  }

  bool startsWith(Pattern pattern, [int index = 0]) {
    RxTracking.track(this);
    return value.startsWith(pattern, index);
  }

  bool endsWith(String other) {
    RxTracking.track(this);
    return value.endsWith(other);
  }

  int indexOf(Pattern pattern, [int start = 0]) {
    RxTracking.track(this);
    return value.indexOf(pattern, start);
  }

  int lastIndexOf(Pattern pattern, [int? start]) {
    RxTracking.track(this);
    return value.lastIndexOf(pattern, start);
  }
}