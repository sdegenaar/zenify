// lib/reactive/extensions/rx_set_extensions.dart
import '../core/rx_value.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';
import '../utils/rx_logger.dart';

/// Enhanced reactive set operations with comprehensive error handling
extension RxSetExtensions<T> on Rx<Set<T>> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Add item with error handling
  RxResult<bool> tryAdd(T item) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final added = newSet.add(item);
      if (added) value = newSet;
      return added;
    }, 'add item to set');
  }

  /// Remove item with error handling
  RxResult<bool> tryRemove(Object? item) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final removed = newSet.remove(item);
      if (removed) value = newSet;
      return removed;
    }, 'remove item from set');
  }

  /// Clear set with error handling
  RxResult<void> tryClear() {
    return RxResult.tryExecute(() {
      if (value.isNotEmpty) {
        value = <T>{};
      }
    }, 'clear set');
  }

  /// Add all items with error handling
  RxResult<void> tryAddAll(Iterable<T> elements) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final sizeBefore = newSet.length;
      newSet.addAll(elements);
      if (sizeBefore != newSet.length) value = newSet;
    }, 'add all items to set');
  }

  /// Remove all items with error handling
  RxResult<void> tryRemoveAll(Iterable<Object?> elements) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final sizeBefore = newSet.length;
      newSet.removeAll(elements);
      if (sizeBefore != newSet.length) value = newSet;
    }, 'remove all items from set');
  }

  /// Remove where with error handling
  RxResult<void> tryRemoveWhere(bool Function(T) test) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final sizeBefore = newSet.length;
      newSet.removeWhere(test);
      if (sizeBefore != newSet.length) value = newSet;
    }, 'remove where from set');
  }

  /// Retain where with error handling
  RxResult<void> tryRetainWhere(bool Function(T) test) {
    return RxResult.tryExecute(() {
      final newSet = Set<T>.from(value);
      final sizeBefore = newSet.length;
      newSet.retainWhere(test);
      if (sizeBefore != newSet.length) value = newSet;
    }, 'retain where in set');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Add item (convenience method)
  bool add(T item) {
    final result = tryAdd(item);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
      return false;
    }
    return result.value;
  }

  /// Remove item (convenience method)
  bool remove(Object? item) {
    final result = tryRemove(item);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
      return false;
    }
    return result.value;
  }

  /// Clear set (convenience method)
  void clear() {
    final result = tryClear();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
    }
  }

  /// Add all items (convenience method)
  void addAll(Iterable<T> elements) {
    final result = tryAddAll(elements);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
    }
  }

  /// Remove all items (convenience method)
  void removeAll(Iterable<Object?> elements) {
    final result = tryRemoveAll(elements);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
    }
  }

  /// Remove where (convenience method)
  void removeWhere(bool Function(T) test) {
    final result = tryRemoveWhere(test);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
    }
  }

  /// Retain where (convenience method)
  void retainWhere(bool Function(T) test) {
    final result = tryRetainWhere(test);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Set');
    }
  }

  // ============================================================================
  // SAFE QUERY OPERATIONS
  // ============================================================================

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

  // Safe set operations
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

  // Safe functional operations
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

  // Safe element access with error handling
  RxResult<T> get tryFirst {
    return RxResult.tryExecute(() {
      if (value.isEmpty) {
        throw const RxException('Cannot get first element of empty set');
      }
      return value.first;
    }, 'get first element from set');
  }

  RxResult<T> get tryLast {
    return RxResult.tryExecute(() {
      if (value.isEmpty) {
        throw const RxException('Cannot get last element of empty set');
      }
      return value.last;
    }, 'get last element from set');
  }

  RxResult<T> get trySingle {
    return RxResult.tryExecute(() {
      if (value.isEmpty) {
        throw const RxException('Cannot get single element of empty set');
      }
      if (value.length > 1) {
        throw const RxException('Set has more than one element');
      }
      return value.single;
    }, 'get single element from set');
  }

  // Safe nullable access
  T? get firstOrNull => value.isEmpty ? null : value.first;
  T? get lastOrNull => value.isEmpty ? null : value.last;
  T? get singleOrNull => value.length == 1 ? value.single : null;

  // Safe conversions
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