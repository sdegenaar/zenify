// lib/reactive/extensions/rx_list_extensions.dart
import 'dart:math';

import '../core/rx_value.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';
import '../utils/rx_logger.dart';

/// Reactive list extensions with comprehensive error handling
extension RxListExtensions<T> on Rx<List<T>> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Add element with error handling
  RxResult<void> tryAdd(T element) {
    return RxResult.tryExecute(() {
      value = [...value, element];
    }, 'add element to list');
  }

  /// Remove element with error handling
  RxResult<bool> tryRemove(T element) {
    return RxResult.tryExecute(() {
      final newList = [...value];
      final removed = newList.remove(element);
      value = newList;
      return removed;
    }, 'remove element from list');
  }

  /// Insert at index with validation
  RxResult<void> tryInsert(int index, T element) {
    return RxResult.tryExecute(() {
      if (index < 0 || index > value.length) {
        throw RxException('Invalid index: $index for list of length ${value.length}');
      }
      final newList = [...value];
      newList.insert(index, element);
      value = newList;
    }, 'insert element at index $index');
  }

  /// Insert all at index with validation
  RxResult<void> tryInsertAll(int index, Iterable<T> iterable) {
    return RxResult.tryExecute(() {
      if (index < 0 || index > value.length) {
        throw RxException('Invalid index: $index for list of length ${value.length}');
      }
      final newList = [...value];
      newList.insertAll(index, iterable);
      value = newList;
    }, 'insert all elements at index $index');
  }

  /// Remove at index with validation
  RxResult<T> tryRemoveAt(int index) {
    return RxResult.tryExecute(() {
      if (index < 0 || index >= value.length) {
        throw RxException('Invalid index: $index for list of length ${value.length}');
      }
      final newList = [...value];
      final removed = newList.removeAt(index);
      value = newList;
      return removed;
    }, 'remove element at index $index');
  }

  /// Get element with error handling
  RxResult<T> tryElementAt(int index) {
    return RxResult.tryExecute(() {
      if (index < 0 || index >= value.length) {
        throw RxException('Index $index out of bounds for list of length ${value.length}');
      }
      return value[index];
    }, 'get element at index $index');
  }

  /// Set element at index with validation
  RxResult<void> trySetAt(int index, T element) {
    return RxResult.tryExecute(() {
      if (index < 0 || index >= value.length) {
        throw RxException('Invalid index: $index for list of length ${value.length}');
      }
      final newList = [...value];
      newList[index] = element;
      value = newList;
    }, 'set element at index $index');
  }

  /// Clear list with error handling
  RxResult<void> tryClear() {
    return RxResult.tryExecute(() {
      value = <T>[];
    }, 'clear list');
  }

  /// Add all elements with error handling
  RxResult<void> tryAddAll(Iterable<T> elements) {
    return RxResult.tryExecute(() {
      value = [...value, ...elements];
    }, 'add all elements to list');
  }

  /// Remove where with error handling
  RxResult<void> tryRemoveWhere(bool Function(T element) test) {
    return RxResult.tryExecute(() {
      final newList = [...value];
      newList.removeWhere(test);
      value = newList;
    }, 'remove elements where condition');
  }

  /// Retain where with error handling
  RxResult<void> tryRetainWhere(bool Function(T element) test) {
    return RxResult.tryExecute(() {
      final newList = [...value];
      newList.retainWhere(test);
      value = newList;
    }, 'retain elements where condition');
  }

  /// Sort list with error handling
  RxResult<void> trySort([int Function(T a, T b)? compare]) {
    return RxResult.tryExecute(() {
      final newList = [...value];
      newList.sort(compare);
      value = newList;
    }, 'sort list');
  }

  /// Shuffle list with error handling
  RxResult<void> tryShuffle([Random? random]) {
    return RxResult.tryExecute(() {
      final newList = [...value];
      newList.shuffle(random);
      value = newList;
    }, 'shuffle list');
  }

  /// Replace range with error handling
  RxResult<void> tryReplaceRange(int start, int end, Iterable<T> replacements) {
    return RxResult.tryExecute(() {
      if (start < 0 || start > value.length) {
        throw RxException('Invalid start index: $start for list of length ${value.length}');
      }
      if (end < start || end > value.length) {
        throw RxException('Invalid end index: $end for list of length ${value.length}');
      }
      final newList = [...value];
      newList.replaceRange(start, end, replacements);
      value = newList;
    }, 'replace range');
  }

  /// Update element at index with validation
  RxResult<void> tryUpdateAt(int index, T element) {
    return RxResult.tryExecute(() {
      if (index < 0 || index >= value.length) {
        throw RxException('Invalid index: $index for list of length ${value.length}');
      }
      final newList = [...value];
      newList[index] = element;
      value = newList;
    }, 'update element at index $index');
  }

  /// Replace all occurrences with error handling
  RxResult<void> tryReplaceAll(T oldElement, T newElement) {
    return RxResult.tryExecute(() {
      final newList = value.map((e) => e == oldElement ? newElement : e).toList();
      value = newList;
    }, 'replace all occurrences');
  }

  // ============================================================================
  // SAFE ACCESS OPERATORS
  // ============================================================================

  /// Safe list access operator with tracking
  T operator [](int index) {
    RxTracking.track(this);
    return value[index];
  }

  /// Safe list assignment operator
  void operator []=(int index, T element) {
    final result = trySetAt(index, element);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Safe element access (returns null instead of throwing)
  T? elementAtOrNull(int index) {
    RxTracking.track(this);
    try {
      return index >= 0 && index < value.length ? value[index] : null;
    } catch (e) {
      RxLogger.logError(
        RxException.withTimestamp(
          'Error accessing element at index $index',
          originalError: e,
        ),
        context: 'List',
      );
      return null;
    }
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Add element (convenience method that calls tryAdd internally)
  void add(T element) {
    final result = tryAdd(element);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Remove element (convenience method that calls tryRemove internally)
  bool remove(T element) {
    final result = tryRemove(element);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
      return false;
    }
    return result.value;
  }

  /// Insert at index (convenience method that calls tryInsert internally)
  void insert(int index, T element) {
    final result = tryInsert(index, element);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Insert all at index (convenience method)
  void insertAll(int index, Iterable<T> iterable) {
    final result = tryInsertAll(index, iterable);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Remove at index (convenience method that calls tryRemoveAt internally)
  T? removeAt(int index) {
    final result = tryRemoveAt(index);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
      return null;
    }
    return result.value;
  }

  /// Clear list (convenience method that calls tryClear internally)
  void clear() {
    final result = tryClear();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Add all elements (convenience method that calls tryAddAll internally)
  void addAll(Iterable<T> elements) {
    final result = tryAddAll(elements);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Remove where (convenience method that calls tryRemoveWhere internally)
  void removeWhere(bool Function(T element) test) {
    final result = tryRemoveWhere(test);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Retain where (convenience method)
  void retainWhere(bool Function(T element) test) {
    final result = tryRetainWhere(test);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Sort list (convenience method that calls trySort internally)
  void sort([int Function(T a, T b)? compare]) {
    final result = trySort(compare);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Shuffle list (convenience method)
  void shuffle([Random? random]) {
    final result = tryShuffle(random);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Replace range (convenience method)
  void replaceRange(int start, int end, Iterable<T> replacements) {
    final result = tryReplaceRange(start, end, replacements);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  // ============================================================================
  // SAFE GETTERS AND QUERY OPERATIONS
  // ============================================================================

  // Safe getters (with tracking)
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

  /// Get first element (throws if empty - matches List<T>.first behavior)
  T get first {
    RxTracking.track(this);
    return value.first;
  }

  /// Get last element (throws if empty - matches List<T>.last behavior)
  T get last {
    RxTracking.track(this);
    return value.last;
  }

  /// Get single element (throws if empty or more than one - matches List<T>.single behavior)
  T get single {
    RxTracking.track(this);
    return value.single;
  }

  T? get firstOrNull {
    RxTracking.track(this);
    return value.isEmpty ? null : value.first;
  }

  T? get lastOrNull {
    RxTracking.track(this);
    return value.isEmpty ? null : value.last;
  }

  T? get singleOrNull {
    RxTracking.track(this);
    return value.length == 1 ? value.single : null;
  }

  // Safe getters with error handling for potential exceptions
  RxResult<T> get tryFirst {
    return RxResult.tryExecute(() {
      RxTracking.track(this);
      if (value.isEmpty) {
        throw const RxException('Cannot get first element of empty list');
      }
      return value.first;
    }, 'get first element');
  }

  RxResult<T> get tryLast {
    return RxResult.tryExecute(() {
      RxTracking.track(this);
      if (value.isEmpty) {
        throw const RxException('Cannot get last element of empty list');
      }
      return value.last;
    }, 'get last element');
  }

  RxResult<T> get trySingle {
    return RxResult.tryExecute(() {
      RxTracking.track(this);
      if (value.isEmpty) {
        throw const RxException('Cannot get single element of empty list');
      }
      if (value.length > 1) {
        throw const RxException('List has more than one element');
      }
      return value.single;
    }, 'get single element');
  }

  // Query operations (safe with tracking)
  bool contains(T element) {
    RxTracking.track(this);
    return value.contains(element);
  }

  int indexOf(T element, [int start = 0]) {
    RxTracking.track(this);
    return value.indexOf(element, start);
  }

  int lastIndexOf(T element, [int? start]) {
    RxTracking.track(this);
    return value.lastIndexOf(element, start);
  }

  bool any(bool Function(T element) test) {
    RxTracking.track(this);
    return value.any(test);
  }

  bool every(bool Function(T element) test) {
    RxTracking.track(this);
    return value.every(test);
  }

  T firstWhere(bool Function(T element) test, {T Function()? orElse}) {
    RxTracking.track(this);
    return value.firstWhere(test, orElse: orElse);
  }

  T lastWhere(bool Function(T element) test, {T Function()? orElse}) {
    RxTracking.track(this);
    return value.lastWhere(test, orElse: orElse);
  }

  T singleWhere(bool Function(T element) test, {T Function()? orElse}) {
    RxTracking.track(this);
    return value.singleWhere(test, orElse: orElse);
  }

  // ============================================================================
  // FUNCTIONAL OPERATIONS
  // ============================================================================

  /// Map operation that returns a spreadable Iterable (for use with ... operator)
  Iterable<R> map<R>(R Function(T element) mapper) {
    RxTracking.track(this);
    return value.map(mapper);
  }

  /// Where operation that returns a spreadable Iterable (for use with ... operator)
  Iterable<T> where(bool Function(T element) test) {
    RxTracking.track(this);
    return value.where(test);
  }

  /// Map operation that returns a new reactive list
  Rx<List<R>> mapToRx<R>(R Function(T element) mapper) {
    RxTracking.track(this);
    return value.map(mapper).toList().obs();
  }

  /// Where operation that returns a new reactive list
  Rx<List<T>> whereToRx(bool Function(T element) test) {
    RxTracking.track(this);
    return value.where(test).toList().obs();
  }

  /// Expand operation
  Iterable<R> expand<R>(Iterable<R> Function(T element) f) {
    RxTracking.track(this);
    return value.expand(f);
  }

  /// Take operation
  Iterable<T> take(int count) {
    RxTracking.track(this);
    return value.take(count);
  }

  /// Skip operation
  Iterable<T> skip(int count) {
    RxTracking.track(this);
    return value.skip(count);
  }

  /// TakeWhile operation
  Iterable<T> takeWhile(bool Function(T element) test) {
    RxTracking.track(this);
    return value.takeWhile(test);
  }

  /// SkipWhile operation
  Iterable<T> skipWhile(bool Function(T element) test) {
    RxTracking.track(this);
    return value.skipWhile(test);
  }

  /// Fold operation
  R fold<R>(R initialValue, R Function(R previousValue, T element) combine) {
    RxTracking.track(this);
    return value.fold(initialValue, combine);
  }

  /// Reduce operation
  T reduce(T Function(T value, T element) combine) {
    RxTracking.track(this);
    return value.reduce(combine);
  }

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

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Perform bulk updates efficiently (only one notification)
  void bulkUpdate(void Function(List<T> items) updater) {
    final result = RxResult.tryExecute(() {
      final newList = [...value];
      updater(newList);
      value = newList;
    }, 'bulk update');

    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'List');
    }
  }

  /// Convenience method to refresh listeners
  void refresh() {
    value = value;
  }
}