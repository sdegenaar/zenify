// lib/zenify/rx_collections.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'rx_tracking.dart';

/// Base class for reactive collections
abstract class RxCollection<E, C> extends ValueNotifier<C> {
  RxCollection(super.initial);

  @override
  C get value {
    // Track value access for reactivity
    RxTracking.track(this);
    return super.value;
  }
}

/// A reactive list implementation
class RxList<E> extends RxCollection<E, List<E>> implements List<E> {
  RxList([List<E> initial = const []]) : super(List<E>.from(initial));

  // Forward operations to the internal list with notification

  @override
  E operator [](int index) {
    RxTracking.track(this); // Track for Obx
    return value[index];
  }

  @override
  void operator []=(int index, E value) {
    this.value[index] = value;
    notifyListeners();
  }

  @override
  void add(E element) {
    value.add(element);
    notifyListeners();
  }

  @override
  void addAll(Iterable<E> iterable) {
    value.addAll(iterable);
    notifyListeners();
  }

  @override
  void clear() {
    value.clear();
    notifyListeners();
  }

  @override
  bool remove(Object? element) {
    final result = value.remove(element);
    if (result) notifyListeners();
    return result;
  }

  @override
  void insert(int index, E element) {
    value.insert(index, element);
    notifyListeners();
  }

  @override
  E removeAt(int index) {
    final result = value.removeAt(index);
    notifyListeners();
    return result;
  }

  @override
  void removeWhere(bool Function(E) test) {
    final sizeBefore = value.length;
    value.removeWhere(test);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    value.sort(compare);
    notifyListeners();
  }

  // Implementing List interface
  @override
  int get length => value.length;

  @override
  set length(int newLength) {
    if (value.length != newLength) {
      value.length = newLength;
      notifyListeners();
    }
  }

  @override
  List<E> operator +(List<E> other) {
    return [...value, ...other];
  }

  @override
  bool any(bool Function(E) test) => value.any(test);

  // Fix the asMap method to match the List interface
  @override
  Map<int, E> asMap() {
    return value.asMap();
  }

  @override
  List<R> cast<R>() => value.cast<R>();

  @override
  bool contains(Object? element) => value.contains(element);

  @override
  E elementAt(int index) => value.elementAt(index);

  @override
  bool every(bool Function(E) test) => value.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E) f) => value.expand(f);

  @override
  E firstWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue, T Function(T, E) combine) =>
      value.fold(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  @override
  void forEach(void Function(E) f) => value.forEach(f);

  @override
  Iterable<E> getRange(int start, int end) => value.getRange(start, end);

  @override
  int indexOf(E element, [int start = 0]) => value.indexOf(element, start);

  @override
  int indexWhere(bool Function(E) test, [int start = 0]) =>
      value.indexWhere(test, start);

  @override
  int lastIndexOf(E element, [int? start]) =>
      value.lastIndexOf(element, start ?? (value.length - 1));

  @override
  int lastIndexWhere(bool Function(E) test, [int? start]) =>
      value.lastIndexWhere(test, start);

  @override
  E lastWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  @override
  Iterable<T> map<T>(T Function(E) f) => value.map(f);

  @override
  E reduce(E Function(E, E) combine) => value.reduce(combine);

  @override
  Iterable<E> skip(int count) => value.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E) test) => value.skipWhile(test);

  @override
  Iterable<E> take(int count) => value.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E) test) => value.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  Iterable<E> where(bool Function(E) test) => value.where(test);

  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  @override
  void fillRange(int start, int end, [E? fill]) {
    value.fillRange(start, end, fill);
    notifyListeners();
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    value.setAll(index, iterable);
    notifyListeners();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    value.setRange(start, end, iterable, skipCount);
    notifyListeners();
  }

  @override
  void shuffle([Random? random]) {
    value.shuffle(random);
    notifyListeners();
  }

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  List<E> sublist(int start, [int? end]) => value.sublist(start, end);

  @override
  E get first => value.first;

  @override
  E get last => value.last;

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  Iterable<E> get reversed => value.reversed;

  @override
  void replaceRange(int start, int end, Iterable<E> replacement) {
    value.replaceRange(start, end, replacement);
    notifyListeners();
  }

  // Missing methods that were flagged
  @override
  String join([String separator = ""]) {
    return value.join(separator);
  }

  @override
  E singleWhere(bool Function(E) test, {E Function()? orElse}) {
    return value.singleWhere(test, orElse: orElse);
  }

  @override
  void insertAll(int index, Iterable<E> elements) {
    value.insertAll(index, elements);
    notifyListeners();
  }

  @override
  E removeLast() {
    final result = value.removeLast();
    notifyListeners();
    return result;
  }

  @override
  E get single => value.single;

  @override
  void removeRange(int start, int end) {
    value.removeRange(start, end);
    notifyListeners();
  }

  @override
  void retainWhere(bool Function(E) test) {
    final sizeBefore = value.length;
    value.retainWhere(test);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  set first(E value) {
    if (this.value.isNotEmpty) {
      this.value[0] = value;
      notifyListeners();
    } else {
      throw IndexError.withLength(0, 0, indexable: this, name: "index", message: "Cannot set first element on empty list");
    }
  }

  @override
  set last(E value) {
    if (this.value.isNotEmpty) {
      this.value[this.value.length - 1] = value;
      notifyListeners();
    } else {
      throw IndexError.withLength(0, 0, indexable: this, name: "index", message: "Cannot set last element on empty list");
    }
  }
}

/// A reactive map implementation
class RxMap<K, V> extends RxCollection<MapEntry<K, V>, Map<K, V>> implements Map<K, V> {
  RxMap([Map<K, V> initial = const {}]) : super(Map<K, V>.from(initial));

  @override
  V? operator [](Object? key) {
    RxTracking.track(this); // Track for Obx
    return value[key];
  }

  @override
  void operator []=(K key, V value) {
    this.value[key] = value;
    notifyListeners();
  }

  @override
  void clear() {
    value.clear();
    notifyListeners();
  }

  @override
  V? remove(Object? key) {
    final result = value.remove(key);
    notifyListeners();
    return result;
  }

  @override
  void addAll(Map<K, V> other) {
    value.addAll(other);
    notifyListeners();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    value.addEntries(newEntries);
    notifyListeners();
  }

  @override
  Map<RK, RV> cast<RK, RV>() => value.cast<RK, RV>();

  @override
  bool containsKey(Object? key) => value.containsKey(key);

  @override
  bool containsValue(Object? val) => value.containsValue(val);

  @override
  void forEach(void Function(K key, V value) action) => value.forEach(action);

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) f) =>
      value.map(f);

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final bool exists = value.containsKey(key);
    final V result = value.putIfAbsent(key, ifAbsent);
    if (!exists) notifyListeners();
    return result;
  }

  @override
  void removeWhere(bool Function(K key, V value) predicate) {
    final sizeBefore = value.length;
    value.removeWhere(predicate);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = value.update(key, update, ifAbsent: ifAbsent);
    notifyListeners();
    return result;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    value.updateAll(update);
    notifyListeners();
  }

  // Implement required getters
  @override
  Iterable<MapEntry<K, V>> get entries => value.entries;

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  Iterable<K> get keys => value.keys;

  @override
  int get length => value.length;

  @override
  Iterable<V> get values => value.values;
}

/// A reactive set implementation
class RxSet<E> extends RxCollection<E, Set<E>> implements Set<E> {
  RxSet([Set<E> initial = const {}]) : super(Set<E>.from(initial));

  @override
  bool add(E value) {
    final result = this.value.add(value);
    if (result) notifyListeners();
    return result;
  }

  @override
  void addAll(Iterable<E> elements) {
    final sizeBefore = value.length;
    value.addAll(elements);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  void clear() {
    value.clear();
    notifyListeners();
  }

  @override
  bool remove(Object? value) {
    final result = this.value.remove(value);
    if (result) notifyListeners();
    return result;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    final sizeBefore = value.length;
    value.removeAll(elements);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    final sizeBefore = value.length;
    value.retainAll(elements);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  void removeWhere(bool Function(E) test) {
    final sizeBefore = value.length;
    value.removeWhere(test);
    if (sizeBefore != value.length) notifyListeners();
  }

  @override
  void retainWhere(bool Function(E) test) {
    final sizeBefore = value.length;
    value.retainWhere(test);
    if (sizeBefore != value.length) notifyListeners();
  }

  // Implement Set interface
  @override
  bool any(bool Function(E) test) => value.any(test);

  @override
  Set<R> cast<R>() => value.cast<R>();

  @override
  bool contains(Object? element) => value.contains(element);

  @override
  bool containsAll(Iterable<Object?> other) => value.containsAll(other);

  @override
  Set<E> difference(Set<Object?> other) => value.difference(other);

  @override
  E elementAt(int index) => value.elementAt(index);

  @override
  bool every(bool Function(E) test) => value.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E) f) => value.expand(f);

  @override
  E firstWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue, T Function(T, E) combine) =>
      value.fold(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  @override
  void forEach(void Function(E) f) => value.forEach(f);

  @override
  Set<E> intersection(Set<Object?> other) => value.intersection(other);

  @override
  E lastWhere(bool Function(E) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  @override
  Iterable<T> map<T>(T Function(E) f) => value.map(f);

  @override
  E reduce(E Function(E, E) combine) => value.reduce(combine);

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  int get length => value.length;

  @override
  E get first => value.first;

  @override
  E get last => value.last;

  @override
  E? lookup(Object? object) => value.lookup(object);

  @override
  Iterable<E> skip(int count) => value.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E) test) => value.skipWhile(test);

  @override
  Iterable<E> take(int count) => value.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E) test) => value.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  Set<E> union(Set<E> other) => value.union(other);

  @override
  Iterable<E> where(bool Function(E) test) => value.where(test);

  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  // Missing methods
  @override
  String join([String separator = ""]) {
    return value.join(separator);
  }

  @override
  E singleWhere(bool Function(E) test, {E Function()? orElse}) {
    return value.singleWhere(test, orElse: orElse);
  }

  @override
  E get single => value.single;
}

// Convenience constructors
RxList<T> rxList<T>([List<T> initial = const []]) => RxList<T>(initial);
RxMap<K, V> rxMap<K, V>([Map<K, V> initial = const {}]) => RxMap<K, V>(initial);
RxSet<T> rxSet<T>([Set<T> initial = const {}]) => RxSet<T>(initial);

// Extension methods for non-reactive lists, maps, and sets
// We need to choose either the getter or method approach, not both
// Using the method approach to match with the rest of the library

extension ListObsExtension<E> on List<E> {
  /// Creates a reactive list from a regular list
  /// Example: final todos = <Todo>[].obs();
  RxList<E> obs() => RxList<E>(this);
}

extension MapObsExtension<K, V> on Map<K, V> {
  /// Creates a reactive map from a regular map
  /// Example: final settings = <String, dynamic>{}.obs();
  RxMap<K, V> obs() => RxMap<K, V>(this);
}

extension SetObsExtension<E> on Set<E> {
  /// Creates a reactive set from a regular set
  /// Example: final uniqueIds = <int>{}.obs();
  RxSet<E> obs() => RxSet<E>(this);
}