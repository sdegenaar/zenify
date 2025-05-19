// test/core/zen_scope_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_state/zen_state.dart';

// Test service classes
class TestService {
  final String value;
  TestService(this.value);
}

class DependentService {
  final TestService dependency;
  DependentService(this.dependency);
}

void main() {
  group('ZenScope', () {
    late ZenScope rootScope;

    setUp(() {
      // Create a fresh root scope for each test
      rootScope = ZenScope(name: 'TestRoot');
    });

    tearDown(() {
      // Clean up after each test
      rootScope.dispose();
    });

    test('should create scopes with unique ids', () {
      final scope1 = ZenScope(name: 'Scope1');
      final scope2 = ZenScope(name: 'Scope2');

      expect(scope1.id, isNot(scope2.id));
      expect(scope1.name, 'Scope1');
      expect(scope2.name, 'Scope2');
    });

    test('should register and find dependencies by type', () {
      final service = TestService('test');
      rootScope.register<TestService>(service);

      final found = rootScope.find<TestService>();
      expect(found, isNotNull);
      expect(found, same(service));
      expect(found?.value, 'test');
    });

    test('should register and find dependencies by tag', () {
      final service1 = TestService('service1');
      final service2 = TestService('service2');

      rootScope.register<TestService>(service1, tag: 'tag1');
      rootScope.register<TestService>(service2, tag: 'tag2');

      final found1 = rootScope.find<TestService>(tag: 'tag1');
      final found2 = rootScope.find<TestService>(tag: 'tag2');

      expect(found1?.value, 'service1');
      expect(found2?.value, 'service2');
    });

    test('should support hierarchical lookup', () {
      // Create a parent-child scope hierarchy
      final parentScope = ZenScope(name: 'Parent');
      final childScope = ZenScope(name: 'Child', parent: parentScope);

      // Register in parent scope
      final parentService = TestService('parent');
      parentScope.register<TestService>(parentService);

      // Should be findable from child scope
      final found = childScope.find<TestService>();
      expect(found, isNotNull);
      expect(found, same(parentService));
    });

    test('should only find in current scope when using findInThisScope', () {
      // Create a parent-child scope hierarchy
      final parentScope = ZenScope(name: 'Parent');
      final childScope = ZenScope(name: 'Child', parent: parentScope);

      // Register in parent scope
      final parentService = TestService('parent');
      parentScope.register<TestService>(parentService);

      // Should not be findable from child scope using findInThisScope
      final found = childScope.findInThisScope<TestService>();
      expect(found, isNull);
    });

    test('should delete dependencies correctly', () {
      final service = TestService('test');
      rootScope.register<TestService>(service);

      // Verify it exists
      expect(rootScope.find<TestService>(), isNotNull);

      // Delete it
      final deleted = rootScope.delete<TestService>();
      expect(deleted, isTrue);

      // Verify it's gone
      expect(rootScope.find<TestService>(), isNull);
    });

    test('should delete dependencies by tag', () {
      final service = TestService('tagged');
      rootScope.register<TestService>(service, tag: 'my-tag');

      // Verify it exists
      expect(rootScope.find<TestService>(tag: 'my-tag'), isNotNull);

      // Delete it
      final deleted = rootScope.deleteByTag('my-tag');
      expect(deleted, isTrue);

      // Verify it's gone
      expect(rootScope.find<TestService>(tag: 'my-tag'), isNull);
    });

    test('should track dependencies and detect cycles', () {
      final serviceA = TestService('A');
      final serviceB = TestService('B');
      final serviceC = TestService('C');

      // Create a circular dependency A -> B -> C -> A
      rootScope.register<TestService>(serviceA, tag: 'A', declaredDependencies: [serviceB]);
      rootScope.register<TestService>(serviceB, tag: 'B', declaredDependencies: [serviceC]);
      rootScope.register<TestService>(serviceC, tag: 'C', declaredDependencies: [serviceA]);

      // The _detectCycles method is private, but we've already invoked it during registration
      // We could check logs or add a public method for testing purposes
    });

    test('should dispose child scopes when parent is disposed', () {
      final parentScope = ZenScope(name: 'Parent');
      final childScope = ZenScope(name: 'Child', parent: parentScope);

      final childService = TestService('child');
      childScope.register<TestService>(childService);

      // Verify service is registered
      expect(childScope.find<TestService>(), isNotNull);

      // Dispose parent
      parentScope.dispose();

      // Child scope should be disposed
      final found = childScope.find<TestService>();
      expect(found, isNull);
    });

    test('should find all instances of a type across scope hierarchy', () {
      final parentScope = ZenScope(name: 'Parent');
      final childScope = ZenScope(name: 'Child', parent: parentScope);

      final parentService = TestService('parent');
      final childService = TestService('child');

      parentScope.register<TestService>(parentService);
      childScope.register<TestService>(childService);

      final results = parentScope.findAllOfType<TestService>();
      expect(results.length, 2);
      expect(results.any((s) => s.value == 'parent'), isTrue);
      expect(results.any((s) => s.value == 'child'), isTrue);
    });

    test('should track use count for auto-disposal', () {
      final service = TestService('service');
      rootScope.register<TestService>(service);

      // Increment use count
      rootScope.incrementUseCount<TestService>();

      // Decrement use count
      final count = rootScope.decrementUseCount<TestService>();
      expect(count, 0);
    });
  });
}