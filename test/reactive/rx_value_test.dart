import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('Rx<T>', () {
    test('should create and update values correctly', () {
      final count = 0.obs();
      expect(count.value, 0);

      count.value = 5;
      expect(count.value, 5);
    });

    test('should notify listeners on value change', () {
      final count = 0.obs();
      var notifications = 0;

      count.addListener(() => notifications++);

      count.value = 1;
      count.value = 2;

      expect(notifications, 2);
    });

    test('should not notify if value is the same', () {
      final count = 0.obs();
      var notifications = 0;

      count.addListener(() => notifications++);

      count.value = 0; // Same value
      count.value = 0; // Same value

      expect(notifications, 0);
    });

    test('should support update function', () {
      final count = 5.obs();
      count.update((value) => value * 2);
      expect(count.value, 10);
    });

    test('should support updateIfChanged', () {
      final count = 5.obs();
      var notifications = 0;

      count.addListener(() => notifications++);

      count.updateIfChanged(5); // Same value
      expect(notifications, 0);

      count.updateIfChanged(10); // Different value
      expect(notifications, 1);
    });

    test('should support refresh', () {
      final count = 5.obs();
      var notifications = 0;

      count.addListener(() => notifications++);

      count.refresh(); // Should notify even with same value
      expect(notifications, 1);
    });

    test('should handle disposal correctly', () {
      final count = 0.obs();
      expect(count.isDisposed, false);

      count.dispose();
      expect(count.isDisposed, true);

      // Multiple dispose should be safe
      count.dispose();
      expect(count.isDisposed, true);
    });
  });

  group('Type-specific Rx creation', () {
    test('should create different Rx types', () {
      final rxBool = true.obs();
      final rxInt = 42.obs();
      final rxDouble = 3.14.obs();
      final rxString = 'hello'.obs();
      final rxList = [1, 2, 3].obs();
      final rxMap = {'key': 'value'}.obs();
      final rxSet = {1, 2, 3}.obs();

      expect(rxBool.value, true);
      expect(rxInt.value, 42);
      expect(rxDouble.value, 3.14);
      expect(rxString.value, 'hello');
      expect(rxList.value, [1, 2, 3]);
      expect(rxMap.value, {'key': 'value'});
      expect(rxSet.value, {1, 2, 3});
    });

    test('should create nullable Rx types', () {
      final rxnBool = RxnBool(null);
      final rxnInt = RxnInt(null);
      final rxnString = RxnString(null);

      expect(rxnBool.value, null);
      expect(rxnInt.value, null);
      expect(rxnString.value, null);
    });
  });

  group('Factory functions', () {
    test('should create Rx with factory functions', () {
      final boolRx = rxBool(true);
      final intRx = rxInt(42);
      final doubleRx = rxDouble(3.14);
      final stringRx = rxString('test');
      final listRx = rxList<int>([1, 2, 3]);
      final mapRx = rxMap<String, int>({'a': 1});
      final setRx = rxSet<int>({1, 2, 3});

      expect(boolRx.value, true);
      expect(intRx.value, 42);
      expect(doubleRx.value, 3.14);
      expect(stringRx.value, 'test');
      expect(listRx.value, [1, 2, 3]);
      expect(mapRx.value, {'a': 1});
      expect(setRx.value, {1, 2, 3});
    });
  });
}
