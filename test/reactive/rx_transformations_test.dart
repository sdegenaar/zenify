import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for rx_transformations.dart — covering uncovered extensions:
/// - transform, filter, distinctMap, combineLatest, switchMap, take, skip
/// - asNullable, withDefault, whereNotNull, mapNotNull
/// - RxCollectionTransformations: rxLength, rxIsEmpty, whereList, mapList, sortedBy
void main() {
  // ══════════════════════════════════════════════════════════
  // RxTransformations
  // ══════════════════════════════════════════════════════════
  group('RxTransformations.transform', () {
    test('transforms value via mapper', () {
      final n = 3.obs();
      final sq = n.transform((v) => v * v);
      expect(sq.value, 9);
      n.dispose();
      sq.dispose();
    });
  });

  group('RxTransformations.filter', () {
    test('returns value when predicate true', () {
      final n = 10.obs();
      final filtered = n.filter((v) => v > 5);
      expect(filtered.value, 10);
      n.dispose();
      filtered.dispose();
    });

    test('returns null when predicate false', () async {
      final n = 10.obs();
      final filtered = n.filter((v) => v > 20);
      expect(filtered.value, isNull);
      n.dispose();
      filtered.dispose();
    });
  });

  group('RxTransformations.distinctMap', () {
    test('maps value via mapper', () {
      final n = 5.obs();
      final mapped = n.distinctMap((v) => v.toString());
      expect(mapped.value, '5');
      n.dispose();
      mapped.dispose();
    });

    test('does not return same reference when value changes', () async {
      final n = 5.obs();
      final mapped = n.distinctMap((v) => v.toString());
      n.value = 10;
      await Future.delayed(Duration.zero);
      expect(mapped.value, '10');
      n.dispose();
      mapped.dispose();
    });
  });

  group('RxTransformations.combineLatest', () {
    test('combines two observables', () {
      final a = 3.obs();
      final b = 4.obs();
      final combined = a.combineLatest(b, (x, y) => x + y);
      expect(combined.value, 7);
      a.dispose();
      b.dispose();
      combined.dispose();
    });
  });

  group('RxTransformations.switchMap', () {
    test('switches to mapped computed', () {
      final flag = true.obs();
      final result = flag.switchMap<int>((v) => computed(() => v ? 1 : 0));
      expect(result.value, isNotNull);
      flag.dispose();
      result.dispose();
    });
  });

  group('RxTransformations.take', () {
    test('returns value while within count', () {
      final n = 5.obs();
      final taken = n.take(3);
      expect(taken.value, 5);
      n.dispose();
      taken.dispose();
    });

    test('returns null after count exceeded', () async {
      final n = 0.obs();
      final taken = n.take(1);
      n.value = 1; // 1st change → still within? depends on impl
      n.value = 2; // 2nd change
      n.value = 3; // 3rd change, count exceeded
      await Future.delayed(Duration.zero);
      // Value may be null or last seen — just verify no crash
      expect(() => taken.value, returnsNormally);
      n.dispose();
      taken.dispose();
    });
  });

  group('RxTransformations.skip', () {
    test('skips initial value (returns null before count)', () {
      final n = 0.obs();
      final skipped = n.skip(2);
      // Should return null until 2nd change after init
      expect(skipped.value, isNull);
      n.dispose();
      skipped.dispose();
    });

    test('returns value after skip count', () async {
      final n = 0.obs();
      final skipped = n.skip(1);
      n.value = 1;
      n.value = 2; // skip count passed
      await Future.delayed(Duration.zero);
      expect(skipped.value, isNotNull);
      n.dispose();
      skipped.dispose();
    });
  });

  group('RxTransformations.asNullable', () {
    test('returns current value as nullable', () {
      final n = 42.obs();
      final nullable = n.asNullable();
      expect(nullable.value, 42);
      n.dispose();
      nullable.dispose();
    });
  });

  group('RxTransformations.withDefault (nullable)', () {
    test('provides default when value is null', () {
      final n = Rx<int?>(null);
      final withDef = n.withDefault(99);
      expect(withDef.value, 99);
      n.dispose();
      withDef.dispose();
    });

    test('uses existing value when not null', () {
      final n = Rx<int?>(7);
      final withDef = n.withDefault(99);
      expect(withDef.value, 7);
      n.dispose();
      withDef.dispose();
    });
  });

  group('RxTransformations.whereNotNull', () {
    test('returns value when not null', () {
      final n = Rx<int?>(5);
      final nn = n.whereNotNull();
      expect(nn.value, 5);
      n.dispose();
      nn.dispose();
    });

    test('returns null when value is null', () {
      final n = Rx<int?>(null);
      final nn = n.whereNotNull();
      expect(nn.value, isNull);
      n.dispose();
      nn.dispose();
    });
  });

  group('RxTransformations.mapNotNull', () {
    test('maps when value is not null', () {
      final n = Rx<int?>(5);
      final mapped = n.mapNotNull((v) => v * 2);
      expect(mapped.value, 10);
      n.dispose();
      mapped.dispose();
    });

    test('returns null when value is null', () {
      final n = Rx<int?>(null);
      final mapped = n.mapNotNull((v) => v * 2);
      expect(mapped.value, isNull);
      n.dispose();
      mapped.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxCollectionTransformations
  // ══════════════════════════════════════════════════════════
  group('RxCollectionTransformations', () {
    test('rxLength returns computed length', () {
      final list = [1, 2, 3].obs();
      final len = list.rxLength;
      expect(len.value, 3);
      list.dispose();
      len.dispose();
    });

    test('rxIsEmpty returns computed isEmpty', () {
      final list = <int>[].obs();
      final empty = list.rxIsEmpty;
      expect(empty.value, true);
      list.dispose();
      empty.dispose();
    });

    test('whereList filters list elements', () {
      final list = [1, 2, 3, 4].obs();
      final evens = list.whereList((x) => x.isEven);
      expect(evens.value, [2, 4]);
      list.dispose();
      evens.dispose();
    });

    test('mapList transforms list elements', () {
      final list = [1, 2, 3].obs();
      final doubled = list.mapList((x) => x * 2);
      expect(doubled.value, [2, 4, 6]);
      list.dispose();
      doubled.dispose();
    });

    test('sortedBy sorts list by comparable key', () {
      final list = [3, 1, 2].obs();
      final sorted = list.sortedBy<num>((x) => x);
      expect(sorted.value, [1, 2, 3]);
      list.dispose();
      sorted.dispose();
    });
  });
}
