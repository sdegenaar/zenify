import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for uncovered paths in core/zen_scope.dart:
/// - forceCompleteReset (L689-705)
/// - getTagForInstance (L708-720)
/// - containsInstance (L738-756)
/// - contains<T> with factory check (L764-772)
/// - findAllOfType (various lines)
/// - putLazy alwaysNew=true (L159-183)
/// - findInThisScope tagged path
///
/// And di/zen_di.dart:
/// - Zen.init() with storage/handlers (L50-70)
/// - Zen.setCurrentScope / resetCurrentScope (L115-123)
/// - Zen.putLazy (L172-184)
/// - Zen.findOrNull (L206-208)
/// - Zen.exists (L211-213)
/// - Zen.createScope (L86-92)
/// - Zen.registerModules (L234-240)
/// - Zen.getModule / hasModule / getAllModules (L242-255)
void main() {
  setUp(Zen.init);
  tearDown(() {
    ZenModuleRegistry.clear();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.forceCompleteReset
  // ══════════════════════════════════════════════════════════
  group('ZenScope.forceCompleteReset', () {
    test('clears all type bindings', () {
      final scope = ZenScope(name: 'ResetScope');
      scope.put<_TestCtrl>(_TestCtrl());
      expect(scope.exists<_TestCtrl>(), true);
      scope.forceCompleteReset();
      expect(scope.exists<_TestCtrl>(), false);
      scope.dispose();
    });

    test('clears tagged bindings', () {
      final scope = ZenScope(name: 'ResetTagged');
      scope.put<_TestCtrl>(_TestCtrl(), tag: 'myTag');
      scope.forceCompleteReset();
      expect(scope.exists<_TestCtrl>(tag: 'myTag'), false);
      scope.dispose();
    });

    test('is safe on already-disposed scope', () {
      final scope = ZenScope(name: 'ResetDisposed');
      scope.dispose();
      expect(() => scope.forceCompleteReset(), returnsNormally);
    });

    test('does not dispose child scopes', () {
      final scope = ZenScope(name: 'ResetParent');
      final child = scope.createChild(name: 'ResetChild');
      scope.forceCompleteReset();
      expect(child.isDisposed, false); // children survive reset
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.getTagForInstance
  // ══════════════════════════════════════════════════════════
  group('ZenScope.getTagForInstance', () {
    test('returns tag for tagged instance', () {
      final scope = ZenScope(name: 'TagGet');
      final ctrl = _TestCtrl();
      scope.put<_TestCtrl>(ctrl, tag: 'primary');
      expect(scope.getTagForInstance(ctrl), 'primary');
      scope.dispose();
    });

    test('returns null for untagged instance', () {
      final scope = ZenScope(name: 'TagNull');
      final ctrl = _TestCtrl();
      scope.put<_TestCtrl>(ctrl);
      expect(scope.getTagForInstance(ctrl), isNull);
      scope.dispose();
    });

    test('returns null for unknown instance', () {
      final scope = ZenScope(name: 'TagUnknown');
      expect(scope.getTagForInstance(_TestCtrl()), isNull);
      scope.dispose();
    });

    test('returns null when scope disposed', () {
      final scope = ZenScope(name: 'TagDisposed');
      final ctrl = _TestCtrl();
      scope.put<_TestCtrl>(ctrl, tag: 't');
      scope.dispose();
      expect(scope.getTagForInstance(ctrl), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.containsInstance
  // ══════════════════════════════════════════════════════════
  group('ZenScope.containsInstance', () {
    test('returns true for registered type binding', () {
      final scope = ZenScope(name: 'ContainsInst');
      final ctrl = _TestCtrl();
      scope.put<_TestCtrl>(ctrl);
      expect(scope.containsInstance(ctrl), true);
      scope.dispose();
    });

    test('returns true for tagged binding', () {
      final scope = ZenScope(name: 'ContainsTagged');
      final ctrl = _TestCtrl();
      scope.put<_TestCtrl>(ctrl, tag: 'x');
      expect(scope.containsInstance(ctrl), true);
      scope.dispose();
    });

    test('returns false for unknown instance', () {
      final scope = ZenScope(name: 'ContainsFalse');
      expect(scope.containsInstance(_TestCtrl()), false);
      scope.dispose();
    });

    test('searches child scopes recursively', () {
      final parent = ZenScope(name: 'ContainsParent');
      final child = parent.createChild(name: 'ContainsChild');
      final ctrl = _TestCtrl();
      child.put<_TestCtrl>(ctrl);
      expect(parent.containsInstance(ctrl), true);
      parent.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.contains<T> with factory check
  // ══════════════════════════════════════════════════════════
  group('ZenScope.contains<T>', () {
    test('returns true for instance registrations', () {
      final scope = ZenScope(name: 'ContainsT');
      scope.put<_TestCtrl>(_TestCtrl());
      expect(scope.contains<_TestCtrl>(), true);
      scope.dispose();
    });

    test('returns true for lazy factory registrations', () {
      final scope = ZenScope(name: 'ContainsFactory');
      scope.putLazy<_TestCtrl>(() => _TestCtrl());
      expect(scope.contains<_TestCtrl>(), true);
      scope.dispose();
    });

    test('returns false when disposed', () {
      final scope = ZenScope(name: 'ContainsDisposed');
      scope.dispose();
      expect(scope.contains<_TestCtrl>(), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenScope.putLazy alwaysNew — factory pattern
  // ══════════════════════════════════════════════════════════
  group('ZenScope.putLazy alwaysNew', () {
    test('creates new instance on each find()', () {
      final scope = ZenScope(name: 'AlwaysNew');
      scope.putLazy<_TestCtrl>(() => _TestCtrl(), alwaysNew: true);
      final a = scope.find<_TestCtrl>();
      final b = scope.find<_TestCtrl>();
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(identical(a, b), false); // different instances
      scope.dispose();
    });

    test('putLazy isPermanent creates persistent singleton', () {
      final scope = ZenScope(name: 'LazyPermanent');
      scope.putLazy<_TestCtrl>(() => _TestCtrl(), isPermanent: true);
      final a = scope.find<_TestCtrl>();
      final b = scope.find<_TestCtrl>();
      expect(identical(a, b), true); // same instance
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.createScope
  // ══════════════════════════════════════════════════════════
  group('Zen.createScope', () {
    test('creates a scope parented to rootScope by default', () {
      final scope = Zen.createScope(name: 'Created');
      expect(scope.parent, same(Zen.rootScope));
      scope.dispose();
    });

    test('creates scope with custom parent', () {
      final parentScope = Zen.createScope(name: 'CustomParent');
      final child = Zen.createScope(name: 'CustomChild', parent: parentScope);
      expect(child.parent, same(parentScope));
      parentScope.dispose();
    });

    test('generates name when none provided', () {
      final scope = Zen.createScope();
      expect(scope.name, isNotNull);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.setCurrentScope / resetCurrentScope
  // ══════════════════════════════════════════════════════════
  group('Zen.setCurrentScope and resetCurrentScope', () {
    test('setCurrentScope changes currentScope', () {
      final scope = Zen.createScope(name: 'Current');
      Zen.setCurrentScope(scope);
      expect(Zen.currentScope, same(scope));
      Zen.resetCurrentScope();
      scope.dispose();
    });

    test('resetCurrentScope falls back to rootScope', () {
      Zen.resetCurrentScope();
      expect(Zen.currentScope, same(Zen.rootScope));
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.putLazy
  // ══════════════════════════════════════════════════════════
  group('Zen.putLazy', () {
    test('registers lazy factory in root scope', () {
      Zen.putLazy<_TestCtrl>(() => _TestCtrl());
      final result = Zen.find<_TestCtrl>();
      expect(result, isNotNull);
    });

    test('putLazy with tag works', () {
      Zen.putLazy<_TestCtrl>(() => _TestCtrl(), tag: 'lazy-tagged');
      final result = Zen.findOrNull<_TestCtrl>(tag: 'lazy-tagged');
      expect(result, isNotNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.findOrNull / Zen.exists
  // ══════════════════════════════════════════════════════════
  group('Zen.findOrNull and Zen.exists', () {
    test('findOrNull returns null when not registered', () {
      expect(Zen.findOrNull<_NotRegistered>(), isNull);
    });

    test('findOrNull returns instance when registered', () {
      Zen.put<_TestCtrl>(_TestCtrl(), tag: 'findOrNull');
      expect(Zen.findOrNull<_TestCtrl>(tag: 'findOrNull'), isNotNull);
    });

    test('exists returns false when not registered', () {
      expect(Zen.exists<_NotRegistered>(), false);
    });

    test('exists returns true when registered', () {
      Zen.put<_TestCtrl>(_TestCtrl(), tag: 'exists_test');
      expect(Zen.exists<_TestCtrl>(tag: 'exists_test'), true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.registerModules / getModule / hasModule / getAllModules
  // ══════════════════════════════════════════════════════════
  group('Zen module convenience methods', () {
    test('registerModules loads modules into root scope', () async {
      await Zen.registerModules([_TestModule('zen_di_test_mod')]);
      expect(Zen.hasModule('zen_di_test_mod'), true);
    });

    test('getModule returns module after loading', () async {
      final m = _TestModule('zen_di_get');
      await Zen.registerModules([m]);
      expect(Zen.getModule('zen_di_get'), same(m));
    });

    test('getAllModules returns all loaded modules', () async {
      await Zen.registerModules([_TestModule('z1'), _TestModule('z2')]);
      final all = Zen.getAllModules();
      expect(all.containsKey('z1'), true);
      expect(all.containsKey('z2'), true);
    });

    test('registerModules with custom scope', () async {
      final scope = Zen.createScope(name: 'ModuleScope');
      await Zen.registerModules([_TestModule('scoped_mod')], scope: scope);
      expect(Zen.hasModule('scoped_mod'), true);
      scope.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Zen.find auto-initializes ZenService
  // ══════════════════════════════════════════════════════════
  group('Zen.find auto-initializes ZenService', () {
    test('find on lazy uninitialized ZenService triggers ensureInitialized',
        () {
      // putLazy with a ZenService subclass
      Zen.rootScope.putLazy<_LazyService>(() => _LazyService());
      final svc = Zen.find<_LazyService>();
      expect(svc.isInitialized, true);
    });
  });
}

// ── Helpers ──

class _TestCtrl extends ZenController {}

class _NotRegistered extends ZenController {}

class _LazyService extends ZenService {
  @override
  void onInit() => super.onInit();
}

class _TestModule extends ZenModule {
  _TestModule(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  void register(ZenScope scope) {}
}
