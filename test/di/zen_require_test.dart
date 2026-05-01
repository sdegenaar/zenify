// test/di/zen_require_test.dart
//
// Tests for scope.require<T>() — the idiomatic throwing dependency lookup
// that replaces the find<T>()! null-assertion pattern.
//
// Key asymmetry this file documents:
//   scope.find<T>()    → T?   (nullable, caller must null-check)
//   scope.require<T>() → T    (throws ZenDependencyNotFoundException if missing)
//   Zen.find<T>()      → T    (already throws, like Get.find)
//   Zen.findOrNull<T>()→ T?   (explicit nullable global form)

import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

class _ServiceA {
  final String value;
  _ServiceA(this.value);
}

class _ServiceB {
  final String value;
  _ServiceB(this.value);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // =========================================================================
  // scope.require<T>() — the valuable addition
  // scope.find<T>() is nullable; scope.require<T>() is the throwing form.
  // =========================================================================

  group('scope.require<T>()', () {
    late ZenScope scope;

    setUp(() {
      Zen.reset();
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.test);
      scope = Zen.createScope(name: 'RequireTestScope');
    });

    tearDown(() {
      if (!scope.isDisposed) scope.dispose();
      Zen.reset();
    });

    // -----------------------------------------------------------------------
    // Happy-path: dependency is present
    // -----------------------------------------------------------------------

    test('returns the registered instance when present', () {
      final svc = _ServiceA('hello');
      scope.put<_ServiceA>(svc);

      final found = scope.require<_ServiceA>();

      expect(found, same(svc));
      expect(found.value, 'hello');
    });

    test('returns instance registered with a tag', () {
      final svc = _ServiceA('tagged');
      scope.put<_ServiceA>(svc, tag: 'myTag');

      final found = scope.require<_ServiceA>(tag: 'myTag');

      expect(found, same(svc));
    });

    test('resolves dependency from parent scope (hierarchical lookup)', () {
      final parent = Zen.createScope(name: 'Parent');
      final child = Zen.createScope(name: 'Child', parent: parent);

      final svc = _ServiceA('from-parent');
      parent.put<_ServiceA>(svc);

      final found = child.require<_ServiceA>();
      expect(found, same(svc));

      parent.dispose();
    });

    test('resolves a lazy-registered dependency', () {
      bool factoryCalled = false;
      scope.putLazy<_ServiceA>(() {
        factoryCalled = true;
        return _ServiceA('lazy');
      });

      expect(factoryCalled, isFalse);

      final found = scope.require<_ServiceA>();

      expect(factoryCalled, isTrue);
      expect(found.value, 'lazy');
    });

    // -----------------------------------------------------------------------
    // Key contrast: scope.find returns null, scope.require throws
    // -----------------------------------------------------------------------

    test('scope.find<T>() returns null when type is missing', () {
      final result = scope.find<_ServiceB>();
      expect(result, isNull);
    });

    test('scope.require<T>() throws where scope.find<T>() would return null',
        () {
      expect(
        () => scope.require<_ServiceB>(),
        throwsA(isA<ZenDependencyNotFoundException>()),
      );
    });

    // -----------------------------------------------------------------------
    // Error-path: exception quality
    // -----------------------------------------------------------------------

    test('exception message includes the missing type name', () {
      try {
        scope.require<_ServiceB>();
        fail('Expected ZenDependencyNotFoundException');
      } on ZenDependencyNotFoundException catch (e) {
        expect(e.toString(), contains('_ServiceB'));
      }
    });

    test('exception message includes the scope name', () {
      try {
        scope.require<_ServiceB>();
        fail('Expected ZenDependencyNotFoundException');
      } on ZenDependencyNotFoundException catch (e) {
        expect(e.toString(), contains('RequireTestScope'));
      }
    });

    test('exception message includes the tag when one is specified', () {
      try {
        scope.require<_ServiceB>(tag: 'missing-tag');
        fail('Expected ZenDependencyNotFoundException');
      } on ZenDependencyNotFoundException catch (e) {
        expect(e.toString(), contains('missing-tag'));
      }
    });

    test('exception includes a registration suggestion', () {
      try {
        scope.require<_ServiceB>();
        fail('Expected ZenDependencyNotFoundException');
      } on ZenDependencyNotFoundException catch (e) {
        expect(e.suggestion, isNotNull);
        expect(e.suggestion, contains('_ServiceB'));
      }
    });

    test('throws when type is registered with a different tag', () {
      scope.put<_ServiceA>(_ServiceA('no-tag'));

      expect(
        () => scope.require<_ServiceA>(tag: 'wrong-tag'),
        throwsA(isA<ZenDependencyNotFoundException>()),
      );
    });

    test('does not throw when the correct tag is used', () {
      scope.put<_ServiceA>(_ServiceA('correct'), tag: 'correct-tag');
      scope.put<_ServiceA>(_ServiceA('wrong'), tag: 'wrong-tag');

      expect(
        () => scope.require<_ServiceA>(tag: 'correct-tag'),
        returnsNormally,
      );
    });

    // -----------------------------------------------------------------------
    // findRequired<T>() is now deprecated — require<T>() is canonical
    // -----------------------------------------------------------------------

    test('require<T>() and findRequired<T>() return the same instance (compat)',
        () {
      final svc = _ServiceA('same');
      scope.put<_ServiceA>(svc);

      // ignore: deprecated_member_use
      expect(scope.require<_ServiceA>(), same(scope.findRequired<_ServiceA>()));
    });

    test('findRequired<T>() is a deprecated alias — delegates to require<T>()',
        () {
      ZenDependencyNotFoundException? fromRequire;
      ZenDependencyNotFoundException? fromFindRequired;

      try {
        scope.require<_ServiceB>();
      } on ZenDependencyNotFoundException catch (e) {
        fromRequire = e;
      }

      try {
        // ignore: deprecated_member_use
        scope.findRequired<_ServiceB>();
      } on ZenDependencyNotFoundException catch (e) {
        fromFindRequired = e;
      }

      expect(fromRequire, isNotNull);
      expect(fromFindRequired, isNotNull);
      // Same context keys — findRequired delegates to require, same exception
      expect(
          fromRequire!.context?.keys, equals(fromFindRequired!.context?.keys));
    });

    // -----------------------------------------------------------------------
    // Disposed scope
    // -----------------------------------------------------------------------

    test('throws after scope is disposed', () {
      final svc = _ServiceA('alive');
      scope.put<_ServiceA>(svc);
      scope.dispose();

      expect(
        () => scope.require<_ServiceA>(),
        throwsA(isA<ZenDependencyNotFoundException>()),
      );
    });
  });

  // =========================================================================
  // Zen.find<T>() global API — documents the already-throwing behaviour.
  // Zen.find is NOT nullable (unlike scope.find). It behaves like Get.find.
  // =========================================================================

  group('Zen.find<T>() throws like Get.find<T>()', () {
    setUp(() {
      Zen.reset();
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.test);
    });

    tearDown(() {
      Zen.reset();
    });

    test('returns the instance when registered', () {
      final svc = _ServiceA('root');
      Zen.put<_ServiceA>(svc);

      expect(Zen.find<_ServiceA>(), same(svc));
    });

    test('throws ZenDependencyNotFoundException when not registered', () {
      expect(
        () => Zen.find<_ServiceB>(),
        throwsA(isA<ZenDependencyNotFoundException>()),
      );
    });

    test('exception includes type name', () {
      try {
        Zen.find<_ServiceB>();
        fail('Expected exception');
      } on ZenDependencyNotFoundException catch (e) {
        expect(e.toString(), contains('_ServiceB'));
      }
    });

    test('Zen.findOrNull<T>() returns null instead of throwing', () {
      expect(Zen.findOrNull<_ServiceB>(), isNull);
    });

    test('find and findOrNull return same instance when present', () {
      final svc = _ServiceA('same-global');
      Zen.put<_ServiceA>(svc);

      expect(Zen.findOrNull<_ServiceA>(), same(Zen.find<_ServiceA>()));
    });

    test('find with tag returns correct tagged instance', () {
      Zen.put<_ServiceA>(_ServiceA('a'), tag: 'a');
      Zen.put<_ServiceA>(_ServiceA('b'), tag: 'b');

      expect(Zen.find<_ServiceA>(tag: 'a').value, 'a');
      expect(Zen.find<_ServiceA>(tag: 'b').value, 'b');
    });
  });
}
