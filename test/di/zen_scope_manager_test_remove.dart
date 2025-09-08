// // test/di/zen_scope_manager_test.dart
// import 'package:flutter_test/flutter_test.dart';
// import 'package:zenify/zenify.dart';
//
// void main() {
//   // Initialize Flutter test framework BEFORE any tests run
//   setUpAll(() {
//     TestWidgetsFlutterBinding.ensureInitialized();
//   });
//
//   group('ZenScopeManager', () {
//     setUp(() {
//       // Reset manager state before each test
//       try {
//         ZenScopeManager.instance.dispose();
//       } catch (e) {
//         // Ignore disposal errors
//       }
//       ZenScopeManager.instance.initialize();
//     });
//
//     tearDown(() {
//       try {
//         ZenScopeManager.instance.dispose();
//       } catch (e) {
//         // Ignore disposal errors
//       }
//     });
//
//     test('should provide singleton instance', () {
//       final instance1 = ZenScopeManager.instance;
//       final instance2 = ZenScopeManager.instance;
//
//       expect(instance1, isNotNull);
//       expect(identical(instance1, instance2), isTrue);
//     });
//
//     test('should initialize with root scope', () {
//       final manager = ZenScopeManager.instance;
//
//       expect(manager.rootScope, isNotNull);
//       expect(manager.rootScope.name, equals('RootScope'));
//       expect(manager.rootScope.isDisposed, isFalse);
//     });
//
//     test('should create scopes with proper hierarchy', () {
//       final manager = ZenScopeManager.instance;
//
//       // Create child scope of root
//       final childScope = manager.createScope(name: 'ChildScope');
//
//       expect(childScope, isNotNull);
//       expect(childScope.name, equals('ChildScope'));
//       expect(childScope.parent, equals(manager.rootScope));
//       expect(childScope.isDisposed, isFalse);
//
//       // Create grandchild scope
//       final grandchildScope = manager.createScope(
//         name: 'GrandchildScope',
//         parent: childScope,
//       );
//
//       expect(grandchildScope.parent, equals(childScope));
//       expect(grandchildScope.name, equals('GrandchildScope'));
//     });
//
//     test('should find scopes by ID', () {
//       final manager = ZenScopeManager.instance;
//
//       final scope1 = manager.createScope(name: 'Scope1');
//       final scope2 = manager.createScope(name: 'Scope2');
//
//       // Find by ID
//       expect(manager.findScopeById(scope1.id), equals(scope1));
//       expect(manager.findScopeById(scope2.id), equals(scope2));
//       expect(manager.findScopeById('nonexistent'), isNull);
//     });
//
//     test('should find scopes by name', () {
//       final manager = ZenScopeManager.instance;
//
//       final scope1 = manager.createScope(name: 'TestScope');
//       final scope2 = manager.createScope(name: 'TestScope'); // Same name
//       final scope3 = manager.createScope(name: 'OtherScope');
//
//       // Find by name
//       final testScopes = manager.findScopesByName('TestScope');
//       expect(testScopes.length, equals(2));
//       expect(testScopes.contains(scope1), isTrue);
//       expect(testScopes.contains(scope2), isTrue);
//
//       final otherScopes = manager.findScopesByName('OtherScope');
//       expect(otherScopes.length, equals(1));
//       expect(otherScopes.first, equals(scope3));
//
//       // Non-existent name
//       expect(manager.findScopesByName('NonExistent'), isEmpty);
//     });
//
//     test('should get all scopes', () {
//       final manager = ZenScopeManager.instance;
//
//       // Initially should have just root scope
//       final initialScopes = manager.getAllScopes();
//       expect(initialScopes.length, equals(1));
//       expect(initialScopes.first, equals(manager.rootScope));
//
//       // Create additional scopes
//       final scope1 = manager.createScope(name: 'Scope1');
//       final scope2 = manager.createScope(name: 'Scope2');
//
//       final allScopes = manager.getAllScopes();
//       expect(allScopes.length, equals(3));
//       expect(allScopes.contains(manager.rootScope), isTrue);
//       expect(allScopes.contains(scope1), isTrue);
//       expect(allScopes.contains(scope2), isTrue);
//     });
//
//     test('should clean up disposed scopes from maps', () {
//       final manager = ZenScopeManager.instance;
//
//       final scope = manager.createScope(name: 'DisposableScope');
//       final scopeId = scope.id;
//
//       // Verify scope exists in manager
//       expect(manager.findScopeById(scopeId), equals(scope));
//       expect(manager.findScopesByName('DisposableScope'), contains(scope));
//       expect(manager.getAllScopes(), contains(scope));
//
//       // Dispose the scope
//       scope.dispose();
//
//       // Verify scope is removed from manager maps
//       expect(manager.findScopeById(scopeId), isNull);
//       expect(manager.findScopesByName('DisposableScope'), isEmpty);
//       expect(manager.getAllScopes(), isNot(contains(scope)));
//     });
//
//     test('should support scopes without names', () {
//       final manager = ZenScopeManager.instance;
//
//       final unnamedScope = manager.createScope();
//
//       expect(unnamedScope, isNotNull);
//       expect(unnamedScope.name, isNull);
//       expect(unnamedScope.parent, equals(manager.rootScope));
//
//       // Should be findable by ID but not by name
//       expect(manager.findScopeById(unnamedScope.id), equals(unnamedScope));
//       expect(manager.findScopesByName(''), isEmpty);
//
//       // Should be in getAllScopes
//       expect(manager.getAllScopes(), contains(unnamedScope));
//     });
//
//     test('should generate scope hierarchy dump', () {
//       final manager = ZenScopeManager.instance;
//
//       // Create hierarchy
//       final parentScope = manager.createScope(name: 'Parent');
//       final childScope = manager.createScope(name: 'Child', parent: parentScope);
//       manager.createScope(name: 'Grandchild', parent: childScope);
//
//       final dump = manager.dumpScopeHierarchy();
//
//       expect(dump, isNotNull);
//       expect(dump, contains('RootScope'));
//       expect(dump, contains('Parent'));
//       expect(dump, contains('Child'));
//       expect(dump, contains('Grandchild'));
//     });
//
//     test('should handle deleteAll across all scopes', () {
//       final manager = ZenScopeManager.instance;
//
//       // Create scopes and register some dependencies
//       final scope1 = manager.createScope(name: 'Scope1');
//       final scope2 = manager.createScope(name: 'Scope2');
//
//       // Register some test dependencies
//       manager.rootScope.put('rootDep');
//       scope1.put('scope1Dep');
//       scope2.put('scope2Dep');
//
//       // Verify dependencies exist
//       expect(manager.rootScope.find<String>(), equals('rootDep'));
//       expect(scope1.find<String>(), equals('scope1Dep'));
//       expect(scope2.find<String>(), equals('scope2Dep'));
//
//       // Delete all dependencies
//       manager.deleteAll(force: true);
//
//       // Verify all dependencies are gone
//       expect(manager.rootScope.find<String>(), isNull);
//       expect(scope1.find<String>(), isNull);
//       expect(scope2.find<String>(), isNull);
//     });
//
//     test('should dispose all scopes when manager is disposed', () {
//       final manager = ZenScopeManager.instance;
//
//       final scope1 = manager.createScope(name: 'Scope1');
//       final scope2 = manager.createScope(name: 'Scope2');
//
//       expect(manager.rootScope.isDisposed, isFalse);
//       expect(scope1.isDisposed, isFalse);
//       expect(scope2.isDisposed, isFalse);
//
//       // Dispose manager
//       manager.dispose();
//
//       // All scopes should be disposed
//       expect(manager.rootScope.isDisposed, isTrue);
//
//       // Maps should be cleared
//       expect(manager.getAllScopes(), isEmpty);
//       expect(manager.findScopeById(scope1.id), isNull);
//       expect(manager.findScopeById(scope2.id), isNull);
//     });
//
//     test('should reinitialize cleanly after disposal', () {
//       final manager = ZenScopeManager.instance;
//
//       // Create some scopes
//       final scope1 = manager.createScope(name: 'Scope1');
//       scope1.put('testDependency');
//
//       // Dispose
//       manager.dispose();
//
//       // Reinitialize
//       manager.initialize();
//
//       // Should have fresh root scope
//       expect(manager.rootScope, isNotNull);
//       expect(manager.rootScope.name, equals('RootScope'));
//       expect(manager.rootScope.isDisposed, isFalse);
//       expect(manager.rootScope.find<String>(), isNull);
//
//       // Old scope references should be disposed
//       expect(scope1.isDisposed, isTrue);
//
//       // Maps should be clean except for new root
//       expect(manager.getAllScopes().length, equals(1));
//       expect(manager.getAllScopes().first, equals(manager.rootScope));
//     });
//
//     test('should handle multiple scopes with same name correctly', () {
//       final manager = ZenScopeManager.instance;
//
//       final scope1 = manager.createScope(name: 'SameName');
//       final scope2 = manager.createScope(name: 'SameName');
//       final scope3 = manager.createScope(name: 'SameName');
//
//       final sameNameScopes = manager.findScopesByName('SameName');
//       expect(sameNameScopes.length, equals(3));
//       expect(sameNameScopes.contains(scope1), isTrue);
//       expect(sameNameScopes.contains(scope2), isTrue);
//       expect(sameNameScopes.contains(scope3), isTrue);
//
//       // Dispose one scope
//       scope2.dispose();
//
//       // Should now only find 2
//       final remainingScopes = manager.findScopesByName('SameName');
//       expect(remainingScopes.length, equals(2));
//       expect(remainingScopes.contains(scope1), isTrue);
//       expect(remainingScopes.contains(scope2), isFalse);
//       expect(remainingScopes.contains(scope3), isTrue);
//     });
//   });
// }
