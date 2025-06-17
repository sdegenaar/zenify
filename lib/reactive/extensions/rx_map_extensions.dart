
// lib/reactive/extensions/rx_map_extensions.dart
import '../core/rx_value.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';
import '../utils/rx_logger.dart';

/// Enhanced reactive map operations with comprehensive error handling
extension RxMapExtensions<K, V> on Rx<Map<K, V>> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Set key-value with error handling
  RxResult<void> trySetKey(K key, V val) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      newMap[key] = val;
      value = newMap;
    }, 'set map key');
  }

  /// Remove key with error handling
  RxResult<V?> tryRemoveKey(Object? key) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      final removed = newMap.remove(key);
      if (removed != null) value = newMap;
      return removed;
    }, 'remove map key');
  }

  /// Clear map with error handling
  RxResult<void> tryClear() {
    return RxResult.tryExecute(() {
      if (value.isNotEmpty) {
        value = <K, V>{};
      }
    }, 'clear map');
  }

  /// Add all entries with error handling
  RxResult<void> tryAddAll(Map<K, V> other) {
    return RxResult.tryExecute(() {
      if (other.isEmpty) return;
      final newMap = Map<K, V>.from(value);
      newMap.addAll(other);
      value = newMap;
    }, 'add all entries to map');
  }

  /// Add entries with error handling
  RxResult<void> tryAddEntries(Iterable<MapEntry<K, V>> newEntries) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      newMap.addEntries(newEntries);
      value = newMap;
    }, 'add entries to map');
  }

  /// Put if absent with error handling
  RxResult<V> tryPutIfAbsent(K key, V Function() ifAbsent) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      final sizeBefore = newMap.length;
      final result = newMap.putIfAbsent(key, ifAbsent);
      if (sizeBefore != newMap.length) value = newMap;
      return result;
    }, 'put if absent in map');
  }

  /// Remove where with error handling
  RxResult<void> tryRemoveWhere(bool Function(K key, V value) predicate) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      final sizeBefore = newMap.length;
      newMap.removeWhere(predicate);
      if (sizeBefore != newMap.length) value = newMap;
    }, 'remove where from map');
  }

  /// Update value with error handling
  RxResult<V> tryUpdate(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      final result = newMap.update(key, update, ifAbsent: ifAbsent);
      value = newMap;
      return result;
    }, 'update map value');
  }

  /// Update all values with error handling
  RxResult<void> tryUpdateAll(V Function(K key, V value) update) {
    return RxResult.tryExecute(() {
      final newMap = Map<K, V>.from(value);
      newMap.updateAll(update);
      value = newMap;
    }, 'update all map values');
  }

  /// Safe key access with error handling
  RxResult<V> tryGetKey(K key) {
    return RxResult.tryExecute(() {
      final val = value[key];
      if (val == null && !value.containsKey(key)) {
        throw RxException('Key not found: $key');
      }
      return val as V;
    }, 'get map key');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Set key-value (convenience method)
  void operator []=(K key, V val) {
    final result = trySetKey(key, val);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  /// Remove key (convenience method)
  V? remove(Object? key) {
    final result = tryRemoveKey(key);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
      return null;
    }
    return result.value;
  }

  /// Clear map (convenience method)
  void clear() {
    final result = tryClear();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  /// Add all entries (convenience method)
  void addAll(Map<K, V> other) {
    final result = tryAddAll(other);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  /// Add entries (convenience method)
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final result = tryAddEntries(newEntries);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  /// Put if absent (convenience method)
  V putIfAbsent(K key, V Function() ifAbsent) {
    final result = tryPutIfAbsent(key, ifAbsent);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
      return ifAbsent(); // Fallback to ifAbsent result
    }
    return result.value;
  }

  /// Remove where (convenience method)
  void removeWhere(bool Function(K key, V value) predicate) {
    final result = tryRemoveWhere(predicate);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  /// Update value (convenience method)
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = tryUpdate(key, update, ifAbsent: ifAbsent);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
      if (ifAbsent != null) return ifAbsent();
      throw result.errorOrNull!;
    }
    return result.value;
  }

  /// Update all values (convenience method)
  void updateAll(V Function(K key, V value) update) {
    final result = tryUpdateAll(update);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Map');
    }
  }

  // ============================================================================
  // SAFE ACCESS OPERATIONS
  // ============================================================================

  /// Safe access operations
  V? operator [](Object? key) {
    RxTracking.track(this);
    return value[key];
  }

  /// Safe key access with fallback
  V keyOr(K key, V fallback) {
    RxTracking.track(this);
    return value[key] ?? fallback;
  }

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

  // Safe functional operations
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