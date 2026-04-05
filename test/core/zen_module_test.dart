import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenModuleRegistry targeting uncovered lines in core/zen_module.dart:
/// - L22-30: ZenModule equality and hashCode and toString
/// - L45: empty modules list early return
/// - L56-60: missing dependency detection
/// - L73-75: already-loaded module skip
/// - L149-151: circular dependency detection
void main() {
  setUp(() {
    ZenModuleRegistry.clear();
    Zen.init();
  });

  tearDown(() {
    ZenModuleRegistry.clear();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // ZenModule equality and hashing
  // ══════════════════════════════════════════════════════════
  group('ZenModule equality', () {
    test('two modules with same name are equal', () {
      final a = _SimpleModule('auth');
      final b = _SimpleModule('auth');
      expect(a, equals(b));
    });

    test('two modules with different names are not equal', () {
      final a = _SimpleModule('auth');
      final b = _SimpleModule('logging');
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal modules', () {
      final a = _SimpleModule('auth');
      final b = _SimpleModule('auth');
      expect(a.hashCode, b.hashCode);
    });

    test('toString includes module name', () {
      final m = _SimpleModule('analytics');
      expect(m.toString(), contains('analytics'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerModules - empty list
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry.registerModules — empty list', () {
    test('empty list returns without error', () async {
      await expectLater(
        ZenModuleRegistry.registerModules([], Zen.rootScope),
        completes,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerModules - transitive dependency resolution
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry.registerModules — transitive dependency resolution',
      () {
    test('dep declared on module is auto-resolved transiently', () async {
      // 'base' is only declared as a dependency of 'feature'
      // — not explicitly passed to registerModules.
      // _collectAllDependencies resolves it automatically.
      final order = <String>[];
      final base = _OrderedModule('baseAuto', [], order);
      final feature = _OrderedModule('featureAuto', [base], order);

      // Pass ONLY feature; base will be auto-resolved
      await ZenModuleRegistry.registerModules([feature], Zen.rootScope);

      expect(order, containsAll(['baseAuto', 'featureAuto']));
      expect(order.indexOf('baseAuto'), lessThan(order.indexOf('featureAuto')));
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerModules - circular dependency
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry.registerModules — circular dependency', () {
    test('throws StateError on circular dependency chain', () async {
      // Create a cycle: A → B → A
      final modA = _CircularModule('modA');
      final modB = _CircularModule('modB');
      modA.addDep(modB);
      modB.addDep(modA);

      await expectLater(
        ZenModuleRegistry.registerModules([modA, modB], Zen.rootScope),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Circular dependency'),
        )),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerModules - already loaded skip
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry.registerModules — already loaded skip', () {
    test('registering same module twice does not re-register', () async {
      final m = _CountingModule('counted');

      await ZenModuleRegistry.registerModules([m], Zen.rootScope);
      expect(m.registerCallCount, 1);

      // Register again — should be skipped (line 73-75)
      await ZenModuleRegistry.registerModules([m], Zen.rootScope);
      expect(m.registerCallCount, 1); // still 1
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerModules - with dependency (load order)
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry.registerModules — dependency order', () {
    test('dependencies are loaded before dependents', () async {
      final order = <String>[];
      final base = _OrderedModule('base', [], order);
      final feature = _OrderedModule('feature', [base], order);

      await ZenModuleRegistry.registerModules([feature], Zen.rootScope);
      // Base must come before feature
      expect(order.indexOf('base'), lessThan(order.indexOf('feature')));
    });
  });

  // ══════════════════════════════════════════════════════════
  // hasModule / getModule / getAllModules / clear
  // ══════════════════════════════════════════════════════════
  group('ZenModuleRegistry inspection', () {
    test('hasModule returns true after registration', () async {
      await ZenModuleRegistry.registerModules(
        [_SimpleModule('inspect')],
        Zen.rootScope,
      );
      expect(ZenModuleRegistry.hasModule('inspect'), true);
    });

    test('hasModule returns false for unknown module', () {
      expect(ZenModuleRegistry.hasModule('phantom'), false);
    });

    test('getModule returns correct module', () async {
      final m = _SimpleModule('fetch');
      await ZenModuleRegistry.registerModules([m], Zen.rootScope);
      expect(ZenModuleRegistry.getModule('fetch'), same(m));
    });

    test('getAllModules returns all registered modules', () async {
      await ZenModuleRegistry.registerModules(
        [_SimpleModule('a'), _SimpleModule('b')],
        Zen.rootScope,
      );
      final all = ZenModuleRegistry.getAllModules();
      expect(all.containsKey('a'), true);
      expect(all.containsKey('b'), true);
    });

    test('clear removes all modules', () async {
      await ZenModuleRegistry.registerModules(
        [_SimpleModule('temp')],
        Zen.rootScope,
      );
      expect(ZenModuleRegistry.hasModule('temp'), true);
      ZenModuleRegistry.clear();
      expect(ZenModuleRegistry.hasModule('temp'), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenModule.onInit / onDispose async hooks
  // ══════════════════════════════════════════════════════════
  group('ZenModule async hooks', () {
    test('onInit is called after register', () async {
      final m = _HookModule('hooks');
      await ZenModuleRegistry.registerModules([m], Zen.rootScope);
      expect(m.onInitCalled, true);
    });
  });
}

// ── Module helpers ──

class _SimpleModule extends ZenModule {
  _SimpleModule(this._name);
  final String _name;

  @override
  String get name => _name;

  @override
  void register(ZenScope scope) {}
}

class _CircularModule extends ZenModule {
  _CircularModule(this._name);
  final String _name;
  final List<ZenModule> _deps = [];

  void addDep(ZenModule m) => _deps.add(m);

  @override
  String get name => _name;

  @override
  List<ZenModule> get dependencies => _deps;

  @override
  void register(ZenScope scope) {}
}

class _CountingModule extends ZenModule {
  _CountingModule(this._name);
  final String _name;
  int registerCallCount = 0;

  @override
  String get name => _name;

  @override
  void register(ZenScope scope) => registerCallCount++;
}

class _OrderedModule extends ZenModule {
  _OrderedModule(this._name, this._deps, this._order);
  final String _name;
  final List<ZenModule> _deps;
  final List<String> _order;

  @override
  String get name => _name;

  @override
  List<ZenModule> get dependencies => _deps;

  @override
  void register(ZenScope scope) => _order.add(_name);
}

class _HookModule extends ZenModule {
  _HookModule(this._name);
  final String _name;
  bool onInitCalled = false;

  @override
  String get name => _name;

  @override
  void register(ZenScope scope) {}

  @override
  Future<void> onInit(ZenScope scope) async {
    onInitCalled = true;
  }
}
