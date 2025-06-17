import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxList Extensions', () {
    test('should add and remove items', () {
      final list = <int>[].obs();

      list.add(1);
      expect(list.value, [1]);

      list.addAll([2, 3, 4]);
      expect(list.value, [1, 2, 3, 4]);

      final removed = list.remove(2);
      expect(removed, true);
      expect(list.value, [1, 3, 4]);

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

      // Shuffle test - just ensure it doesn't crash
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
      expect(notifications, 1); // Only one notification for bulk update
    });
  });
}