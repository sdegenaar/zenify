// lib/reactive/rx_set_extensions.dart
import 'rx_value.dart';
import 'rx_tracking.dart';

/// Enhanced reactive set operations that provide complete Set interface
extension ReactiveSetInterface<T> on Rx<Set<T>> {
  bool add(T item) {
    final newSet = Set<T>.from(value);
    final added = newSet.add(item);
    if (added) value = newSet;
    return added;
  }

  bool remove(Object? item) {
    final newSet = Set<T>.from(value);
    final removed = newSet.remove(item);
    if (removed) value = newSet;
    return removed;
  }

  void clear() {
    if (value.isNotEmpty) {
      value = <T>{};
    }
  }

  bool contains(Object? element) {
    RxTracking.track(this);
    return value.contains(element);
  }

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

  void addAll(Iterable<T> elements) {
    final newSet = Set<T>.from(value);
    final sizeBefore = newSet.length;
    newSet.addAll(elements);
    if (sizeBefore != newSet.length) value = newSet;
  }

  void removeAll(Iterable<Object?> elements) {
    final newSet = Set<T>.from(value);
    final sizeBefore = newSet.length;
    newSet.removeAll(elements);
    if (sizeBefore != newSet.length) value = newSet;
  }

  void removeWhere(bool Function(T) test) {
    final newSet = Set<T>.from(value);
    final sizeBefore = newSet.length;
    newSet.removeWhere(test);
    if (sizeBefore != newSet.length) value = newSet;
  }

  void retainWhere(bool Function(T) test) {
    final newSet = Set<T>.from(value);
    final sizeBefore = newSet.length;
    newSet.retainWhere(test);
    if (sizeBefore != newSet.length) value = newSet;
  }

  // Set operations
  Set<T> intersection(Set<Object?> other) {
    RxTracking.track(this);
    return value.intersection(other);
  }

  Set<T> union(Set<T> other) {
    RxTracking.track(this);
    return value.union(other);
  }

  Set<T> difference(Set<Object?> other) {
    RxTracking.track(this);
    return value.difference(other);
  }

  // Functional methods
  void forEach(void Function(T) action) {
    RxTracking.track(this);
    value.forEach(action);
  }

  Iterable<R> map<R>(R Function(T) f) {
    RxTracking.track(this);
    return value.map(f);
  }

  Iterable<T> where(bool Function(T) test) {
    RxTracking.track(this);
    return value.where(test);
  }

  bool any(bool Function(T) test) {
    RxTracking.track(this);
    return value.any(test);
  }

  bool every(bool Function(T) test) {
    RxTracking.track(this);
    return value.every(test);
  }

  T get first {
    RxTracking.track(this);
    return value.first;
  }

  T get last {
    RxTracking.track(this);
    return value.last;
  }

  T get single {
    RxTracking.track(this);
    return value.single;
  }

  List<T> toList({bool growable = true}) {
    RxTracking.track(this);
    return value.toList(growable: growable);
  }

  Set<T> toSet() {
    RxTracking.track(this);
    return value.toSet();
  }

  String join([String separator = ""]) {
    RxTracking.track(this);
    return value.join(separator);
  }

  /// Convenience method to refresh listeners
  void refresh() {
    value = value;
  }
}