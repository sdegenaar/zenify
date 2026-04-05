import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxSet try* methods', () {
    test('tryAdd adds new item and returns true', () {
      final set = <int>{}.obs();
      final result = set.tryAdd(1);
      expect(result.isSuccess, true);
      expect(result.value, true);
      expect(set.value, {1});
    });

    test('tryAdd returns false for duplicate', () {
      final set = {1}.obs();
      final result = set.tryAdd(1);
      expect(result.isSuccess, true);
      expect(result.value, false);
      expect(set.value, {1});
    });

    test('tryRemove removes existing item', () {
      final set = {1, 2, 3}.obs();
      final result = set.tryRemove(2);
      expect(result.isSuccess, true);
      expect(result.value, true);
      expect(set.value, {1, 3});
    });

    test('tryRemove returns false for missing item', () {
      final set = {1}.obs();
      final result = set.tryRemove(99);
      expect(result.isSuccess, true);
      expect(result.value, false);
    });

    test('tryClear empties a non-empty set', () {
      final set = {1, 2, 3}.obs();
      final result = set.tryClear();
      expect(result.isSuccess, true);
      expect(set.value, isEmpty);
    });

    test('tryClear on empty set is a no-op (no notification)', () {
      final set = <int>{}.obs();
      var notifications = 0;
      set.addListener(() => notifications++);
      set.tryClear();
      expect(notifications, 0);
    });

    test('tryAddAll adds new items only', () {
      final set = {1}.obs();
      final result = set.tryAddAll([2, 3]);
      expect(result.isSuccess, true);
      expect(set.value, {1, 2, 3});
    });

    test('tryAddAll with duplicates only is a no-op', () {
      final set = {1}.obs();
      var notifications = 0;
      set.addListener(() => notifications++);
      set.tryAddAll([1]);
      expect(notifications, 0);
    });

    test('tryRemoveAll removes specified items', () {
      final set = {1, 2, 3}.obs();
      set.tryRemoveAll([1, 3]);
      expect(set.value, {2});
    });

    test('tryRemoveAll with none matching is a no-op', () {
      final set = {1}.obs();
      var notifications = 0;
      set.addListener(() => notifications++);
      set.tryRemoveAll([99]);
      expect(notifications, 0);
    });

    test('tryRemoveWhere removes matching items', () {
      final set = {1, 2, 3, 4}.obs();
      set.tryRemoveWhere((x) => x.isEven);
      expect(set.value, {1, 3});
    });

    test('tryRetainWhere keeps only matching items', () {
      final set = {1, 2, 3, 4}.obs();
      set.tryRetainWhere((x) => x > 2);
      expect(set.value, {3, 4});
    });

    test('tryFirst returns success on non-empty set', () {
      final set = {42}.obs();
      final result = set.tryFirst;
      expect(result.isSuccess, true);
      expect(result.value, 42);
    });

    test('tryFirst fails on empty set', () {
      final set = <int>{}.obs();
      expect(set.tryFirst.isFailure, true);
    });

    test('tryLast returns success on non-empty set', () {
      final set = {1, 2}.obs();
      expect(set.tryLast.isSuccess, true);
    });

    test('tryLast fails on empty set', () {
      expect(<int>{}.obs().tryLast.isFailure, true);
    });

    test('trySingle returns element for single-item set', () {
      final set = {7}.obs();
      final result = set.trySingle;
      expect(result.isSuccess, true);
      expect(result.value, 7);
    });

    test('trySingle fails on empty set', () {
      expect(<int>{}.obs().trySingle.isFailure, true);
    });

    test('trySingle fails on multi-element set', () {
      expect({1, 2}.obs().trySingle.isFailure, true);
    });
  });

  group('RxSet convenience methods', () {
    test('add inserts item', () {
      final set = <int>{}.obs();
      final added = set.add(5);
      expect(added, true);
      expect(set.value, {5});
    });

    test('add returns false for duplicate', () {
      final set = {5}.obs();
      expect(set.add(5), false);
    });

    test('remove deletes item', () {
      final set = {1, 2}.obs();
      expect(set.remove(1), true);
      expect(set.value, {2});
    });

    test('clear empties the set', () {
      final set = {1, 2, 3}.obs();
      set.clear();
      expect(set.isEmpty, true);
    });

    test('addAll adds multiple items', () {
      final set = <int>{}.obs();
      set.addAll([1, 2, 3]);
      expect(set.value, {1, 2, 3});
    });

    test('removeAll removes specified items', () {
      final set = {1, 2, 3}.obs();
      set.removeAll([1, 2]);
      expect(set.value, {3});
    });

    test('removeWhere removes matching items', () {
      final set = {1, 2, 3, 4}.obs();
      set.removeWhere((x) => x < 3);
      expect(set.value, {3, 4});
    });

    test('retainWhere keeps matching items', () {
      final set = {1, 2, 3}.obs();
      set.retainWhere((x) => x == 2);
      expect(set.value, {2});
    });
  });

  group('RxSet query operations', () {
    test('contains returns true for members', () {
      final set = {1, 2, 3}.obs();
      expect(set.contains(2), true);
      expect(set.contains(99), false);
    });

    test('length returns element count', () {
      expect({1, 2, 3}.obs().length, 3);
    });

    test('isEmpty is true for empty set', () {
      expect(<int>{}.obs().isEmpty, true);
    });

    test('isNotEmpty is true for non-empty set', () {
      expect({1}.obs().isNotEmpty, true);
    });

    test('intersection returns common elements', () {
      final set = {1, 2, 3}.obs();
      expect(set.intersection({2, 3, 4}), {2, 3});
    });

    test('union returns combined elements', () {
      final set = {1, 2}.obs();
      expect(set.union({3, 4}), {1, 2, 3, 4});
    });

    test('difference returns elements not in other', () {
      final set = {1, 2, 3}.obs();
      expect(set.difference({2}), {1, 3});
    });

    test('any returns true when predicate matches', () {
      expect({1, 2, 3}.obs().any((x) => x > 2), true);
    });

    test('every returns true only when all match', () {
      expect({2, 4, 6}.obs().every((x) => x.isEven), true);
      expect({1, 2, 3}.obs().every((x) => x.isEven), false);
    });

    test('map transforms elements', () {
      final set = {1, 2, 3}.obs();
      expect(set.map((x) => x * 2).toSet(), {2, 4, 6});
    });

    test('where filters elements', () {
      final set = {1, 2, 3, 4}.obs();
      expect(set.where((x) => x.isOdd).toSet(), {1, 3});
    });

    test('forEach iterates all elements', () {
      final set = {1, 2, 3}.obs();
      var sum = 0;
      set.forEach((x) => sum += x);
      expect(sum, 6);
    });

    test('firstOrNull returns null for empty set', () {
      expect(<int>{}.obs().firstOrNull, isNull);
    });

    test('lastOrNull returns null for empty set', () {
      expect(<int>{}.obs().lastOrNull, isNull);
    });

    test('singleOrNull returns element for single-item set', () {
      expect({42}.obs().singleOrNull, 42);
    });

    test('singleOrNull returns null for multi-element set', () {
      expect({1, 2}.obs().singleOrNull, isNull);
    });
  });

  group('RxSet conversions', () {
    test('toList returns a list of elements', () {
      final set = {1, 2, 3}.obs();
      expect(set.toList()..sort(), [1, 2, 3]);
    });

    test('toSet returns a copy of the set', () {
      final set = {1, 2}.obs();
      expect(set.toSet(), {1, 2});
    });

    test('join joins elements with separator', () {
      final set = {'a'}.obs();
      set.addAll(['b', 'c']);
      expect(set.join('-'), contains('-'));
    });

    test('refresh notifies listeners', () {
      final set = {1}.obs();
      var count = 0;
      set.addListener(() => count++);
      set.refresh();
      expect(count, 1);
    });
  });

  group('RxSet reactivity', () {
    test('notifies on add', () {
      final set = <int>{}.obs();
      var count = 0;
      set.addListener(() => count++);
      set.add(1);
      expect(count, 1);
    });

    test('notifies on remove', () {
      final set = {1, 2}.obs();
      var count = 0;
      set.addListener(() => count++);
      set.remove(1);
      expect(count, 1);
    });

    test('does not notify when add is duplicate', () {
      final set = {1}.obs();
      var count = 0;
      set.addListener(() => count++);
      set.add(1);
      expect(count, 0);
    });
  });
}
