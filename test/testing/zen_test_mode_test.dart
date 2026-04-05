import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() => Zen.init());
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // ZenTestMode — singleton behavior
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode singleton', () {
    test('ZenTestMode() returns the same singleton', () {
      final a = ZenTestMode();
      final b = ZenTestMode();
      expect(identical(a, b), true);
    });

    test('zenTestMode() returns the same singleton', () {
      final a = zenTestMode();
      final b = ZenTestMode();
      expect(identical(a, b), true);
    });

    test('ZenTestingExtension.testMode() returns the same singleton', () {
      final a = ZenTestingExtension.testMode();
      final b = ZenTestMode();
      expect(identical(a, b), true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // mock<T> — correct type registration
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.mock', () {
    test('registers instance under correct type', () {
      ZenTestMode().mock<_Service>(_ServiceImpl('mock-A'));
      expect(Zen.find<_Service>(), isNotNull);
      expect((Zen.find<_Service>() as _ServiceImpl).label, 'mock-A');
    });

    test('replaces existing registration', () {
      Zen.put<_Service>(_ServiceImpl('original'));
      ZenTestMode().mock<_Service>(_ServiceImpl('replaced'));
      expect((Zen.find<_Service>() as _ServiceImpl).label, 'replaced');
    });

    test('mock is chainable', () {
      final mode = ZenTestMode()
          .mock<_Service>(_ServiceImpl('chain-A'))
          .mock<_Other>(_Other());
      expect(mode, isA<ZenTestMode>());
      expect(Zen.find<_Service>(), isNotNull);
      expect(Zen.find<_Other>(), isNotNull);
    });

    test('mock with tag registers under tag', () {
      ZenTestMode().mock<_Service>(_ServiceImpl('tagged'), tag: 'premium');
      expect(Zen.find<_Service>(tag: 'premium'), isNotNull);
      expect(Zen.findOrNull<_Service>(),
          isNull); // untagged version not registered
    });
  });

  // ══════════════════════════════════════════════════════════
  // mockLazy<T>
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.mockLazy', () {
    test('registers lazy factory', () {
      ZenTestMode().mockLazy<_Service>(() => _ServiceImpl('lazy'));
      expect(Zen.find<_Service>(), isNotNull);
    });

    test('alwaysNew creates fresh instance each time', () {
      var count = 0;
      ZenTestMode().mockLazy<_Service>(
        () => _ServiceImpl('inst-${++count}'),
        alwaysNew: true,
      );
      final a = Zen.find<_Service>();
      final b = Zen.find<_Service>();
      expect(identical(a, b), false);
    });

    test('mockLazy is chainable', () {
      final mode = ZenTestMode().mockLazy<_Service>(() => _ServiceImpl('L'));
      expect(mode, isA<ZenTestMode>());
    });
  });

  // ══════════════════════════════════════════════════════════
  // isolatedScope
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.isolatedScope', () {
    test('returns a non-null scope', () {
      final scope = ZenTestMode().isolatedScope(name: 'Isolated');
      expect(scope, isNotNull);
      expect(scope.isDisposed, false);
      scope.dispose();
    });

    test('scope accepts dependencies independently', () {
      final scope = ZenTestMode().isolatedScope(name: 'Isolated2');
      scope.put<_Service>(_ServiceImpl('scoped'));
      expect(scope.find<_Service>()?.label, 'scoped');
      scope.dispose();
    });

    test('isolated scope is separate from root scope', () {
      final scope = ZenTestMode().isolatedScope();
      scope.put<_Service>(_ServiceImpl('isolated'));
      // Root scope doesn't see it
      expect(Zen.findOrNull<_Service>(), isNull);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // clearQueryCache
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.clearQueryCache', () {
    test('clearQueryCache is chainable', () {
      final mode = ZenTestMode().clearQueryCache();
      expect(mode, isA<ZenTestMode>());
    });

    test('clearQueryCache does not crash', () {
      expect(() => ZenTestMode().clearQueryCache(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // reset
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.reset', () {
    test('reset does not crash', () {
      expect(() => ZenTestMode().reset(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // mockAll — documented bug test
  // ══════════════════════════════════════════════════════════
  group('ZenTestMode.mockAll (deprecated, broken)', () {
    test('mockAll is deprecated and returns self', () {
      // ignore: deprecated_member_use
      final mode = ZenTestMode().mockAll({_Service: _ServiceImpl('broken')});
      expect(mode, isA<ZenTestMode>());
    });

    test('mockAll does NOT register under the interface type (known bug)', () {
      // ignore: deprecated_member_use
      ZenTestMode().mockAll({_Service: _ServiceImpl('broken')});
      // BUG: Zen.findOrNull<_Service>() returns null because Dart infers T=dynamic
      // when calling Zen.put(instance) with a dynamic-typed variable.
      // The instance is registered under `dynamic`, not `_Service`.
      expect(
        Zen.findOrNull<_Service>(),
        isNull, // This proves the bug — mock wasn't registered correctly
        reason: 'mockAll registers under dynamic due to Dart type erasure. '
            'This is the documented behavior. Use .mock<T>() instead.',
      );
    });
  });
}

abstract class _Service {
  String get label;
}

class _ServiceImpl implements _Service {
  @override
  final String label;
  _ServiceImpl(this.label);
}

class _Other {}
