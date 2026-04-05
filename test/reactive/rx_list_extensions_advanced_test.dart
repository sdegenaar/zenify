import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered failure branches in rx_list_extensions.dart:
/// - L49-50: tryInsertAll invalid index
/// - L154-155: tryReplaceRange invalid end index
/// - L199,209-211: []= failure path and elementAtOrNull error catch
/// - L228,236,246,254,262,269-272,280,288,296,304,312,320: convenience failure logs
/// - L551,556-557: bulkUpdate failure + refresh()
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // tryInsertAll — L49-50 invalid index
  // ══════════════════════════════════════════════════════════
  group('RxList.tryInsertAll', () {
    test('succeeds with valid index', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryInsertAll(1, [10, 20]);
      expect(result.isSuccess, true);
      expect(rx.value, [1, 10, 20, 2, 3]);
    });

    test('fails with negative index', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryInsertAll(-1, [10]);
      expect(result.isFailure, true);
    });

    test('fails with out-of-bounds index', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryInsertAll(10, [10]);
      expect(result.isFailure, true);
    });

    test('insertAll convenience logs failure on bad index', () {
      final rx = RxList<int>([1, 2, 3]);
      expect(() => rx.insertAll(-1, [9]), returnsNormally);
      expect(rx.value, [1, 2, 3]); // unchanged on failure
    });
  });

  // ══════════════════════════════════════════════════════════
  // tryReplaceRange — L154-155 invalid end
  // ══════════════════════════════════════════════════════════
  group('RxList.tryReplaceRange', () {
    test('succeeds with valid range', () {
      final rx = RxList<int>([1, 2, 3, 4]);
      final result = rx.tryReplaceRange(1, 3, [10, 20]);
      expect(result.isSuccess, true);
      expect(rx.value, [1, 10, 20, 4]);
    });

    test('fails with negative start', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryReplaceRange(-1, 2, []);
      expect(result.isFailure, true);
    });

    test('fails when end < start', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryReplaceRange(2, 1, []);
      expect(result.isFailure, true);
    });

    test('fails when end > length', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.tryReplaceRange(0, 10, []);
      expect(result.isFailure, true);
    });

    test('replaceRange convenience logs failure on invalid range', () {
      final rx = RxList<int>([1, 2, 3]);
      expect(() => rx.replaceRange(-1, 2, [9]), returnsNormally);
      expect(rx.value, [1, 2, 3]); // unchanged
    });
  });

  // ══════════════════════════════════════════════════════════
  // []= operator — failure path (bad index triggers logError)
  // ══════════════════════════════════════════════════════════
  group('RxList.[]= operator', () {
    test('valid assignment updates value', () {
      final rx = RxList<int>([1, 2, 3]);
      rx[1] = 99;
      expect(rx.value, [1, 99, 3]);
    });

    test('out-of-bounds assignment logs error safely', () {
      final rx = RxList<int>([1, 2, 3]);
      expect(() => rx[10] = 99, returnsNormally); // should not throw
      expect(rx.value, [1, 2, 3]); // unchanged
    });
  });

  // ══════════════════════════════════════════════════════════
  // elementAtOrNull — error recovery path (L209-211)
  // ══════════════════════════════════════════════════════════
  group('RxList.elementAtOrNull', () {
    test('returns element for valid index', () {
      final rx = RxList<int>([10, 20, 30]);
      expect(rx.elementAtOrNull(1), 20);
    });

    test('returns null for negative index', () {
      final rx = RxList<int>([10, 20, 30]);
      expect(rx.elementAtOrNull(-1), isNull);
    });

    test('returns null for out-of-bounds index', () {
      final rx = RxList<int>([10, 20, 30]);
      expect(rx.elementAtOrNull(99), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Convenience method failure branches
  // ══════════════════════════════════════════════════════════
  group('RxList convenience failure paths', () {
    test('add succeeds normally', () {
      final rx = RxList<int>([1]);
      rx.add(2);
      expect(rx.value, [1, 2]);
    });

    test('remove returns false for missing element', () {
      final rx = RxList<int>([1, 2]);
      final result = rx.remove(99);
      expect(result, false);
    });

    test('removeAt out of bounds returns null', () {
      final rx = RxList<int>([1, 2, 3]);
      final result = rx.removeAt(99);
      expect(result, isNull);
      expect(rx.value, [1, 2, 3]);
    });

    test('insert out of bounds logs error safely', () {
      final rx = RxList<int>([1, 2]);
      expect(() => rx.insert(-1, 9), returnsNormally);
      expect(rx.value, [1, 2]);
    });

    test('clear succeeds', () {
      final rx = RxList<int>([1, 2, 3]);
      rx.clear();
      expect(rx.value, isEmpty);
    });

    test('addAll adds all elements', () {
      final rx = RxList<int>([1]);
      rx.addAll([2, 3]);
      expect(rx.value, [1, 2, 3]);
    });

    test('removeWhere removes matching elements', () {
      final rx = RxList<int>([1, 2, 3, 4]);
      rx.removeWhere((e) => e.isEven);
      expect(rx.value, [1, 3]);
    });

    test('retainWhere keeps matching elements', () {
      final rx = RxList<int>([1, 2, 3, 4]);
      rx.retainWhere((e) => e.isOdd);
      expect(rx.value, [1, 3]);
    });

    test('sort sorts elements', () {
      final rx = RxList<int>([3, 1, 2]);
      rx.sort();
      expect(rx.value, [1, 2, 3]);
    });

    test('sort with custom comparator', () {
      final rx = RxList<int>([3, 1, 2]);
      rx.sort((a, b) => b.compareTo(a)); // descending
      expect(rx.value, [3, 2, 1]);
    });

    test('shuffle does not throw', () {
      final rx = RxList<int>([1, 2, 3, 4, 5]);
      expect(() => rx.shuffle(), returnsNormally);
      expect(rx.length, 5);
    });

    test('refresh triggers listeners', () {
      final rx = RxList<int>([1, 2, 3]);
      int notified = 0;
      rx.addListener(() => notified++);
      rx.refresh();
      expect(notified, 1);
    });
  });

  // ══════════════════════════════════════════════════════════
  // bulkUpdate — L550-552 failure branch
  // ══════════════════════════════════════════════════════════
  group('RxList.bulkUpdate', () {
    test('bulkUpdate applies changes atomically', () {
      final rx = RxList<int>([1, 2, 3]);
      int notifications = 0;
      rx.addListener(() => notifications++);

      rx.bulkUpdate((list) {
        list.add(4);
        list.remove(1);
      });

      expect(rx.value, [2, 3, 4]);
      expect(notifications, 1); // only one notification
    });

    test('bulkUpdate logs error and does not crash on exception', () {
      final rx = RxList<int>([1, 2, 3]);
      expect(
        () => rx.bulkUpdate((_) => throw Exception('bulk error')),
        returnsNormally,
      );
      // Original value preserved (copy was made before update)
      expect(rx.value, [1, 2, 3]);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Validated try* success paths
  // ══════════════════════════════════════════════════════════
  group('RxList try* methods success paths', () {
    test('tryInsert at index 0 succeeds', () {
      final rx = RxList<String>(['b', 'c']);
      final r = rx.tryInsert(0, 'a');
      expect(r.isSuccess, true);
      expect(rx.value, ['a', 'b', 'c']);
    });

    test('tryRemoveAt middle element', () {
      final rx = RxList<int>([10, 20, 30]);
      final r = rx.tryRemoveAt(1);
      expect(r.isSuccess, true);
      expect(r.value, 20);
      expect(rx.value, [10, 30]);
    });

    test('trySetAt updates element', () {
      final rx = RxList<int>([1, 2, 3]);
      final r = rx.trySetAt(1, 99);
      expect(r.isSuccess, true);
      expect(rx.value, [1, 99, 3]);
    });

    test('tryUpdateAt updates element', () {
      final rx = RxList<int>([1, 2, 3]);
      final r = rx.tryUpdateAt(2, 100);
      expect(r.isSuccess, true);
      expect(rx.value, [1, 2, 100]);
    });

    test('tryReplaceAll replaces all occurrences', () {
      final rx = RxList<String>(['a', 'b', 'a']);
      final r = rx.tryReplaceAll('a', 'x');
      expect(r.isSuccess, true);
      expect(rx.value, ['x', 'b', 'x']);
    });

    test('tryRetainWhere keeps matching', () {
      final rx = RxList<int>([1, 2, 3, 4, 5]);
      final r = rx.tryRetainWhere((e) => e > 3);
      expect(r.isSuccess, true);
      expect(rx.value, [4, 5]);
    });

    test('tryShuffle succeeds', () {
      final rx = RxList<int>([1, 2, 3, 4, 5]);
      final r = rx.tryShuffle();
      expect(r.isSuccess, true);
    });

    test('tryClear succeeds', () {
      final rx = RxList<int>([1, 2, 3]);
      final r = rx.tryClear();
      expect(r.isSuccess, true);
      expect(rx.value, isEmpty);
    });
  });
}
