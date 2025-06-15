// lib/reactive/rx_list_extensions.dart
import 'dart:math' as math;

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

  // ============================================================================
  // EXISTING MODIFICATION METHODS
  // ============================================================================

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

  // ============================================================================
  // NEW MISSING METHODS - ADD THESE!
  // ============================================================================

  /// Remove elements from [start] (inclusive) to [end] (exclusive)
  void removeRange(int start, int end) {
    if (start < 0 || end > value.length || start > end) {
      throw RangeError('Invalid range: start=$start, end=$end, length=${value.length}');
    }
    final newList = List<T>.from(value);
    newList.removeRange(start, end);
    value = newList;
  }

  /// Remove and return the element at [index]
  T removeAt(int index) {
    if (index < 0 || index >= value.length) {
      throw RangeError.index(index, value);
    }
    final newList = List<T>.from(value);
    final removed = newList.removeAt(index);
    value = newList;
    return removed;
  }

  /// Remove and return the last element
  T removeLast() {
    if (value.isEmpty) {
      throw StateError('No element');
    }
    final newList = List<T>.from(value);
    final removed = newList.removeLast();
    value = newList;
    return removed;
  }

  /// Insert [element] at [index]
  void insert(int index, T element) {
    if (index < 0 || index > value.length) {
      throw RangeError.index(index, value);
    }
    final newList = List<T>.from(value);
    newList.insert(index, element);
    value = newList;
  }

  /// Insert all [elements] starting at [index]
  void insertAll(int index, Iterable<T> elements) {
    if (index < 0 || index > value.length) {
      throw RangeError.index(index, value);
    }
    if (elements.isEmpty) return;
    final newList = List<T>.from(value);
    newList.insertAll(index, elements);
    value = newList;
  }

  /// Replace elements from [start] to [end] with [replacements]
  void replaceRange(int start, int end, Iterable<T> replacements) {
    if (start < 0 || end > value.length || start > end) {
      throw RangeError('Invalid range: start=$start, end=$end, length=${value.length}');
    }
    final newList = List<T>.from(value);
    newList.replaceRange(start, end, replacements);
    value = newList;
  }

  /// Set all elements starting at [index] to [elements]
  void setAll(int index, Iterable<T> elements) {
    if (index < 0 || index > value.length) {
      throw RangeError.index(index, value);
    }
    final newList = List<T>.from(value);
    newList.setAll(index, elements);
    value = newList;
  }

  /// Set elements from [start] to [end] to values from [iterable]
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    if (start < 0 || end > value.length || start > end) {
      throw RangeError('Invalid range: start=$start, end=$end, length=${value.length}');
    }
    final newList = List<T>.from(value);
    newList.setRange(start, end, iterable, skipCount);
    value = newList;
  }

  /// Fill elements from [start] to [end] with [fillValue]
  void fillRange(int start, int end, [T? fillValue]) {
    if (start < 0 || end > value.length || start > end) {
      throw RangeError('Invalid range: start=$start, end=$end, length=${value.length}');
    }
    final newList = List<T>.from(value);
    newList.fillRange(start, end, fillValue);
    value = newList;
  }

  /// Remove elements that satisfy [test]
  void removeWhere(bool Function(T element) test) {
    final newList = List<T>.from(value);
    newList.removeWhere(test);
    value = newList;
  }

  /// Keep only elements that satisfy [test]
  void retainWhere(bool Function(T element) test) {
    final newList = List<T>.from(value);
    newList.retainWhere(test);
    value = newList;
  }

  /// Sort the list using [compare] function
  void sort([int Function(T a, T b)? compare]) {
    final newList = List<T>.from(value);
    newList.sort(compare);
    value = newList;
  }

  /// Shuffle the list randomly
  void shuffle([math.Random? random]) {
    final newList = List<T>.from(value);
    newList.shuffle(random);
    value = newList;
  }

  // ============================================================================
  // QUERY METHODS (existing ones)
  // ============================================================================

  /// Get a sublist from [start] to [end]
  List<T> sublist(int start, [int? end]) {
    RxTracking.track(this);
    return value.sublist(start, end);
  }

  /// Get elements from [start] to [end] as an iterable
  Iterable<T> getRange(int start, int end) {
    RxTracking.track(this);
    return value.getRange(start, end);
  }

  /// Find index of [element] starting from [start]
  int indexOf(T element, [int start = 0]) {
    RxTracking.track(this);
    return value.indexOf(element, start);
  }

  /// Find last index of [element] starting from [start]
  int lastIndexOf(T element, [int? start]) {
    RxTracking.track(this);
    return value.lastIndexOf(element, start);
  }

  /// Check if list contains [element]
  bool contains(Object? element) {
    RxTracking.track(this);
    return value.contains(element);
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