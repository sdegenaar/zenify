// lib/reactive/rx_transformations.dart
import '../core/rx_value.dart';
import '../computed/rx_computed.dart';

/// Transformation extensions for reactive values
extension RxTransformations<T> on Rx<T> {
  /// Transform this reactive value to another type
  RxComputed<R> transform<R>(R Function(T) mapper) {
    return computed(() => mapper(value));
  }

  /// Filter values based on a predicate
  RxComputed<T?> filter(bool Function(T) predicate) {
    return computed(() => predicate(value) ? value : null);
  }

  /// Create a reactive value that only updates when the mapped value changes
  RxComputed<R> distinctMap<R>(R Function(T) mapper) {
    R? lastMapped;
    return computed(() {
      final newMapped = mapper(value);
      if (lastMapped != newMapped) {
        lastMapped = newMapped;
      }
      return lastMapped as R;
    });
  }

  /// Combine with another reactive value
  RxComputed<R> combineLatest<U, R>(Rx<U> other, R Function(T, U) combiner) {
    return computed(() => combiner(value, other.value));
  }

  /// Switch to a new reactive value based on current value
  RxComputed<R> switchMap<R>(RxComputed<R> Function(T) mapper) {
    RxComputed<R>? currentMapped;
    return computed(() {
      final newMapped = mapper(value);
      if (currentMapped != newMapped) {
        currentMapped?.dispose();
        currentMapped = newMapped;
      }
      return currentMapped!.value;
    });
  }

  /// Take the first n values
  RxComputed<T?> take(int count) {
    int taken = 0;
    return computed(() {
      if (taken < count) {
        taken++;
        return value;
      }
      return null;
    });
  }

  /// Skip the first n values
  RxComputed<T?> skip(int count) {
    int skipped = 0;
    return computed(() {
      if (skipped < count) {
        skipped++;
        return null;
      }
      return value;
    });
  }

  /// Convert to nullable type
  RxComputed<T?> asNullable() {
    return computed(() => value as T?);
  }

  /// Handle null values with a default
  RxComputed<T> whereNotNull([T? defaultValue]) {
    return computed(() {
      final val = value;
      if (val == null) {
        if (defaultValue != null) return defaultValue;
        throw StateError('Value is null and no default provided');
      }
      return val;
    });
  }
}

/// Extensions for nullable reactive values
extension RxNullableTransformations<T> on Rx<T?> {
  /// Provide a default value for null
  RxComputed<T> withDefault(T defaultValue) {
    return computed(() => value ?? defaultValue);
  }

  /// Filter out null values
  RxComputed<T?> whereNotNull() {
    return computed(() => value);
  }

  /// Map only non-null values
  RxComputed<R?> mapNotNull<R>(R Function(T) mapper) {
    return computed(() {
      final val = value;
      return val != null ? mapper(val) : null;
    });
  }
}

/// Collection transformation extensions
extension RxListTransformations<T> on Rx<List<T>> {
  /// Get list length as reactive value
  RxComputed<int> get rxLength => computed(() => value.length);

  /// Check if list is empty
  RxComputed<bool> get rxIsEmpty => computed(() => value.isEmpty);

  /// Get first element (or null)
  RxComputed<T?> get rxFirst =>
      computed(() => value.isNotEmpty ? value.first : null);

  /// Get last element (or null)
  RxComputed<T?> get rxLast =>
      computed(() => value.isNotEmpty ? value.last : null);

  /// Filter list reactively
  RxComputed<List<T>> whereList(bool Function(T) predicate) {
    return computed(() => value.where(predicate).toList());
  }

  /// Map list reactively
  RxComputed<List<R>> mapList<R>(R Function(T) mapper) {
    return computed(() => value.map(mapper).toList());
  }

  /// Sort list reactively
  RxComputed<List<T>> sortedBy<R extends Comparable>(
      R Function(T) keySelector) {
    return computed(() {
      final list = List<T>.from(value);
      list.sort((a, b) => keySelector(a).compareTo(keySelector(b)));
      return list;
    });
  }
}
