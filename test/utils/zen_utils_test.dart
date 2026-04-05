import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/utils/zen_utils.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // ZenUtils.structuralEquals
  // ══════════════════════════════════════════════════════════
  group('ZenUtils.structuralEquals — primitives', () {
    test('same object is equal to itself', () {
      final obj = Object();
      expect(ZenUtils.structuralEquals(obj, obj), true);
    });

    test('equal ints are equal', () {
      expect(ZenUtils.structuralEquals(1, 1), true);
    });

    test('different ints are not equal', () {
      expect(ZenUtils.structuralEquals(1, 2), false);
    });

    test('null equals null', () {
      expect(ZenUtils.structuralEquals(null, null), true);
    });

    test('null not equal to non-null', () {
      expect(ZenUtils.structuralEquals(null, 0), false);
    });

    test('equal strings are equal', () {
      expect(ZenUtils.structuralEquals('hello', 'hello'), true);
    });

    test('different strings are not equal', () {
      expect(ZenUtils.structuralEquals('a', 'b'), false);
    });
  });

  group('ZenUtils.structuralEquals — lists', () {
    test('equal lists are equal', () {
      expect(ZenUtils.structuralEquals([1, 2, 3], [1, 2, 3]), true);
    });

    test('different-length lists are not equal', () {
      expect(ZenUtils.structuralEquals([1, 2], [1, 2, 3]), false);
    });

    test('lists with different elements are not equal', () {
      expect(ZenUtils.structuralEquals([1, 2, 3], [1, 2, 4]), false);
    });

    test('empty lists are equal', () {
      expect(ZenUtils.structuralEquals([], []), true);
    });

    test('nested equal lists are equal', () {
      expect(
        ZenUtils.structuralEquals(
          [
            1,
            [2, 3]
          ],
          [
            1,
            [2, 3]
          ],
        ),
        true,
      );
    });

    test('nested different lists are not equal', () {
      expect(
        ZenUtils.structuralEquals(
          [
            1,
            [2, 3]
          ],
          [
            1,
            [2, 4]
          ],
        ),
        false,
      );
    });
  });

  group('ZenUtils.structuralEquals — maps', () {
    test('equal maps are equal', () {
      expect(ZenUtils.structuralEquals({'a': 1}, {'a': 1}), true);
    });

    test('maps with different values are not equal', () {
      expect(ZenUtils.structuralEquals({'a': 1}, {'a': 2}), false);
    });

    test('maps with different keys are not equal', () {
      expect(ZenUtils.structuralEquals({'a': 1}, {'b': 1}), false);
    });

    test('maps with different sizes are not equal', () {
      expect(ZenUtils.structuralEquals({'a': 1}, {'a': 1, 'b': 2}), false);
    });

    test('empty maps are equal', () {
      expect(ZenUtils.structuralEquals(<String, int>{}, <String, int>{}), true);
    });

    test('maps with nested list values are compared deeply', () {
      expect(
        ZenUtils.structuralEquals({
          'k': [1, 2]
        }, {
          'k': [1, 2]
        }),
        true,
      );
    });

    test('maps with different nested lists are not equal', () {
      expect(
        ZenUtils.structuralEquals({
          'k': [1, 2]
        }, {
          'k': [1, 3]
        }),
        false,
      );
    });
  });

  group('ZenUtils.structuralEquals — sets', () {
    test('equal sets are equal', () {
      expect(ZenUtils.structuralEquals({1, 2, 3}, {3, 2, 1}), true);
    });

    test('sets with different elements are not equal', () {
      expect(ZenUtils.structuralEquals({1, 2}, {1, 3}), false);
    });

    test('sets with different sizes are not equal', () {
      expect(ZenUtils.structuralEquals({1, 2}, {1, 2, 3}), false);
    });

    test('empty sets are equal', () {
      expect(ZenUtils.structuralEquals(<int>{}, <int>{}), true);
    });
  });

  group('ZenUtils.structuralEquals — type mismatches', () {
    test('list is not equal to map', () {
      expect(ZenUtils.structuralEquals([1], {'a': 1}), false);
    });

    test('map is not equal to set', () {
      expect(ZenUtils.structuralEquals({'a'}, {'a': 1}), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenUtils.shareStructure
  // ══════════════════════════════════════════════════════════
  group('ZenUtils.shareStructure', () {
    test('returns old data when structurally equal', () {
      final old = [1, 2, 3];
      final result = ZenUtils.shareStructure(old, [1, 2, 3]);
      expect(identical(result, old), true);
    });

    test('returns new data when not equal', () {
      final old = [1, 2, 3];
      final newData = [1, 2, 4];
      final result = ZenUtils.shareStructure(old, newData);
      expect(identical(result, newData), true);
    });

    test('works with maps', () {
      final old = {'a': 1};
      final result = ZenUtils.shareStructure(old, {'a': 1});
      expect(identical(result, old), true);
    });

    test('works with primitives', () {
      const old = 42;
      expect(ZenUtils.shareStructure(old, 42), 42);
      expect(ZenUtils.shareStructure(old, 99), 99);
    });
  });
}
