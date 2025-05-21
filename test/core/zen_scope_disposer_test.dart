// test/core/zen_scope_disposer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('ZenScope Disposer', () {
    // Reset singleton state before each test
    setUp(() {
      // Make sure we have a fresh instance for each test
      Zen.container.clear(); // Explicitly clear container first
      ZenScopeManager.instance.dispose();
      ZenScopeManager.instance.initialize();
    });

    // Clean up after tests
    tearDown(() {
      Zen.container.clear(); // Clean up after test
      ZenScopeManager.instance.dispose();
      ZenScopeManager.instance.initialize();
    });

    test('should execute disposers when scope is disposed', () {
      // Create a scope
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');

      // Keep track of which disposers were called
      final disposerCalls = <String>[];

      // Register several disposers
      scope.registerDisposer(() {
        disposerCalls.add('disposer1');
      });

      scope.registerDisposer(() {
        disposerCalls.add('disposer2');
      });

      // Verify disposers haven't been called yet
      expect(disposerCalls, isEmpty);

      // Dispose the scope
      scope.dispose();

      // Verify both disposers were called
      expect(disposerCalls, containsAll(['disposer1', 'disposer2']));
      expect(disposerCalls.length, equals(2));
    });

    test('should continue executing other disposers if one throws', () {
      // Create a scope
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');

      // Keep track of which disposers were called
      final disposerCalls = <String>[];

      // Register disposers, including one that throws
      scope.registerDisposer(() {
        disposerCalls.add('disposer1');
      });

      scope.registerDisposer(() {
        disposerCalls.add('errorDisposer');
        throw Exception('Test error in disposer');
      });

      scope.registerDisposer(() {
        disposerCalls.add('disposer3');
      });

      // Dispose the scope - this should not throw
      scope.dispose();

      // Verify all disposers were called, including the one after the error
      expect(disposerCalls, containsAll(['disposer1', 'errorDisposer', 'disposer3']));
      expect(disposerCalls.length, equals(3));
    });

    test('should execute parent scope disposers when child scope is disposed', () {
      // Create parent and child scopes
      final parentScope = ZenScopeManager.instance.createScope(name: 'ParentScope');
      final childScope = ZenScopeManager.instance.createScope(
          name: 'ChildScope',
          parent: parentScope
      );

      // Track disposer calls
      final disposerCalls = <String>[];

      // Register disposers in both scopes
      parentScope.registerDisposer(() {
        disposerCalls.add('parentDisposer');
      });

      childScope.registerDisposer(() {
        disposerCalls.add('childDisposer');
      });

      // Dispose only the child scope
      childScope.dispose();

      // Only child disposers should be called
      expect(disposerCalls, contains('childDisposer'));
      expect(disposerCalls, isNot(contains('parentDisposer')));

      // Now dispose the parent
      parentScope.dispose();

      // Now parent disposers should also be called
      expect(disposerCalls, containsAll(['childDisposer', 'parentDisposer']));
    });

    test('should execute all child scope disposers when parent scope is disposed', () {
      // Create parent and child scopes
      final parentScope = ZenScopeManager.instance.createScope(name: 'ParentScope');
      final childScope1 = ZenScopeManager.instance.createScope(
          name: 'ChildScope1',
          parent: parentScope
      );
      final childScope2 = ZenScopeManager.instance.createScope(
          name: 'ChildScope2',
          parent: parentScope
      );

      // Track disposer calls
      final disposerCalls = <String>[];

      // Register disposers in all scopes
      parentScope.registerDisposer(() {
        disposerCalls.add('parentDisposer');
      });

      childScope1.registerDisposer(() {
        disposerCalls.add('child1Disposer');
      });

      childScope2.registerDisposer(() {
        disposerCalls.add('child2Disposer');
      });

      // Dispose the parent scope
      parentScope.dispose();

      // All disposers should be called
      expect(disposerCalls, containsAll(['parentDisposer', 'child1Disposer', 'child2Disposer']));

      // Child scopes should be marked as disposed
      expect(childScope1.isDisposed, isTrue);
      expect(childScope2.isDisposed, isTrue);
    });

    test('should clear disposers after execution', () {
      // Create a scope
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');

      // Track disposer calls
      final disposerCalls = <String>[];

      // Register a disposer
      scope.registerDisposer(() {
        disposerCalls.add('disposer1');
      });

      // Dispose the scope
      scope.dispose();

      // Verify disposer was called
      expect(disposerCalls, contains('disposer1'));

      // Reset tracking
      disposerCalls.clear();

      // Try to dispose again (this won't throw because the dispose method is idempotent)
      scope.dispose();

      // Disposer should not be called again
      expect(disposerCalls, isEmpty);
    });

    test('should throw when registering disposers on disposed scope', () {
      // Create a scope
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');

      // Dispose the scope
      scope.dispose();

      // Try to register a disposer on a disposed scope
      expect(() => scope.registerDisposer(() {}), throwsException);
    });

    test('should support ZenScopeManager convenience methods', () {
      // Create scopes
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');
      final manager = ZenScopeManager.instance;

      // Set current scope
      manager.currentScope = scope;

      // Track disposer calls
      final disposerCalls = <String>[];

      // Use convenience methods
      manager.registerDisposer(() {
        disposerCalls.add('currentScopeDisposer');
      });

      manager.registerGlobalDisposer(() {
        disposerCalls.add('globalDisposer');
      });

      manager.registerDisposerIn(
        scope: manager.rootScope,
        disposer: () {
          disposerCalls.add('rootScopeDisposer');
        },
      );

      // Dispose the current scope
      scope.dispose();

      // Verify current scope disposer was called
      expect(disposerCalls, contains('currentScopeDisposer'));
      expect(disposerCalls, isNot(contains('globalDisposer')));
      expect(disposerCalls, isNot(contains('rootScopeDisposer')));

      // Dispose everything
      manager.dispose();

      // Verify all disposers were called
      expect(disposerCalls, containsAll(['currentScopeDisposer', 'globalDisposer', 'rootScopeDisposer']));
    });

    test('should execute resource cleanup in disposer', () {
      // Create a scope
      final scope = ZenScopeManager.instance.createScope(name: 'TestScope');

      // Create a mock resource
      final mockResource = MockResource();

      // Register the resource and its cleanup
      scope.registerDisposer(() {
        mockResource.close();
      });

      // Verify resource is not closed yet
      expect(mockResource.isClosed, isFalse);

      // Dispose the scope
      scope.dispose();

      // Verify resource was closed
      expect(mockResource.isClosed, isTrue);
    });
  });
}

// Mock resource class for testing cleanup
class MockResource {
  bool _isClosed = false;

  bool get isClosed => _isClosed;

  void close() {
    _isClosed = true;
  }
}