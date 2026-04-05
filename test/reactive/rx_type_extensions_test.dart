import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  // ─────────────────────────────────────────────────
  // RxInt
  // ─────────────────────────────────────────────────
  group('RxInt convenience methods', () {
    test('increment and decrement', () {
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

    test('multiply and divide', () {
      final num = 10.obs();
      num.multiply(3);
      expect(num.value, 30);
      num.divide(6);
      expect(num.value, 5);
    });

    test('modulo', () {
      final num = 10.obs();
      num.modulo(3);
      expect(num.value, 1);
    });

    test('power', () {
      final num = 2.obs();
      num.power(4);
      expect(num.value, 16);
    });

    test('number property getters', () {
      final even = 4.obs();
      final odd = 5.obs();
      final negative = (-3).obs();
      expect(even.isEven, true);
      expect(even.isOdd, false);
      expect(odd.isOdd, true);
      expect(negative.isNegative, true);
      expect(negative.abs, 3);
      expect(0.obs().sign, 0);
      expect(5.obs().sign, 1);
      expect((-5).obs().sign, -1);
    });
  });

  group('RxInt try* methods', () {
    test('tryIncrement succeeds', () {
      final n = 1.obs();
      expect(n.tryIncrement(5).isSuccess, true);
      expect(n.value, 6);
    });

    test('tryDecrement succeeds', () {
      final n = 10.obs();
      expect(n.tryDecrement(3).isSuccess, true);
      expect(n.value, 7);
    });

    test('tryMultiply succeeds', () {
      final n = 3.obs();
      expect(n.tryMultiply(4).isSuccess, true);
      expect(n.value, 12);
    });

    test('tryDivide succeeds', () {
      final n = 10.obs();
      expect(n.tryDivide(2).isSuccess, true);
      expect(n.value, 5);
    });

    test('tryDivide fails on zero divisor', () {
      final n = 10.obs();
      expect(n.tryDivide(0).isFailure, true);
    });

    test('tryModulo succeeds', () {
      final n = 7.obs();
      expect(n.tryModulo(3).isSuccess, true);
      expect(n.value, 1);
    });

    test('tryModulo fails on zero divisor', () {
      expect(5.obs().tryModulo(0).isFailure, true);
    });

    test('tryPower with exponent 0 gives 1', () {
      final n = 5.obs();
      expect(n.tryPower(0).isSuccess, true);
      expect(n.value, 1);
    });

    test('tryPower fails with negative exponent', () {
      expect(5.obs().tryPower(-1).isFailure, true);
    });
  });

  // ─────────────────────────────────────────────────
  // RxDouble
  // ─────────────────────────────────────────────────
  group('RxDouble convenience methods', () {
    test('increment and decrement', () {
      final d = 1.5.obs();
      d.increment(0.5);
      expect(d.value, closeTo(2.0, 0.001));
      d.decrement(1.0);
      expect(d.value, closeTo(1.0, 0.001));
    });

    test('multiply and divide', () {
      final d = 4.0.obs();
      d.multiply(2.5);
      expect(d.value, closeTo(10.0, 0.001));
      d.divide(5.0);
      expect(d.value, closeTo(2.0, 0.001));
    });

    test('divide by zero fails', () {
      expect(5.0.obs().tryDivide(0).isFailure, true);
    });

    test('property getters', () {
      expect((-1.5).obs().isNegative, true);
      expect((-1.5).obs().abs, closeTo(1.5, 0.001));
      expect(3.7.obs().isFinite, true);
      expect(double.infinity.obs().isInfinite, true);
      expect(double.nan.obs().isNaN, true);
    });

    test('round, floor, ceil, truncate', () {
      final d = 2.7.obs();
      d.round();
      expect(d.value, closeTo(3.0, 0.001));

      final d2 = 2.7.obs();
      d2.floor();
      expect(d2.value, closeTo(2.0, 0.001));

      final d3 = 2.1.obs();
      d3.ceil();
      expect(d3.value, closeTo(3.0, 0.001));

      final d4 = 2.9.obs();
      d4.truncate();
      expect(d4.value, closeTo(2.0, 0.001));
    });
  });

  group('RxDouble try* methods', () {
    test('tryIncrement succeeds', () {
      final d = 1.0.obs();
      expect(d.tryIncrement(0.5).isSuccess, true);
      expect(d.value, closeTo(1.5, 0.001));
    });

    test('tryDecrement succeeds', () {
      final d = 3.0.obs();
      expect(d.tryDecrement(1.0).isSuccess, true);
      expect(d.value, closeTo(2.0, 0.001));
    });

    test('tryMultiply succeeds', () {
      final d = 2.0.obs();
      expect(d.tryMultiply(3).isSuccess, true);
      expect(d.value, closeTo(6.0, 0.001));
    });
  });

  // ─────────────────────────────────────────────────
  // RxBool
  // ─────────────────────────────────────────────────
  group('RxBool convenience methods', () {
    test('toggle', () {
      final flag = false.obs();
      flag.toggle();
      expect(flag.value, true);
      flag.toggle();
      expect(flag.value, false);
    });

    test('setTrue and setFalse', () {
      final flag = false.obs();
      flag.setTrue();
      expect(flag.value, true);
      flag.setFalse();
      expect(flag.value, false);
    });
  });

  group('RxBool try* methods', () {
    test('tryToggle succeeds', () {
      final flag = false.obs();
      expect(flag.tryToggle().isSuccess, true);
      expect(flag.value, true);
    });

    test('trySetTrue succeeds', () {
      final flag = false.obs();
      expect(flag.trySetTrue().isSuccess, true);
      expect(flag.value, true);
    });

    test('trySetFalse succeeds', () {
      final flag = true.obs();
      expect(flag.trySetFalse().isSuccess, true);
      expect(flag.value, false);
    });
  });

  // ─────────────────────────────────────────────────
  // RxString
  // ─────────────────────────────────────────────────
  group('RxString convenience methods', () {
    test('append, prepend, case conversion', () {
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

    test('trim and clear', () {
      final text = '  hello  '.obs();
      text.trim();
      expect(text.value, 'hello');
      text.clear();
      expect(text.isEmpty, true);
    });

    test('replace substitutes pattern', () {
      final text = 'hello world'.obs();
      text.replace('world', 'dart');
      expect(text.value, 'hello dart');
    });

    test('property getters', () {
      final text = 'hello world'.obs();
      expect(text.length, 11);
      expect(text.isEmpty, false);
      expect(text.isNotEmpty, true);
      expect(text.contains('world'), true);
      expect(text.startsWith('hello'), true);
      expect(text.endsWith('world'), true);
    });

    test('indexOf and lastIndexOf', () {
      final text = 'abcabc'.obs();
      expect(text.indexOf('b'), 1);
      expect(text.lastIndexOf('b'), 4);
    });

    test('substring extracts range', () {
      final text = 'hello'.obs();
      expect(text.substring(1, 3), 'el');
    });

    test('split splits by pattern', () {
      final text = 'a,b,c'.obs();
      expect(text.split(','), ['a', 'b', 'c']);
    });
  });

  group('RxString try* methods', () {
    test('tryAppend succeeds', () {
      final s = 'foo'.obs();
      expect(s.tryAppend('bar').isSuccess, true);
      expect(s.value, 'foobar');
    });

    test('tryPrepend succeeds', () {
      final s = 'bar'.obs();
      expect(s.tryPrepend('foo').isSuccess, true);
      expect(s.value, 'foobar');
    });

    test('tryClear clears string', () {
      final s = 'hello'.obs();
      expect(s.tryClear().isSuccess, true);
      expect(s.value, '');
    });

    test('tryToUpperCase succeeds', () {
      final s = 'hello'.obs();
      expect(s.tryToUpperCase().isSuccess, true);
      expect(s.value, 'HELLO');
    });

    test('tryToLowerCase succeeds', () {
      final s = 'HELLO'.obs();
      expect(s.tryToLowerCase().isSuccess, true);
      expect(s.value, 'hello');
    });

    test('tryTrim succeeds', () {
      final s = '  hi  '.obs();
      expect(s.tryTrim().isSuccess, true);
      expect(s.value, 'hi');
    });

    test('tryReplace succeeds', () {
      final s = 'foo bar'.obs();
      expect(s.tryReplace('bar', 'baz').isSuccess, true);
      expect(s.value, 'foo baz');
    });
  });
}
