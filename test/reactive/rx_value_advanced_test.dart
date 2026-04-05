import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for uncovered lines in reactive/core/rx_value.dart:
/// - factory functions (rxBool, rxInt, etc.)
/// - nullable variants (rxnBool, rxnInt, etc.)
/// - updateIfChanged
/// - refresh
/// - dispose idempotency
/// - toString
/// - type-specific obs() extensions
void main() {
  // ══════════════════════════════════════════════════════════
  // Factory functions
  // ══════════════════════════════════════════════════════════
  group('rx factory functions — defaults', () {
    test('rxBool defaults to false', () {
      final rx = rxBool();
      expect(rx.value, false);
      rx.dispose();
    });

    test('rxBool with initial value', () {
      final rx = rxBool(true);
      expect(rx.value, true);
      rx.dispose();
    });

    test('rxInt defaults to 0', () {
      final rx = rxInt();
      expect(rx.value, 0);
      rx.dispose();
    });

    test('rxInt with initial value', () {
      final rx = rxInt(42);
      expect(rx.value, 42);
      rx.dispose();
    });

    test('rxDouble defaults to 0.0', () {
      final rx = rxDouble();
      expect(rx.value, 0.0);
      rx.dispose();
    });

    test('rxDouble with initial value', () {
      final rx = rxDouble(3.14);
      expect(rx.value, 3.14);
      rx.dispose();
    });

    test('rxString defaults to empty string', () {
      final rx = rxString();
      expect(rx.value, '');
      rx.dispose();
    });

    test('rxString with initial value', () {
      final rx = rxString('hello');
      expect(rx.value, 'hello');
      rx.dispose();
    });

    test('rxList defaults to empty list', () {
      final rx = rxList<int>();
      expect(rx.value, isEmpty);
      rx.dispose();
    });

    test('rxList with initial value', () {
      final rx = rxList([1, 2, 3]);
      expect(rx.value, [1, 2, 3]);
      rx.dispose();
    });

    test('rxMap defaults to empty map', () {
      final rx = rxMap<String, int>();
      expect(rx.value, isEmpty);
      rx.dispose();
    });

    test('rxMap with initial value', () {
      final rx = rxMap({'a': 1});
      expect(rx.value, {'a': 1});
      rx.dispose();
    });

    test('rxSet defaults to empty set', () {
      final rx = rxSet<String>();
      expect(rx.value, isEmpty);
      rx.dispose();
    });

    test('rxSet with initial value', () {
      final rx = rxSet({'x', 'y'});
      expect(rx.value, {'x', 'y'});
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Nullable factory functions
  // ══════════════════════════════════════════════════════════
  group('rxn nullable factory functions', () {
    test('rxnBool defaults to null', () {
      final rx = rxnBool();
      expect(rx.value, isNull);
      rx.dispose();
    });

    test('rxnBool with value', () {
      final rx = rxnBool(true);
      expect(rx.value, true);
      rx.dispose();
    });

    test('rxnInt defaults to null', () {
      final rx = rxnInt();
      expect(rx.value, isNull);
      rx.dispose();
    });

    test('rxnInt with value', () {
      final rx = rxnInt(7);
      expect(rx.value, 7);
      rx.dispose();
    });

    test('rxnDouble defaults to null', () {
      final rx = rxnDouble();
      expect(rx.value, isNull);
      rx.dispose();
    });

    test('rxnDouble with value', () {
      final rx = rxnDouble(1.5);
      expect(rx.value, 1.5);
      rx.dispose();
    });

    test('rxnString defaults to null', () {
      final rx = rxnString();
      expect(rx.value, isNull);
      rx.dispose();
    });

    test('rxnString with value', () {
      final rx = rxnString('hi');
      expect(rx.value, 'hi');
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Type-specific .obs() extensions
  // ══════════════════════════════════════════════════════════
  group('Type-specific .obs() extensions', () {
    test('int.obs() returns RxInt', () {
      final rx = 5.obs();
      expect(rx.value, 5);
      rx.dispose();
    });

    test('double.obs() returns RxDouble', () {
      final rx = 2.5.obs();
      expect(rx.value, 2.5);
      rx.dispose();
    });

    test('bool.obs() returns RxBool', () {
      final rx = true.obs();
      expect(rx.value, true);
      rx.dispose();
    });

    test('String.obs() returns RxString', () {
      final rx = 'test'.obs();
      expect(rx.value, 'test');
      rx.dispose();
    });

    test('List.obs() returns RxList', () {
      final rx = [1, 2].obs();
      expect(rx.value, [1, 2]);
      rx.dispose();
    });

    test('Map.obs() returns RxMap', () {
      final rx = {'k': 'v'}.obs();
      expect(rx.value, {'k': 'v'});
      rx.dispose();
    });

    test('Set.obs() returns RxSet', () {
      final rx = {'a', 'b'}.obs();
      expect(rx.value, {'a', 'b'});
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // updateIfChanged
  // ══════════════════════════════════════════════════════════
  group('Rx.updateIfChanged', () {
    test('does not notify when value is same', () {
      final rx = 10.obs();
      var notified = false;
      rx.addListener(() => notified = true);
      rx.updateIfChanged(10);
      expect(notified, false);
      rx.dispose();
    });

    test('notifies when value changes', () {
      final rx = 10.obs();
      var notified = false;
      rx.addListener(() => notified = true);
      rx.updateIfChanged(20);
      expect(notified, true);
      expect(rx.value, 20);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // refresh
  // ══════════════════════════════════════════════════════════
  group('Rx.refresh', () {
    test('notifies listeners even when value is unchanged', () {
      final rx = 'same'.obs();
      var count = 0;
      rx.addListener(() => count++);
      rx.refresh();
      expect(count, 1);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // dispose idempotency
  // ══════════════════════════════════════════════════════════
  group('Rx.dispose idempotency', () {
    test('second dispose does not throw', () {
      final rx = 0.obs();
      rx.dispose();
      expect(() => rx.dispose(), returnsNormally);
    });

    test('isDisposed is true after dispose', () {
      final rx = 0.obs();
      rx.dispose();
      expect(rx.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // toString
  // ══════════════════════════════════════════════════════════
  group('Rx.toString', () {
    test('includes type and value', () {
      final rx = 42.obs();
      expect(rx.toString(), contains('42'));
      rx.dispose();
    });

    test('includes disposed state when disposed', () {
      final rx = 0.obs();
      rx.dispose();
      expect(rx.toString(), contains('disposed: true'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // call() operator
  // ══════════════════════════════════════════════════════════
  group('Rx.call() operator', () {
    test('call() returns current value', () {
      final rx = 99.obs();
      expect(rx(), 99);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // update() method
  // ══════════════════════════════════════════════════════════
  group('Rx.update()', () {
    test('transforms value', () {
      final rx = 5.obs();
      rx.update((v) => v * 2);
      expect(rx.value, 10);
      rx.dispose();
    });

    test('update on string', () {
      final rx = 'hello'.obs();
      rx.update((v) => v.toUpperCase());
      expect(rx.value, 'HELLO');
      rx.dispose();
    });
  });
}
