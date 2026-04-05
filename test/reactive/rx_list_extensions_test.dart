import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  // ─────────────────────────────────────────
  // EXISTING (kept for regression)
  // ─────────────────────────────────────────
  group('RxList basic add/remove', () {
    test('should add and remove items', () {
      final list = <int>[].obs();
      list.add(1);
      expect(list.value, [1]);
      list.addAll([2, 3, 4]);
      expect(list.value, [1, 2, 3, 4]);
      final removed = list.remove(2);
      expect(removed, true);
      final removedItem = list.removeAt(0);
      expect(removedItem, 1);
      expect(list.value, [3, 4]);
    });

    test('should provide reactive list properties', () {
      final list = [1, 2, 3, 4, 5].obs();
      expect(list.length, 5);
      expect(list.isEmpty, false);
      expect(list.isNotEmpty, true);
      expect(list.first, 1);
      expect(list.last, 5);
      expect(list[2], 3);
    });

    test('should insert and replace items', () {
      final list = [1, 2, 3].obs();
      list.insert(1, 10);
      expect(list.value, [1, 10, 2, 3]);
      list.insertAll(2, [20, 30]);
      expect(list.value, [1, 10, 20, 30, 2, 3]);
      list.replaceRange(2, 4, [100]);
      expect(list.value, [1, 10, 100, 2, 3]);
    });

    test('should sort and shuffle', () {
      final list = [3, 1, 4, 1, 5].obs();
      list.sort();
      expect(list.value, [1, 1, 3, 4, 5]);
      list.shuffle();
      expect(list.length, 5);
    });

    test('should filter items', () {
      final list = [1, 2, 3, 4, 5].obs();
      list.removeWhere((item) => item.isEven);
      expect(list.value, [1, 3, 5]);
      list.retainWhere((item) => item > 2);
      expect(list.value, [3, 5]);
    });

    test('should handle bulk updates efficiently', () {
      final list = [1, 2, 3].obs();
      var notifications = 0;
      list.addListener(() => notifications++);
      list.bulkUpdate((items) {
        items.add(4);
        items.add(5);
        items.removeAt(0);
      });
      expect(list.value, [2, 3, 4, 5]);
      expect(notifications, 1);
    });
  });

  // ─────────────────────────────────────────
  // TRY* METHODS
  // ─────────────────────────────────────────
  group('RxList try* methods — success cases', () {
    test('tryAdd succeeds', () {
      final list = <int>[].obs();
      final result = list.tryAdd(42);
      expect(result.isSuccess, true);
      expect(list.value, [42]);
    });

    test('tryRemove returns true when found', () {
      final list = [1, 2, 3].obs();
      final result = list.tryRemove(2);
      expect(result.isSuccess, true);
      expect(result.value, true);
      expect(list.value, [1, 3]);
    });

    test('tryRemove returns false when not found', () {
      final list = [1, 2].obs();
      final result = list.tryRemove(99);
      expect(result.isSuccess, true);
      expect(result.value, false);
    });

    test('tryInsert inserts at valid index', () {
      final list = [1, 3].obs();
      final result = list.tryInsert(1, 2);
      expect(result.isSuccess, true);
      expect(list.value, [1, 2, 3]);
    });

    test('tryInsertAll inserts all at valid index', () {
      final list = [1, 4].obs();
      final result = list.tryInsertAll(1, [2, 3]);
      expect(result.isSuccess, true);
      expect(list.value, [1, 2, 3, 4]);
    });

    test('tryRemoveAt removes and returns element', () {
      final list = [10, 20, 30].obs();
      final result = list.tryRemoveAt(1);
      expect(result.isSuccess, true);
      expect(result.value, 20);
      expect(list.value, [10, 30]);
    });

    test('tryElementAt returns element at index', () {
      final list = ['a', 'b', 'c'].obs();
      final result = list.tryElementAt(1);
      expect(result.isSuccess, true);
      expect(result.value, 'b');
    });

    test('trySetAt updates element at index', () {
      final list = [1, 2, 3].obs();
      final result = list.trySetAt(1, 99);
      expect(result.isSuccess, true);
      expect(list.value, [1, 99, 3]);
    });

    test('tryClear empties the list', () {
      final list = [1, 2, 3].obs();
      expect(list.tryClear().isSuccess, true);
      expect(list.value, isEmpty);
    });

    test('tryAddAll appends all elements', () {
      final list = [1].obs();
      list.tryAddAll([2, 3, 4]);
      expect(list.value, [1, 2, 3, 4]);
    });

    test('trySort sorts with custom comparator', () {
      final list = [3, 1, 2].obs();
      list.trySort((a, b) => b.compareTo(a)); // descending
      expect(list.value, [3, 2, 1]);
    });

    test('tryShuffle shuffles without error', () {
      final list = [1, 2, 3, 4, 5].obs();
      expect(list.tryShuffle().isSuccess, true);
      expect(list.length, 5);
    });

    test('tryReplaceRange replaces a range', () {
      final list = [1, 2, 3, 4, 5].obs();
      list.tryReplaceRange(1, 3, [20, 30]);
      expect(list.value, [1, 20, 30, 4, 5]);
    });

    test('tryUpdateAt updates element', () {
      final list = [1, 2, 3].obs();
      list.tryUpdateAt(0, 99);
      expect(list.value[0], 99);
    });

    test('tryReplaceAll replaces all occurrences', () {
      final list = [1, 2, 1, 3, 1].obs();
      list.tryReplaceAll(1, 0);
      expect(list.value, [0, 2, 0, 3, 0]);
    });
  });

  group('RxList try* methods — error cases', () {
    test('tryInsert fails with negative index', () {
      final list = [1, 2].obs();
      expect(list.tryInsert(-1, 0).isFailure, true);
    });

    test('tryInsert fails with out-of-bounds index', () {
      final list = [1, 2].obs();
      expect(list.tryInsert(99, 0).isFailure, true);
    });

    test('tryRemoveAt fails with negative index', () {
      final list = [1, 2].obs();
      expect(list.tryRemoveAt(-1).isFailure, true);
    });

    test('tryRemoveAt fails with index >= length', () {
      final list = [1].obs();
      expect(list.tryRemoveAt(1).isFailure, true);
    });

    test('tryElementAt fails out of bounds', () {
      final list = [1].obs();
      expect(list.tryElementAt(5).isFailure, true);
    });

    test('trySetAt fails out of bounds', () {
      final list = [1, 2].obs();
      expect(list.trySetAt(99, 0).isFailure, true);
    });

    test('tryUpdateAt fails out of bounds', () {
      final list = [1].obs();
      expect(list.tryUpdateAt(5, 0).isFailure, true);
    });

    test('tryReplaceRange fails with invalid start', () {
      final list = [1, 2].obs();
      expect(list.tryReplaceRange(-1, 1, []).isFailure, true);
    });
  });

  // ─────────────────────────────────────────
  // OPERATOR AND SAFE ACCESS
  // ─────────────────────────────────────────
  group('RxList safe access', () {
    test('operator []= sets element', () {
      final list = [1, 2, 3].obs();
      list[1] = 99;
      expect(list.value[1], 99);
    });

    test('elementAtOrNull returns element within bounds', () {
      final list = ['a', 'b', 'c'].obs();
      expect(list.elementAtOrNull(1), 'b');
    });

    test('elementAtOrNull returns null out of bounds', () {
      final list = [1].obs();
      expect(list.elementAtOrNull(99), isNull);
    });

    test('elementAtOrNull returns null for negative index', () {
      final list = [1].obs();
      expect(list.elementAtOrNull(-1), isNull);
    });

    test('firstOrNull returns null for empty list', () {
      expect(<int>[].obs().firstOrNull, isNull);
    });

    test('lastOrNull returns null for empty list', () {
      expect(<int>[].obs().lastOrNull, isNull);
    });

    test('singleOrNull returns element for single-item list', () {
      expect([42].obs().singleOrNull, 42);
    });

    test('singleOrNull returns null for multi-element list', () {
      expect([1, 2].obs().singleOrNull, isNull);
    });

    test('single returns element for single-item list', () {
      expect([7].obs().single, 7);
    });

    test('tryFirst succeeds on non-empty list', () {
      final result = [1, 2, 3].obs().tryFirst;
      expect(result.isSuccess, true);
      expect(result.value, 1);
    });

    test('tryFirst fails on empty list', () {
      expect(<int>[].obs().tryFirst.isFailure, true);
    });

    test('tryLast succeeds on non-empty list', () {
      expect([1, 2, 3].obs().tryLast.isSuccess, true);
    });

    test('tryLast fails on empty list', () {
      expect(<int>[].obs().tryLast.isFailure, true);
    });

    test('trySingle succeeds on single-element list', () {
      final r = [5].obs().trySingle;
      expect(r.isSuccess, true);
      expect(r.value, 5);
    });

    test('trySingle fails on empty list', () {
      expect(<int>[].obs().trySingle.isFailure, true);
    });

    test('trySingle fails on multi-element list', () {
      expect([1, 2].obs().trySingle.isFailure, true);
    });
  });

  // ─────────────────────────────────────────
  // QUERY OPERATIONS
  // ─────────────────────────────────────────
  group('RxList query operations', () {
    test('contains returns correct result', () {
      final list = [1, 2, 3].obs();
      expect(list.contains(2), true);
      expect(list.contains(99), false);
    });

    test('indexOf finds first occurrence', () {
      final list = [1, 2, 3, 2].obs();
      expect(list.indexOf(2), 1);
    });

    test('lastIndexOf finds last occurrence', () {
      final list = [1, 2, 3, 2].obs();
      expect(list.lastIndexOf(2), 3);
    });

    test('any returns true when predicate matches', () {
      expect([1, 2, 3].obs().any((x) => x > 2), true);
    });

    test('every returns true when all match', () {
      expect([2, 4, 6].obs().every((x) => x.isEven), true);
    });

    test('firstWhere finds first matching element', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.firstWhere((x) => x > 2), 3);
    });

    test('firstWhere uses orElse when nothing matches', () {
      final list = [1, 2].obs();
      expect(list.firstWhere((x) => x > 10, orElse: () => -1), -1);
    });

    test('lastWhere finds last matching element', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.lastWhere((x) => x.isEven), 4);
    });

    test('singleWhere finds the one matching element', () {
      final list = [1, 2, 3].obs();
      expect(list.singleWhere((x) => x == 2), 2);
    });
  });

  // ─────────────────────────────────────────
  // FUNCTIONAL OPERATIONS
  // ─────────────────────────────────────────
  group('RxList functional operations', () {
    test('map transforms elements', () {
      final list = [1, 2, 3].obs();
      expect(list.map((x) => x * 2).toList(), [2, 4, 6]);
    });

    test('where filters elements', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.where((x) => x.isOdd).toList(), [1, 3]);
    });

    test('mapToRx creates reactive mapped list', () {
      final list = [1, 2, 3].obs();
      final doubled = list.mapToRx((x) => x * 2);
      expect(doubled.value, [2, 4, 6]);
    });

    test('whereToRx creates reactive filtered list', () {
      final list = [1, 2, 3, 4].obs();
      final odds = list.whereToRx((x) => x.isOdd);
      expect(odds.value, [1, 3]);
    });

    test('expand flattens elements', () {
      final list = [1, 2, 3].obs();
      expect(list.expand((x) => [x, x]).toList(), [1, 1, 2, 2, 3, 3]);
    });

    test('take returns first n elements', () {
      final list = [1, 2, 3, 4, 5].obs();
      expect(list.take(3).toList(), [1, 2, 3]);
    });

    test('skip skips first n elements', () {
      final list = [1, 2, 3, 4, 5].obs();
      expect(list.skip(2).toList(), [3, 4, 5]);
    });

    test('takeWhile takes while predicate is true', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.takeWhile((x) => x < 3).toList(), [1, 2]);
    });

    test('skipWhile skips while predicate is true', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.skipWhile((x) => x < 3).toList(), [3, 4]);
    });

    test('fold reduces to single value', () {
      final list = [1, 2, 3, 4].obs();
      expect(list.fold(0, (acc, x) => acc + x), 10);
    });

    test('reduce combines elements', () {
      final list = [1, 2, 3].obs();
      expect(list.reduce((acc, x) => acc + x), 6);
    });

    test('toList returns a list copy', () {
      final list = [1, 2, 3].obs();
      expect(list.toList(), [1, 2, 3]);
    });

    test('toSet converts to set', () {
      final list = [1, 2, 2, 3].obs();
      expect(list.toSet(), {1, 2, 3});
    });

    test('join concatenates elements', () {
      final list = ['a', 'b', 'c'].obs();
      expect(list.join(', '), 'a, b, c');
    });

    test('refresh notifies listeners', () {
      final list = [1].obs();
      var count = 0;
      list.addListener(() => count++);
      list.refresh();
      expect(count, 1);
    });
  });
}
