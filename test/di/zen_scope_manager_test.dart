// test/di/zen_scope_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test service class
class TestService {
  final String value;
  TestService(this.value);
}

// Stateful service for testing factories
class CounterService {
  int count = 0;

  void increment() {
    count++;
  }
}

void main() {
  group('ZenScopeManager', () {
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

    test('should access the singleton instance', () {
      // Verify we can access the instance
      expect(ZenScopeManager.instance, isNotNull);

      // The instance should be the same each time
      final firstAccess = ZenScopeManager.instance;
      final secondAccess = ZenScopeManager.instance;
      expect(identical(firstAccess, secondAccess), isTrue);
    });

    test('should initialize with root scope', () {
      // The instance should have a root scope
      expect(ZenScopeManager.instance.rootScope, isNotNull);
      expect(ZenScopeManager.instance.rootScope.name, equals('RootScope'));

      // Current scope should default to root scope
      expect(identical(ZenScopeManager.instance.currentScope,
          ZenScopeManager.instance.rootScope), isTrue);
    });

    test('should create scopes with proper parent relationships', () {
      final manager = ZenScopeManager.instance;

      // Create a child scope
      final childScope = manager.createScope(name: 'ChildScope');

      // Verify parent relationship
      expect(identical(childScope.parent, manager.rootScope), isTrue);

      // Create a grandchild scope
      final grandchildScope = manager.createScope(
          parent: childScope,
          name: 'GrandchildScope'
      );

      // Verify parent relationship
      expect(identical(grandchildScope.parent, childScope), isTrue);
    });

    test('should manage the current scope', () {
      final manager = ZenScopeManager.instance;

      // Create a new scope
      final childScope = manager.createScope(name: 'CurrentScope');

      // Initially current scope is root
      expect(identical(manager.currentScope, manager.rootScope), isTrue);

      // Change current scope
      manager.setCurrentScope(childScope);
      expect(identical(manager.currentScope, childScope), isTrue);

      // Create a session that will restore the previous scope when ended
      final otherScope = manager.createScope(name: 'OtherScope');
      final session = manager.beginSession(otherScope);

      // Session should set current scope
      expect(identical(manager.currentScope, otherScope), isTrue);

      // End session should restore previous scope
      session.end();
      expect(identical(manager.currentScope, childScope), isTrue);
    });

    test('should register dependencies in the current scope', () {
      final manager = ZenScopeManager.instance;

      // Create a child scope and set as current
      final childScope = manager.createScope(name: 'CurrentScope');
      manager.setCurrentScope(childScope);

      // Register in current scope
      final service = TestService('testValue');
      manager.put<TestService>(service);

      // Should be found in current scope
      expect(manager.find<TestService>()?.value, equals('testValue'));

      // Switch back to root scope
      manager.setCurrentScope(manager.rootScope);

      // Should not be found in root scope
      expect(manager.find<TestService>(), isNull);

      // But should be found when explicitly using child scope
      expect(manager.findIn<TestService>(scope: childScope)?.value, equals('testValue'));
    });

    test('should properly handle lazy dependency initialization', () {
      final manager = ZenScopeManager.instance;
      int initializationCount = 0;

      // Register a lazily initialized dependency
      manager.lazily<TestService>(() {
        initializationCount++;
        return TestService('lazy-initialized');
      });

      // Verify factory is registered but not called yet
      expect(initializationCount, equals(0));

      // First access should initialize the dependency
      final instance1 = manager.find<TestService>();
      expect(instance1, isNotNull);
      expect(instance1?.value, equals('lazy-initialized'));
      expect(initializationCount, equals(1));

      // Second access should return the same instance without re-initialization
      final instance2 = manager.find<TestService>();
      expect(identical(instance2, instance1), isTrue);
      expect(initializationCount, equals(1)); // Still 1, not re-initialized

      // Test lazy global dependency
      manager.lazilyGlobal<TestService>(() {
        initializationCount++;
        return TestService('global-lazy');
      }, tag: 'global');

      // Verify factory is registered but not called
      expect(initializationCount, equals(1));

      // Access the global dependency
      final globalInstance = manager.findGlobal<TestService>(tag: 'global');
      expect(globalInstance?.value, equals('global-lazy'));
      expect(initializationCount, equals(2));

      // Test lazy dependency in a specific scope
      final childScope = manager.createScope(name: 'LazyChild');
      manager.lazilyIn<TestService>(
              () {
            initializationCount++;
            return TestService('scope-specific');
          },
          scope: childScope,
          tag: 'scoped'
      );

      // Verify factory is registered but not called
      expect(initializationCount, equals(2));

      // Access the scoped dependency
      final scopedInstance = manager.findIn<TestService>(
          scope: childScope,
          tag: 'scoped'
      );
      expect(scopedInstance?.value, equals('scope-specific'));
      expect(initializationCount, equals(3));
    });

    test('should properly handle factory registration with putFactory', () {
      final manager = ZenScopeManager.instance;
      int factoryCallCount = 0;

      // Register a factory that creates new instances each time
      manager.putFactory<TestService>(() {
        factoryCallCount++;
        return TestService('factory-instance-$factoryCallCount');
      });

      // Verify the factory hasn't been called yet
      expect(factoryCallCount, equals(0));

      // First access should call the factory
      final instance1 = manager.find<TestService>();
      expect(instance1, isNotNull);
      expect(instance1?.value, equals('factory-instance-1'));
      expect(factoryCallCount, equals(1));

      // Second access should call the factory again and create a new instance
      final instance2 = manager.find<TestService>();
      expect(instance2, isNotNull);
      expect(instance2?.value, equals('factory-instance-2'));
      expect(factoryCallCount, equals(2));

      // Instances should be different
      expect(identical(instance1, instance2), isFalse);

      // Test with a stateful service to confirm instances are separate
      manager.putFactory<CounterService>(() => CounterService());

      final counterInstance1 = manager.find<CounterService>();
      final counterInstance2 = manager.find<CounterService>();

      expect(counterInstance1, isNotNull);
      expect(counterInstance2, isNotNull);
      expect(identical(counterInstance1, counterInstance2), isFalse);

      // Modify one instance
      counterInstance1?.increment();
      expect(counterInstance1?.count, equals(1));

      // The other instance should not be affected
      expect(counterInstance2?.count, equals(0));
    });

    test('should support global and scoped factories', () {
      final manager = ZenScopeManager.instance;
      int rootFactoryCount = 0;
      int childFactoryCount = 0;

      // Register a factory in root scope
      manager.putFactoryGlobal<TestService>(() {
        rootFactoryCount++;
        return TestService('root-factory-$rootFactoryCount');
      });

      // Create a child scope
      final childScope = manager.createScope(name: 'ChildScope');

      // Register a factory in child scope
      manager.putFactoryIn<TestService>(
              () {
            childFactoryCount++;
            return TestService('child-factory-$childFactoryCount');
          },
          scope: childScope,
          tag: 'child'
      );

      // Test the root factory
      final rootInstance1 = manager.findGlobal<TestService>();
      final rootInstance2 = manager.findGlobal<TestService>();

      expect(rootInstance1?.value, equals('root-factory-1'));
      expect(rootInstance2?.value, equals('root-factory-2'));
      expect(rootFactoryCount, equals(2));
      expect(identical(rootInstance1, rootInstance2), isFalse);

      // Test the child scope factory
      final childInstance1 = manager.findIn<TestService>(scope: childScope, tag: 'child');
      final childInstance2 = manager.findIn<TestService>(scope: childScope, tag: 'child');

      expect(childInstance1?.value, equals('child-factory-1'));
      expect(childInstance2?.value, equals('child-factory-2'));
      expect(childFactoryCount, equals(2));
      expect(identical(childInstance1, childInstance2), isFalse);
    });

    test('should support mixing lazy singletons and factories', () {
      final manager = ZenScopeManager.instance;
      int singletonCount = 0;
      int factoryCount = 0;

      // Register a lazy singleton
      manager.lazily<TestService>(() {
        singletonCount++;
        return TestService('singleton-$singletonCount');
      }, tag: 'singleton');

      // Register a factory
      manager.putFactory<TestService>(() {
        factoryCount++;
        return TestService('factory-$factoryCount');
      }, tag: 'factory');

      // Test the singleton behavior
      final singleton1 = manager.find<TestService>(tag: 'singleton');
      final singleton2 = manager.find<TestService>(tag: 'singleton');

      expect(singleton1?.value, equals('singleton-1'));
      expect(singleton2?.value, equals('singleton-1'));  // Same value
      expect(singletonCount, equals(1));  // Only created once
      expect(identical(singleton1, singleton2), isTrue);  // Same instance

      // Test the factory behavior
      final factory1 = manager.find<TestService>(tag: 'factory');
      final factory2 = manager.find<TestService>(tag: 'factory');

      expect(factory1?.value, equals('factory-1'));
      expect(factory2?.value, equals('factory-2'));  // Different value
      expect(factoryCount, equals(2));  // Created twice
      expect(identical(factory1, factory2), isFalse);  // Different instances
    });

    test('should handle factory disposal correctly', () {
      final manager = ZenScopeManager.instance;
      int factoryCallCount = 0;

      // Create a child scope
      final childScope = manager.createScope(name: 'FactoryScope');

      // Register a factory in the child scope
      manager.putFactoryIn<TestService>(
              () {
            factoryCallCount++;
            return TestService('factory-$factoryCallCount');
          },
          scope: childScope
      );

      // Test the factory works before disposal
      final instance1 = manager.findIn<TestService>(scope: childScope);
      expect(instance1?.value, equals('factory-1'));

      // Dispose the child scope
      childScope.dispose();

      // Factory should no longer be available
      final instance2 = manager.findIn<TestService>(scope: childScope);
      expect(instance2, isNull);

      // Create a new scope with the same name
      final newScope = manager.createScope(name: 'FactoryScope');

      // Factory should not exist in the new scope
      final instance3 = manager.findIn<TestService>(scope: newScope);
      expect(instance3, isNull);
    });

    test('should cleanup properly when disposed', () {
      final manager = ZenScopeManager.instance;

      // Create child scopes
      final childScope1 = manager.createScope(name: 'Child1');
      final childScope2 = manager.createScope(name: 'Child2');

      // Register services in different scopes
      manager.putGlobal<TestService>(TestService('root'));
      manager.putIn<TestService>(TestService('child1'), scope: childScope1, tag: 'child1');
      manager.putIn<TestService>(TestService('child2'), scope: childScope2, tag: 'child2');

      // Verify services exist
      expect(manager.findGlobal<TestService>()?.value, equals('root'));
      expect(manager.findIn<TestService>(scope: childScope1, tag: 'child1')?.value, equals('child1'));
      expect(manager.findIn<TestService>(scope: childScope2, tag: 'child2')?.value, equals('child2'));

      // Dispose the manager
      manager.dispose();

      // All scopes should be disposed
      expect(manager.rootScope.isDisposed, isTrue);
      expect(childScope1.isDisposed, isTrue);
      expect(childScope2.isDisposed, isTrue);

      // Reinitialize for next test
      manager.initialize();
    });
  });
}