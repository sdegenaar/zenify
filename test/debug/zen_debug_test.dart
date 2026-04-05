import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for uncovered code paths in debug/zen_debug.dart (L10-76):
/// - allScopes
/// - _collectScopesRecursively (child recursion)
/// - findAllInstancesOfType
/// - findScopeContaining
/// - dumpScopes
/// - dumpModules (L54-72)
/// - generateSystemReport
void main() {
  setUp(Zen.init);
  tearDown(() {
    ZenModuleRegistry.clear();
    Zen.reset();
  });

  group('ZenDebug.allScopes', () {
    test('returns at least the root scope', () {
      expect(ZenDebug.allScopes, isNotEmpty);
    });

    test('includes child scopes in hierarchy', () {
      final child = Zen.rootScope.createChild(name: 'DebugChild');
      final scopes = ZenDebug.allScopes;
      expect(scopes.any((s) => s.name == 'DebugChild'), true);
      child.dispose();
    });

    test('does not include disposed scopes', () {
      final child = Zen.rootScope.createChild(name: 'DeadScope');
      child.dispose();
      final scopes = ZenDebug.allScopes;
      // Disposed child is removed from parent's _childScopes
      expect(scopes.any((s) => s.name == 'DeadScope'), false);
    });
  });

  group('ZenDebug.getHierarchyInfo', () {
    test('returns non-null map', () {
      final info = ZenDebug.getHierarchyInfo();
      expect(info, isNotNull);
      expect(info, isA<Map>());
    });
  });

  group('ZenDebug.getSystemStats', () {
    test('returns non-null map', () {
      final stats = ZenDebug.getSystemStats();
      expect(stats, isNotNull);
      expect(stats, isA<Map>());
    });
  });

  group('ZenDebug.findAllInstancesOfType', () {
    test('finds instances registered in root scope', () {
      Zen.rootScope.put<_DebugCtrl>(_DebugCtrl());
      final found = ZenDebug.findAllInstancesOfType<_DebugCtrl>();
      expect(found, isNotEmpty);
    });

    test('returns empty when type not registered', () {
      final found = ZenDebug.findAllInstancesOfType<_UnregisteredCtrl>();
      expect(found, isEmpty);
    });
  });

  group('ZenDebug.findScopeContaining', () {
    test('returns null when instance not found anywhere', () {
      final orphan = _DebugCtrl();
      final scope = ZenDebug.findScopeContaining(orphan);
      expect(scope, isNull);
    });

    test('returns scope when instance is registered', () {
      final ctrl = _DebugCtrl();
      Zen.rootScope.put<_DebugCtrl>(ctrl);
      final scope = ZenDebug.findScopeContaining(ctrl);
      expect(scope, isNotNull);
    });
  });

  group('ZenDebug.dumpScopes', () {
    test('returns a non-empty string', () {
      final dump = ZenDebug.dumpScopes();
      expect(dump, isA<String>());
      expect(dump, isNotEmpty);
    });

    test('dump contains root scope name', () {
      final dump = ZenDebug.dumpScopes();
      expect(dump.toLowerCase(), anyOf(contains('root'), contains('scope')));
    });
  });

  group('ZenDebug.dumpModules', () {
    test('returns module registry header', () {
      final dump = ZenDebug.dumpModules();
      expect(dump, contains('MODULE REGISTRY'));
    });

    test('shows registered module names', () async {
      await ZenModuleRegistry.registerModules(
        [_NamedModule('analytics'), _NamedModule('payments')],
        Zen.rootScope,
      );
      final dump = ZenDebug.dumpModules();
      expect(dump, contains('analytics'));
      expect(dump, contains('payments'));
    });

    test('shows module dependencies when present', () async {
      final base = _NamedModule('base');
      final feature = _NamedModuleWithDeps('feature2', [base]);
      await ZenModuleRegistry.registerModules([feature], Zen.rootScope);
      final dump = ZenDebug.dumpModules();
      expect(dump, contains('feature2'));
    });

    test('shows Total: 0 when no modules', () {
      final dump = ZenDebug.dumpModules();
      expect(dump, contains('Total: 0'));
    });
  });

  group('ZenDebug.generateSystemReport', () {
    test('returns non-empty string', () {
      final report = ZenDebug.generateSystemReport();
      expect(report, isA<String>());
      expect(report, isNotEmpty);
    });
  });
}

class _DebugCtrl extends ZenController {}

class _UnregisteredCtrl extends ZenController {}

class _NamedModule extends ZenModule {
  _NamedModule(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  void register(ZenScope scope) {}
}

class _NamedModuleWithDeps extends ZenModule {
  _NamedModuleWithDeps(this._name, this._deps);
  final String _name;
  final List<ZenModule> _deps;
  @override
  String get name => _name;
  @override
  List<ZenModule> get dependencies => _deps;
  @override
  void register(ZenScope scope) {}
}
