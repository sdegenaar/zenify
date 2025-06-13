// lib/reactive/rx_list_extensions.dart
import 'rx_value.dart';
import 'rx_tracking.dart';

/// Enhanced reactive list operations that provide complete List interface
extension ReactiveListInterface<T> on Rx<List<T>> {

  /// Convenient forEach that tracks reactivity
  void forEach(void Function(T element) action) {
    RxTracking.track(this);
    value.forEach(action);
  }

  /// Convenient for-loop alternative that's reactive
  void forEachIndexed(void Function(int index, T element) action) {
    RxTracking.track(this);
    for (int i = 0; i < value.length; i++) {
      action(i, value[i]);
    }
  }

  /// Convenient fold operation
  R fold<R>(R initialValue, R Function(R previous, T element) combine) {
    RxTracking.track(this);
    return value.fold(initialValue, combine);
  }

  /// Convenient reduce operation
  T reduce(T Function(T previous, T element) combine) {
    RxTracking.track(this);
    return value.reduce(combine);
  }

  /// Convenient map operation
  Iterable<R> map<R>(R Function(T element) transform) {
    RxTracking.track(this);
    return value.map(transform);
  }

  /// Convenient where operation
  Iterable<T> where(bool Function(T element) test) {
    RxTracking.track(this);
    return value.where(test);
  }

  // Direct indexing access with reactive tracking
  T operator [](int index) {
    RxTracking.track(this);
    return value[index];
  }

  void operator []=(int index, T item) {
    if (index < 0 || index >= value.length) {
      throw RangeError.index(index, value);
    }
    final newList = List<T>.from(value);
    newList[index] = item;
    value = newList;
  }

  // Essential List properties with reactive tracking
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

  T get first {
    RxTracking.track(this);
    return value.first;
  }

  T get last {
    RxTracking.track(this);
    return value.last;
  }

  // Core modification methods
  void add(T item) {
    value = [...value, item];
  }

  void addAll(Iterable<T> items) {
    if (items.isEmpty) return;
    value = [...value, ...items];
  }

  bool remove(Object? item) {
    final newList = List<T>.from(value);
    final removed = newList.remove(item);
    if (removed) value = newList;
    return removed;
  }

  void clear() {
    if (value.isNotEmpty) {
      value = <T>[];
    }
  }

  // Performance optimization methods
  void bulkUpdate(void Function(List<T>) updater) {
    final newList = List<T>.from(value);
    updater(newList);
    value = newList;
  }

  /// Convenience method to refresh listeners
  void refresh() {
    value = value;
  }
}