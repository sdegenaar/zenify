import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  late ZenScope scope;

  setUp(() {
    Zen.init();
    scope = Zen.createScope(name: 'TestScope');
  });
  tearDown(() {
    if (!scope.isDisposed) scope.dispose();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // getAllInstances
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.getAllInstances', () {
    test('returns empty map on empty scope', () {
      expect(ZenScopeInspector.getAllInstances(scope), isEmpty);
    });

    test('returns instances after registration', () {
      scope.put<_MyService>(_MyService());
      final instances = ZenScopeInspector.getAllInstances(scope);
      expect(instances.containsKey(_MyService), true);
    });

    test('returns empty map on disposed scope', () {
      scope.put<_MyService>(_MyService());
      scope.dispose();
      expect(ZenScopeInspector.getAllInstances(scope), isEmpty);
    });

    test('returned map is unmodifiable', () {
      scope.put<_MyService>(_MyService());
      final instances = ZenScopeInspector.getAllInstances(scope);
      expect(
        () => (instances as dynamic)[Object] = 'fail',
        throwsUnsupportedError,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // getRegisteredTypes
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.getRegisteredTypes', () {
    test('returns empty list on empty scope', () {
      expect(ZenScopeInspector.getRegisteredTypes(scope), isEmpty);
    });

    test('includes registered type', () {
      scope.put<_MyService>(_MyService());
      final types = ZenScopeInspector.getRegisteredTypes(scope);
      expect(types, contains(_MyService));
    });

    test('returns empty list on disposed scope', () {
      scope.put<_MyService>(_MyService());
      scope.dispose();
      expect(ZenScopeInspector.getRegisteredTypes(scope), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════
  // toDebugMap
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.toDebugMap', () {
    test('includes scopeInfo section', () {
      final map = ZenScopeInspector.toDebugMap(scope);
      expect(map.containsKey('scopeInfo'), true);
      final info = map['scopeInfo'] as Map;
      expect(info['name'], 'TestScope');
      expect(info['disposed'], false);
    });

    test('includes dependencies section', () {
      scope.put<_MyService>(_MyService());
      final map = ZenScopeInspector.toDebugMap(scope);
      final deps = map['dependencies'] as Map;
      expect(deps['totalDependencies'], 1);
    });

    test('includes registeredTypes list', () {
      scope.put<_MyService>(_MyService());
      final map = ZenScopeInspector.toDebugMap(scope);
      final types = map['registeredTypes'] as List;
      expect(types, isNotEmpty);
    });

    test('includes children list', () {
      final child = Zen.createScope(name: 'Child', parent: scope);
      final map = ZenScopeInspector.toDebugMap(scope);
      final children = map['children'] as List;
      expect(children.length, 1);
      expect((children[0] as Map)['name'], 'Child');
      child.dispose();
    });

    test('parent info present', () {
      final child = Zen.createScope(name: 'Child', parent: scope);
      final map = ZenScopeInspector.toDebugMap(child);
      expect((map['scopeInfo'] as Map)['hasParent'], true);
      expect((map['scopeInfo'] as Map)['parentName'], 'TestScope');
      child.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // getDependencyBreakdown
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.getDependencyBreakdown', () {
    test('returns error map on disposed scope', () {
      scope.dispose();
      final result = ZenScopeInspector.getDependencyBreakdown(scope);
      expect(result.containsKey('error'), true);
    });

    test('categorizes controllers correctly', () {
      scope.put<_MyCtrl>(_MyCtrl());
      final bd = ZenScopeInspector.getDependencyBreakdown(scope);
      final controllers = bd['controllers'] as List;
      expect(controllers, isNotEmpty);
      expect((bd['summary'] as Map)['totalControllers'], greaterThan(0));
    });

    test('categorizes services by name pattern', () {
      scope.put<_MyServiceClass>(_MyServiceClass());
      final bd = ZenScopeInspector.getDependencyBreakdown(scope);
      final services = bd['services'] as List;
      // Only categorized if typeName contains 'service' (case-insensitive)
      // _MyServiceClass contains 'Service' so it should be categorized
      expect(
          services.any((s) => s.toString().toLowerCase().contains('service')),
          true);
    });

    test('categorizes others correctly', () {
      scope.put<_Plain>(_Plain());
      final bd = ZenScopeInspector.getDependencyBreakdown(scope);
      final others = bd['others'] as List;
      expect(others, isNotEmpty);
    });

    test('summary grand total is sum of all categories', () {
      scope.put<_MyCtrl>(_MyCtrl());
      scope.put<_Plain>(_Plain());
      final bd = ZenScopeInspector.getDependencyBreakdown(scope);
      final summary = bd['summary'] as Map;
      final grand = summary['grandTotal'] as int;
      final sum = (summary['totalControllers'] as int) +
          (summary['totalServices'] as int) +
          (summary['totalOthers'] as int);
      expect(grand, sum);
    });
  });

  // ══════════════════════════════════════════════════════════
  // getScopePath
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.getScopePath', () {
    test('single scope path contains scope name', () {
      final path = ZenScopeInspector.getScopePath(scope);
      expect(path, contains('TestScope'));
    });

    test('nested scope path includes parent name', () {
      final child = Zen.createScope(name: 'Child', parent: scope);
      final path = ZenScopeInspector.getScopePath(child);
      expect(path, containsAll(['TestScope', 'Child']));
      // Parent comes before child in path
      final parentIdx = path.indexOf('TestScope');
      final childIdx = path.indexOf('Child');
      expect(parentIdx, lessThan(childIdx));
      child.dispose();
    });

    test('path root-to-leaf order', () {
      final child = Zen.createScope(name: 'Leaf', parent: scope);
      final path = ZenScopeInspector.getScopePath(child);
      expect(path.last, 'Leaf');
      child.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // dumpScope
  // ══════════════════════════════════════════════════════════
  group('ZenScopeInspector.dumpScope', () {
    test('writes scope name in output', () {
      final buf = StringBuffer();
      ZenScopeInspector.dumpScope(scope, buf, 0);
      expect(buf.toString(), contains('TestScope'));
    });

    test('writes dependency count', () {
      scope.put<_MyService>(_MyService());
      final buf = StringBuffer();
      ZenScopeInspector.dumpScope(scope, buf, 0);
      expect(buf.toString(), contains('Dependencies: 1'));
    });

    test('recursively dumps child scopes', () {
      final child = Zen.createScope(name: 'ChildDump', parent: scope);
      final buf = StringBuffer();
      ZenScopeInspector.dumpScope(scope, buf, 0);
      expect(buf.toString(), contains('ChildDump'));
      child.dispose();
    });

    test('indentation increases with depth', () {
      final child = Zen.createScope(name: 'Indented', parent: scope);
      final buf = StringBuffer();
      ZenScopeInspector.dumpScope(scope, buf, 0);
      final output = buf.toString();
      // Child line should have more leading spaces
      final childLine = output.split('\n').firstWhere(
            (l) => l.contains('Indented'),
            orElse: () => '',
          );
      expect(childLine.startsWith('  '), true);
      child.dispose();
    });

    test('writes types when dependencies exist', () {
      scope.put<_MyService>(_MyService());
      final buf = StringBuffer();
      ZenScopeInspector.dumpScope(scope, buf, 0);
      expect(buf.toString(), contains('Types:'));
    });
  });
}

class _MyService {}

class _MyServiceClass {}

class _Plain {}

class _MyCtrl extends ZenController {}
