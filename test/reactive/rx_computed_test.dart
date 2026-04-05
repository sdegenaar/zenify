import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

// NOTE: RxComputedExtensions.map / .where / .combineWith share names with
// RxTimingExtensions (now renamed listenMapped/listenWhere) and others.
// We use explicit extension invocation throughout to avoid ambiguity.
// This is documented as a known API design issue — see CHANGELOG.md.

void main() {
  // ══════════════════════════════════════════════════════════
  // RxComputed core
  // ══════════════════════════════════════════════════════════
  group('RxComputed core', () {
    test('computes initial value', () {
      final src = 5.obs();
      final doubled = computed(() => src.value * 2);
      expect(doubled.value, 10);
    });

    test('recomputes when dependency changes', () {
      final src = 3.obs();
      final doubled = computed(() => src.value * 2);
      src.value = 7;
      expect(doubled.value, 14);
    });

    test('does not notify when computed value is unchanged', () {
      final src = 1.obs();
      int notifyCount = 0;
      final parity = computed(() => src.value % 2 == 0 ? 'even' : 'odd');
      parity.addListener(() => notifyCount++);
      src.value = 3; // odd → odd, value unchanged
      expect(notifyCount, 0);
    });

    test('notifies when computed value changes', () {
      final src = 1.obs();
      int notifyCount = 0;
      final parity = computed(() => src.value % 2 == 0 ? 'even' : 'odd');
      parity.addListener(() => notifyCount++);
      src.value = 2; // odd → even
      expect(notifyCount, 1);
    });

    test('dispose stops recomputation', () {
      final src = 1.obs();
      final c = computed(() => src.value * 10);
      c.dispose();
      expect(c.isDisposed, true);
    });

    test('multi-dependency computed updates when any dep changes', () {
      final a = 1.obs();
      final b = 10.obs();
      final sum = computed(() => a.value + b.value);
      a.value = 2;
      expect(sum.value, 12);
      b.value = 20;
      expect(sum.value, 22);
    });

    test('nested computed resolves transitively', () {
      final src = 2.obs();
      final x2 = computed(() => src.value * 2);
      final x4 = computed(() => x2.value * 2);
      src.value = 3;
      expect(x4.value, 12);
    });

    test('computed toString includes type info', () {
      final c = computed(() => 42);
      expect(c.toString(), contains('RxComputed'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxComputedExtensions — explicit invocation required
  // due to naming conflicts with other extensions on Rx<T>
  // ══════════════════════════════════════════════════════════
  group('RxComputedExtensions.map', () {
    test('map transforms value', () {
      final src = 5.obs();
      final mapped = RxComputedExtensions<int>(src).map((v) => v.toString());
      expect(mapped.value, '5');
    });

    test('map recomputes on change', () {
      final src = 1.obs();
      final mapped = RxComputedExtensions<int>(src).map((v) => v * 100);
      src.value = 3;
      expect(mapped.value, 300);
    });
  });

  group('RxComputedExtensions.where', () {
    test('where returns value when predicate true', () {
      final src = 5.obs();
      final filtered = RxComputedExtensions<int>(src).where((v) => v > 3);
      expect(filtered.value, 5);
    });

    test('where returns null when predicate false', () {
      final src = 1.obs();
      final filtered = RxComputedExtensions<int>(src).where((v) => v > 3);
      expect(filtered.value, isNull);
    });

    test('where updates reactively', () {
      final src = 1.obs();
      final filtered = RxComputedExtensions<int>(src).where((v) => v > 3);
      expect(filtered.value, isNull);
      src.value = 5;
      expect(filtered.value, 5);
    });
  });

  group('RxComputedExtensions.combineWith', () {
    test('combineWith combines two sources', () {
      final a = 3.obs();
      final b = 4.obs();
      final combined =
          RxComputedExtensions<int>(a).combineWith(b, (x, y) => x + y);
      expect(combined.value, 7);
    });

    test('combineWith recomputes when either changes', () {
      final a = 1.obs();
      final b = 2.obs();
      final combined =
          RxComputedExtensions<int>(a).combineWith(b, (x, y) => '$x,$y');
      a.value = 9;
      expect(combined.value, '9,2');
      b.value = 8;
      expect(combined.value, '9,8');
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxCombine.combine2/3/4
  // ══════════════════════════════════════════════════════════
  group('RxCombine.combine2', () {
    test('combine2 computes from two sources', () {
      final a = 2.obs();
      final b = 3.obs();
      final product = RxCombine.combine2(a, b, (x, y) => x * y);
      expect(product.value, 6);
    });

    test('combine2 recomputes on either change', () {
      final a = 10.obs();
      final b = 5.obs();
      final diff = RxCombine.combine2(a, b, (x, y) => x - y);
      b.value = 3;
      expect(diff.value, 7);
    });
  });

  group('RxCombine.combine3', () {
    test('combine3 computes from three sources', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final sum = RxCombine.combine3(a, b, c, (x, y, z) => x + y + z);
      expect(sum.value, 6);
    });

    test('combine3 recomputes on any change', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final sum = RxCombine.combine3(a, b, c, (x, y, z) => x + y + z);
      c.value = 10;
      expect(sum.value, 13);
    });
  });

  group('RxCombine.combine4', () {
    test('combine4 computes from four sources', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final d = 4.obs();
      final sum = RxCombine.combine4(a, b, c, d, (w, x, y, z) => w + x + y + z);
      expect(sum.value, 10);
    });

    test('combine4 recomputes on any change', () {
      final a = 1.obs();
      final b = 2.obs();
      final c = 3.obs();
      final d = 4.obs();
      final sum = RxCombine.combine4(a, b, c, d, (w, x, y, z) => w + x + y + z);
      d.value = 100;
      expect(sum.value, 106);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxComputed lifecycle
  // ══════════════════════════════════════════════════════════
  group('RxComputed lifecycle', () {
    test('isDisposed is false initially', () {
      final c = computed(() => 1);
      expect(c.isDisposed, false);
    });

    test('isDisposed is true after dispose', () {
      final c = computed(() => 1);
      c.dispose();
      expect(c.isDisposed, true);
    });

    test('hasError is false for clean computation', () {
      final c = computed(() => 42);
      expect(c.hasError, false);
    });
  });
}
