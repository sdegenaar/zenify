// test/core/zen_scope_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

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
  // Initialize Flutter testing binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenScope', () {
    late ZenScope testScope;

    setUp(() {
      // Initialize Zen system and create a test scope
      Zen.init();
      testScope = Zen.createScope(name: 'TestScope');
    });

    tearDown(() {
      // Clean up after each test
      Zen.reset();
    });

    test('should create scopes with unique ids', () {
      final scope1 = Zen.createScope(name: 'Scope1');
      final scope2 = Zen.createScope(name: 'Scope2');

      expect(scope1.id, isNot(scope2.id));
      expect(scope1.name, 'Scope1');
      expect(scope2.name, 'Scope2');
    });

    test('should register and find dependencies by type', () {
      final service = TestService('test');

      // Register in test scope
      testScope.put(service);

      final found = testScope.find<TestService>();
      expect(found, isNotNull);
      expect(found, same(service));
      expect(found?.value, 'test');
    });

    test('should register and find dependencies by tag', () {
      final service1 = TestService('service1');
      final service2 = TestService('service2');

      testScope.put(service1, tag: 'tag1');
      testScope.put(service2, tag: 'tag2');

      final found1 = testScope.find<TestService>(tag: 'tag1');
      final found2 = testScope.find<TestService>(tag: 'tag2');

      expect(found1?.value, 'service1');
      expect(found2?.value, 'service2');
    });

    test('should support hierarchical lookup', () {
      // Create a parent-child scope hierarchy
      final parentScope = Zen.createScope(name: 'Parent');
      final childScope = Zen.createScope(name: 'Child', parent: parentScope);

      // Register in parent scope
      final parentService = TestService('parent');
      parentScope.put(parentService);

      // Should be findable from child scope
      final found = childScope.find<TestService>();
      expect(found, isNotNull);
      expect(found, same(parentService));
    });

    test('should only find in current scope when using findInThisScope', () {
      // Create a parent-child scope hierarchy
      final parentScope = Zen.createScope(name: 'Parent');
      final childScope = Zen.createScope(name: 'Child', parent: parentScope);

      // Register in parent scope
      final parentService = TestService('parent');
      parentScope.put(parentService);

      // Should not be findable from child scope using findInThisScope
      final found = childScope.findInThisScope<TestService>();
      expect(found, isNull);
    });

    test('should delete dependencies correctly', () {
      final service = TestService('test');

      testScope.put(service);

      // Verify it exists
      expect(testScope.find<TestService>(), isNotNull);

      // Delete it
      final deleted = testScope.delete<TestService>();
      expect(deleted, isTrue);

      // Verify it's gone
      expect(testScope.find<TestService>(), isNull);
    });

    test('should delete dependencies by tag', () {
      final service = TestService('tagged');

      // Register as temporary (not permanent)
      testScope.put(service, tag: 'my-tag', isPermanent: false);

      // Verify it exists
      expect(testScope.find<TestService>(tag: 'my-tag'), isNotNull);

      // Delete it by tag
      final deleted = testScope.delete<TestService>(tag: 'my-tag');
      expect(deleted, isTrue);

      // Verify it's gone
      expect(testScope.find<TestService>(tag: 'my-tag'), isNull);
    });

    test('should register lazy dependencies', () {
      // Register lazy factory
      testScope.putLazy<TestService>(() => TestService('lazy'));

      // Should be created on first access
      final found = testScope.find<TestService>();
      expect(found, isNotNull);
      expect(found?.value, 'lazy');

      // Should return same instance on subsequent calls
      final found2 = testScope.find<TestService>();
      expect(found2, same(found));

      // findInThisScope should return the same instance after creation
      final foundInScope = testScope.findInThisScope<TestService>();
      expect(foundInScope, same(found));
    });

    test('should register factory dependencies', () {
      var counter = 0;
      // Register factory that creates new instances
      testScope.putLazy<TestService>(() => TestService('factory-${++counter}'),
          alwaysNew: true);

      // Should create new instances each time
      final found1 = testScope.find<TestService>();
      final found2 = testScope.find<TestService>();

      expect(found1, isNotNull);
      expect(found2, isNotNull);
      expect(found1, isNot(same(found2)));
      expect(found1?.value, 'factory-1');
      expect(found2?.value, 'factory-2');
    });

    test('should dispose child scopes when parent is disposed', () {
      final parentScope = Zen.createScope(name: 'Parent');
      final childScope = Zen.createScope(name: 'Child', parent: parentScope);

      final childService = TestService('child');
      childScope.put(childService);

      // Verify service is registered
      expect(childScope.find<TestService>(), isNotNull);

      // Dispose parent
      parentScope.dispose();

      // Child scope should be disposed
      expect(childScope.isDisposed, isTrue);
      final found = childScope.findInThisScope<TestService>();
      expect(found, isNull);
    });

    test('should find all instances of a type across scope hierarchy', () {
      final parentScope = Zen.createScope(name: 'Parent');
      final childScope = Zen.createScope(name: 'Child', parent: parentScope);

      final parentService = TestService('parent');
      final childService = TestService('child');

      // Register in parent
      parentScope.put(parentService);

      // Register in child
      childScope.put(childService);

      final results = parentScope.findAllOfType<TestService>();
      expect(results.length, 2);
      expect(results.any((s) => s.value == 'parent'), isTrue);
      expect(results.any((s) => s.value == 'child'), isTrue);
    });

    test('should handle permanent vs temporary dependencies', () {
      final permanentService = TestService('permanent');
      final temporaryService = TestService('temporary');

      // Register permanent dependency
      testScope.put(permanentService, isPermanent: true);

      // Register temporary dependency
      testScope.put(temporaryService, isPermanent: false, tag: 'temp');

      // Try to delete permanent (should fail without force)
      final deletedPermanentWithoutForce = testScope.delete<TestService>();
      expect(deletedPermanentWithoutForce, isFalse);
      expect(testScope.find<TestService>(), isNotNull); // Should still exist

      // Delete temporary (should succeed)
      final deletedTemporary = testScope.delete<TestService>(tag: 'temp');
      expect(deletedTemporary, isTrue);
      expect(
          testScope.find<TestService>(tag: 'temp'), isNull); // Should be gone

      // Force delete permanent (should succeed)
      final forceDeleted = testScope.delete<TestService>(force: true);
      expect(forceDeleted, isTrue);
      expect(testScope.find<TestService>(), isNull); // Should be gone
    });

    test('should handle global scope operations', () {
      final globalService = TestService('global');

      // Register in root scope (global scope)
      Zen.put(globalService);

      // Should be findable from root scope
      final found = Zen.findOrNull<TestService>();
      expect(found, isNotNull);
      expect(found?.value, 'global');

      // Should also be findable from any child scope (hierarchical lookup)
      // Create child scope with root scope as parent for hierarchical lookup
      final childScope = Zen.createScope(name: 'Child', parent: Zen.rootScope);
      final foundFromChild = childScope.find<TestService>();
      expect(foundFromChild, isNotNull);
      expect(foundFromChild?.value, 'global');

      // Should be findable directly from root scope
      final foundFromRoot = Zen.rootScope.find<TestService>();
      expect(foundFromRoot, isNotNull);
      expect(foundFromRoot?.value, 'global');

      // Clean up
      Zen.delete<TestService>(force: true);
    });

    test('should track dependencies correctly', () {
      final service = TestService('service');

      testScope.put<TestService>(service);

      // Verify the service exists
      expect(testScope.findInThisScope<TestService>(), isNotNull);

      // Test that we can access it
      final found = testScope.find<TestService>();
      expect(found, same(service));
    });

    test('should register disposers correctly', () {
      var disposerCalled = false;

      testScope.registerDisposer(() {
        disposerCalled = true;
      });

      // Verify disposer hasn't been called yet
      expect(disposerCalled, isFalse);

      // Dispose the scope
      testScope.dispose();

      // Verify disposer was called
      expect(disposerCalled, isTrue);
    });

    test('should delete temporary dependencies correctly', () {
      final service = TestService('delete-test');

      // Explicitly register as temporary
      testScope.put<TestService>(service, tag: 'delete-me', isPermanent: false);

      // Verify it exists
      expect(testScope.find<TestService>(tag: 'delete-me'), isNotNull);

      // Delete it (temporary should delete without force)
      final deleted = testScope.delete<TestService>(tag: 'delete-me');
      expect(deleted, isTrue);

      // Verify it's gone
      final found = testScope.find<TestService>(tag: 'delete-me');
      expect(found, isNull);
    });

    test('should check if dependencies exist', () {
      final service = TestService('exists-test');

      // Should not exist initially
      expect(testScope.exists<TestService>(), isFalse);
      expect(testScope.exists<TestService>(tag: 'test'), isFalse);

      // Register service
      testScope.put(service);
      testScope.put(service, tag: 'test');

      // Should exist now
      expect(testScope.exists<TestService>(), isTrue);
      expect(testScope.exists<TestService>(tag: 'test'), isTrue);

      // Delete and verify doesn't exist
      testScope.delete<TestService>();
      expect(testScope.exists<TestService>(), isFalse);
      expect(testScope.exists<TestService>(tag: 'test'),
          isTrue); // Tagged one still exists

      testScope.delete<TestService>(tag: 'test');
      expect(testScope.exists<TestService>(tag: 'test'), isFalse);
    });

    test('should handle permanent vs temporary dependencies', () {
      final tempService = TestService('temp');
      final permService = TestService('perm');

      // Use explicit permanent flag
      testScope.put(tempService, tag: 'temp', isPermanent: false);
      testScope.put(permService, tag: 'perm', isPermanent: true);

      // Both should exist
      expect(testScope.find<TestService>(tag: 'temp'), isNotNull);
      expect(testScope.find<TestService>(tag: 'perm'), isNotNull);

      // Temp should delete without force
      expect(testScope.delete<TestService>(tag: 'temp'), isTrue);

      // Perm should require force
      expect(testScope.delete<TestService>(tag: 'perm'), isFalse);
      expect(testScope.delete<TestService>(tag: 'perm', force: true), isTrue);
    });

    test('should handle deleteByTag and deleteByType', () {
      final service1 = TestService('service1');
      final service2 = TestService('service2');

      testScope.put(service1);
      testScope.put(service2, tag: 'tagged');

      // Delete by tag
      expect(testScope.deleteByTag('tagged'), isTrue);
      expect(testScope.find<TestService>(tag: 'tagged'), isNull);
      expect(testScope.find<TestService>(), isNotNull); // Untagged still exists

      // Delete by type
      expect(testScope.deleteByType(TestService), isTrue);
      expect(testScope.find<TestService>(), isNull);
    });

    test('should provide dependency metadata', () {
      final service = TestService('metadata-test');

      testScope.put(service, tag: 'tagged', isPermanent: true);
      testScope.put(service); // Also register without tag

      // Check if permanent
      expect(testScope.isPermanent(type: TestService, tag: 'tagged'), isTrue);
      expect(testScope.isPermanent(type: TestService),
          isFalse); // Untagged defaults to false

      // Check if contains instance
      expect(testScope.containsInstance(service), isTrue);

      final otherService = TestService('other');
      expect(testScope.containsInstance(otherService), isFalse);

      // Get tag for instance
      final tag = testScope.getTagForInstance(service);
      expect(tag, 'tagged'); // Should return the first tag found
    });
  });
}
