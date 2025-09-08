import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxInt Extensions', () {
    test('should increment and decrement', () {
      final count = 5.obs();

      count.increment();
      expect(count.value, 6);

      count.increment(3);
      expect(count.value, 9);

      count.decrement();
      expect(count.value, 8);

      count.decrement(2);
      expect(count.value, 6);
    });

    test('should multiply and divide', () {
      final num = 10.obs();

      num.multiply(3);
      expect(num.value, 30);

      num.divide(6);
      expect(num.value, 5);
    });

    test('should check number properties', () {
      final even = 4.obs();
      final odd = 5.obs();
      final negative = (-3).obs();

      expect(even.isEven, true);
      expect(even.isOdd, false);
      expect(odd.isEven, false);
      expect(odd.isOdd, true);
      expect(negative.isNegative, true);
      expect(negative.abs, 3);
    });
  });

  group('RxBool Extensions', () {
    test('should toggle boolean values', () {
      final flag = false.obs();

      flag.toggle();
      expect(flag.value, true);

      flag.toggle();
      expect(flag.value, false);
    });

    test('should set true and false', () {
      final flag = false.obs();

      flag.setTrue();
      expect(flag.value, true);

      flag.setFalse();
      expect(flag.value, false);
    });
  });

  group('RxString Extensions', () {
    test('should manipulate strings', () {
      final text = 'hello'.obs();

      text.append(' world');
      expect(text.value, 'hello world');

      text.prepend('say ');
      expect(text.value, 'say hello world');

      text.toUpperCase();
      expect(text.value, 'SAY HELLO WORLD');

      text.toLowerCase();
      expect(text.value, 'say hello world');
    });

    test('should provide reactive string properties', () {
      final text = 'hello world'.obs();

      expect(text.length, 11);
      expect(text.isEmpty, false);
      expect(text.isNotEmpty, true);
      expect(text.contains('world'), true);
      expect(text.startsWith('hello'), true);
      expect(text.endsWith('world'), true);
    });

    test('should clear and trim strings', () {
      final text = '  hello world  '.obs();

      text.trim();
      expect(text.value, 'hello world');

      text.clear();
      expect(text.value, '');
      expect(text.isEmpty, true);
    });
  });
}
