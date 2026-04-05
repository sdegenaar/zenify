import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered lines in reactive/computed/rx_computed.dart:
/// - tryGetValue (success and failure)
/// - valueOr
/// - set value throws UnsupportedError
/// - dispose idempotency
/// - toString
/// - refresh
/// - map / where / combineWith extensions
/// - RxCombine.combine2 / combine3 / combine4
void main() {
  // ══════════════════════════════════════════════════════════
  // Basic computed functionality
  // ══════════════════════════════════════════════════════════
  group('RxComputed basic', () {
    test('computed derives value from dependency', () {
      final n = 3.obs();
      final sq = computed(() => n.value * n.value);
      expect(sq.value, 9);
      n.dispose();
      sq.dispose();
    });

    test('computed updates when dependency changes', () async {
      final n = 5.obs();
      final doubled = computed(() => n.value * 2);
      n.value = 10;
      await Future.delayed(Duration.zero);
      expect(doubled.value, 20);
      n.dispose();
      doubled.dispose();
    });

    test('dependencies returns tracked set', () {
      final a = 1.obs();
      final c = computed(() => a.value + 1);
      expect(c.dependencies.length, 1);
      a.dispose();
      c.dispose();
    });

    test('isDisposed is false before dispose', () {
      final a = 0.obs();
      final c = computed(() => a.value);
      expect(c.isDisposed, false);
      a.dispose();
      c.dispose();
    });

    test('isDisposed is true after dispose', () {
      final a = 0.obs();
      final c = computed(() => a.value);
      c.dispose();
      expect(c.isDisposed, true);
      a.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // tryGetValue
  // ══════════════════════════════════════════════════════════
  group('RxComputed.tryGetValue', () {
    test('returns success when no error', () {
      final n = 1.obs();
      final c = computed(() => n.value);
      final result = c.tryGetValue();
      expect(result.isSuccess, true);
      expect(result.value, 1);
      n.dispose();
      c.dispose();
    });

    test('returns failure when computation throws', () {
      final flag = false.obs();
      // Build a computed that will fail after first change
      final c = computed<int>(() {
        if (flag.value) throw Exception('boom');
        return 0;
      });

      flag.value = true; // triggers error in _onDependencyChanged
      expect(c.hasError, true);
      final result = c.tryGetValue();
      expect(result.isSuccess, false);

      flag.dispose();
      c.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // valueOr
  // ══════════════════════════════════════════════════════════
  group('RxComputed.valueOr', () {
    test('returns value when no error', () {
      final n = 7.obs();
      final c = computed(() => n.value);
      expect(c.valueOr(999), 7);
      n.dispose();
      c.dispose();
    });

    test('returns fallback when computation throws', () {
      final flag = false.obs();
      final c = computed<int>(() {
        if (flag.value) throw Exception('fail');
        return 0;
      });
      flag.value = true;
      expect(c.valueOr(-1), -1);
      flag.dispose();
      c.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // set value throws
  // ══════════════════════════════════════════════════════════
  group('RxComputed.value setter', () {
    test('setting value throws UnsupportedError', () {
      final n = 0.obs();
      final c = computed(() => n.value);
      expect(() => c.value = 99, throwsUnsupportedError);
      n.dispose();
      c.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // refresh
  // ══════════════════════════════════════════════════════════
  group('RxComputed.refresh', () {
    test('refresh recomputes value', () {
      var counter = 0;
      final n = 0.obs();
      final c = computed(() {
        counter++;
        return n.value;
      });
      final initial = counter;
      c.refresh();
      expect(counter, greaterThan(initial));
      n.dispose();
      c.dispose();
    });

    test('refresh on disposed does nothing', () {
      final n = 0.obs();
      final c = computed(() => n.value);
      c.dispose();
      expect(() => c.refresh(), returnsNormally);
      n.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // dispose idempotency
  // ══════════════════════════════════════════════════════════
  group('RxComputed.dispose idempotency', () {
    test('second dispose does not throw', () {
      final n = 0.obs();
      final c = computed(() => n.value);
      c.dispose();
      expect(() => c.dispose(), returnsNormally);
      n.dispose();
    });

    test('after dispose dependencies are cleared', () {
      final n = 0.obs();
      final c = computed(() => n.value);
      c.dispose();
      expect(c.dependencies, isEmpty);
      n.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // toString
  // ══════════════════════════════════════════════════════════
  group('RxComputed.toString', () {
    test('includes current value', () {
      final n = 42.obs();
      final c = computed(() => n.value);
      expect(c.toString(), contains('42'));
      n.dispose();
      c.dispose();
    });

    test('includes disposed state', () {
      final n = 0.obs();
      final c = computed(() => n.value);
      c.dispose();
      expect(c.toString(), contains('disposed: true'));
      n.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Extensions: map / where / combineWith
  // ══════════════════════════════════════════════════════════
  group('RxComputedExtensions.map', () {
    test('maps Rx<T> via computed', () {
      final n = 5.obs();
      final doubled = n.map((v) => v * 2);
      expect(doubled.value, 10);
      n.dispose();
      doubled.dispose();
    });

    test('map updates when source changes', () async {
      final n = 3.obs();
      final squared = n.map((v) => v * v);
      n.value = 4;
      await Future.delayed(Duration.zero);
      expect(squared.value, 16);
      n.dispose();
      squared.dispose();
    });
  });

  group('RxComputedExtensions.where', () {
    test('where returns value when predicate true', () {
      final n = 10.obs();
      final evens = n.where((v) => v.isEven);
      expect(evens.value, 10);
      n.dispose();
      evens.dispose();
    });

    test('where returns null when predicate false', () async {
      final n = 10.obs();
      final evens = n.where((v) => v.isEven);
      n.value = 11;
      await Future.delayed(Duration.zero);
      expect(evens.value, isNull);
      n.dispose();
      evens.dispose();
    });
  });

  group('RxComputedExtensions.combineWith', () {
    test('combines two observables', () {
      final a = 3.obs();
      final b = 4.obs();
      final sum = a.combineWith(b, (x, y) => x + y);
      expect(sum.value, 7);
      a.dispose();
      b.dispose();
      sum.dispose();
    });

    test('updates when either changes', () async {
      final a = 1.obs();
      final b = 2.obs();
      final product = a.combineWith(b, (x, y) => x * y);
      a.value = 5;
      await Future.delayed(Duration.zero);
      expect(product.value, 10);
      a.dispose();
      b.dispose();
      product.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxCombine static methods
  // ══════════════════════════════════════════════════════════
  group('RxCombine.combine2', () {
    test('combines 2 sources', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = RxCombine.combine2(a, b, (x, y) => x + y);
      expect(c.value, 3);
      a.dispose();
      b.dispose();
      c.dispose();
    });
  });

  group('RxCombine.combine3', () {
    test('combines 3 sources', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final result = RxCombine.combine3(a, b, c, (x, y, z) => x + y + z);
      expect(result.value, 6);
      a.dispose();
      b.dispose();
      c.dispose();
      result.dispose();
    });

    test('updates when any source changes', () async {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final result = RxCombine.combine3(a, b, c, (x, y, z) => x + y + z);
      c.value = 10;
      await Future.delayed(Duration.zero);
      expect(result.value, 13);
      a.dispose();
      b.dispose();
      c.dispose();
      result.dispose();
    });
  });

  group('RxCombine.combine4', () {
    test('combines 4 sources', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final d = 4.obs();
      final result =
          RxCombine.combine4(a, b, c, d, (w, x, y, z) => w + x + y + z);
      expect(result.value, 10);
      a.dispose();
      b.dispose();
      c.dispose();
      d.dispose();
      result.dispose();
    });
  });
}
