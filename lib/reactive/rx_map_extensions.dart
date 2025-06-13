// lib/reactive/rx_map_extensions.dart
import 'rx_value.dart';
import 'rx_tracking.dart';

/// Enhanced reactive map operations that provide complete Map interface
extension ReactiveMapInterface<K, V> on Rx<Map<K, V>> {
  V? operator [](Object? key) {
    RxTracking.track(this);
    return value[key];
  }

  void operator []=(K key, V val) {
    final newMap = Map<K, V>.from(value);
    newMap[key] = val;
    value = newMap;
  }

  // Essential Map properties
  bool containsKey(Object? key) {
    RxTracking.track(this);
    return value.containsKey(key);
  }

  bool containsValue(Object? val) {
    RxTracking.track(this);
    return value.containsValue(val);
  }

  Iterable<K> get keys {
    RxTracking.track(this);
    return value.keys;
  }

  Iterable<V> get values {
    RxTracking.track(this);
    return value.values;
  }

  Iterable<MapEntry<K, V>> get entries {
    RxTracking.track(this);
    return value.entries;
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

  // Modification methods
  void addEntry(K key, V val) {
    final newMap = Map<K, V>.from(value);
    newMap[key] = val;
    value = newMap;
  }

  V? removeKey(Object? key) {
    final newMap = Map<K, V>.from(value);
    final removed = newMap.remove(key);
    if (removed != null) value = newMap;
    return removed;
  }

  void clear() {
    if (value.isNotEmpty) {
      value = <K, V>{};
    }
  }

  void addAll(Map<K, V> other) {
    if (other.isEmpty) return;
    final newMap = Map<K, V>.from(value);
    newMap.addAll(other);
    value = newMap;
  }

  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final newMap = Map<K, V>.from(value);
    newMap.addEntries(newEntries);
    value = newMap;
  }

  V putIfAbsent(K key, V Function() ifAbsent) {
    final newMap = Map<K, V>.from(value);
    final sizeBefore = newMap.length;
    final result = newMap.putIfAbsent(key, ifAbsent);
    if (sizeBefore != newMap.length) value = newMap;
    return result;
  }

  void removeWhere(bool Function(K key, V value) predicate) {
    final newMap = Map<K, V>.from(value);
    final sizeBefore = newMap.length;
    newMap.removeWhere(predicate);
    if (sizeBefore != newMap.length) value = newMap;
  }

  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final newMap = Map<K, V>.from(value);
    final result = newMap.update(key, update, ifAbsent: ifAbsent);
    value = newMap;
    return result;
  }

  void updateAll(V Function(K key, V value) update) {
    final newMap = Map<K, V>.from(value);
    newMap.updateAll(update);
    value = newMap;
  }

  // Functional methods
  void forEach(void Function(K key, V value) action) {
    RxTracking.track(this);
    value.forEach(action);
  }

  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) f) {
    RxTracking.track(this);
    return value.map(f);
  }

  Map<RK, RV> cast<RK, RV>() {
    RxTracking.track(this);
    return value.cast<RK, RV>();
  }

  /// Convenience method to refresh listeners
  void refresh() {
    value = value;
  }
}