// test/debug/zen_scope_inspector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import '../test_helpers.dart';

void main() {
  group('ZenScopeInspector', () {
    late ZenScope testScope;

    setUp(() {
      ZenTestHelper.resetDI();
      testScope = ZenTestHelper.createIsolatedTestScope('inspector-test');
    });

    tearDown(() {
      try {
        if (!testScope.isDisposed) {
          testScope.dispose();
        }
      } catch (e) {
        // Ignore disposal errors in teardown
      }
    });

    test('should get all instances from scope', () {
      // Arrange
      final service = TestService('test');
      final controller = TestController('test');
      testScope.put<TestService>(service);
      testScope.put<TestController>(controller);

      // Act
      final instances = ZenScopeInspector.getAllInstances(testScope);

      // Assert
      expect(instances.length, equals(2));
      expect(instances[TestService], equals(service));
      expect(instances[TestController], equals(controller));
    });

    test('should return empty map for disposed scope', () {
      // Arrange
      testScope.put<TestService>(TestService('test'));
      testScope.dispose();

      // Act
      final instances = ZenScopeInspector.getAllInstances(testScope);

      // Assert
      expect(instances, isEmpty);
    });

    test('should get registered types correctly', () {
      // Arrange
      testScope.put<TestService>(TestService('test'));
      testScope.put<TestController>(TestController('test'));

      // Act
      final types = ZenScopeInspector.getRegisteredTypes(testScope);

      // Assert
      expect(types.length, equals(2));
      expect(types, contains(TestService));
      expect(types, contains(TestController));
    });

    test('should create comprehensive debug map', () {
      // Arrange
      final service = TestService('test');
      testScope.put<TestService>(service);

      // Record initial child count to handle contamination
      final initialChildCount = testScope.childScopes.length;

      // Create a child scope to test child count
      final childScope = testScope.createChild(name: 'test-child-${DateTime.now().millisecondsSinceEpoch}');

      try {
        // Act
        final debugMap = ZenScopeInspector.toDebugMap(testScope);

        // Assert - Check that we added exactly 1 child
        expect(debugMap['scopeInfo']['name'], contains('inspector-test'));
        expect(debugMap['scopeInfo']['disposed'], isFalse);
        expect(debugMap['scopeInfo']['childCount'], equals(initialChildCount + 1));
        expect(debugMap['dependencies']['totalDependencies'], equals(1));
        expect(debugMap['children'], hasLength(initialChildCount + 1));
      } finally {
        // Clean up child scope immediately
        childScope.dispose();
      }
    });

    test('should create debug map with no children', () {
      // Arrange
      final service = TestService('test');
      testScope.put<TestService>(service);
      // Note: Not creating any child scopes

      // Act
      final debugMap = ZenScopeInspector.toDebugMap(testScope);

      // Assert
      expect(debugMap['scopeInfo']['name'], contains('inspector-test'));
      expect(debugMap['scopeInfo']['disposed'], isFalse);
      expect(debugMap['scopeInfo']['childCount'], equals(0));
      expect(debugMap['dependencies']['totalDependencies'], equals(1));
      expect(debugMap['children'], hasLength(0));
    });

    test('should categorize dependencies correctly', () {
      // Arrange
      testScope.put<TestService>(TestService('test'));
      testScope.put<TestController>(TestController('test'));

      // Act
      final breakdown = ZenScopeInspector.getDependencyBreakdown(testScope);

      // Assert
      expect(breakdown['controllers'], hasLength(1));
      expect(breakdown['services'], hasLength(1));
      expect(breakdown['summary']['totalControllers'], equals(1));
      expect(breakdown['summary']['totalServices'], equals(1));
    });

    test('should get scope path correctly', () {
      // Create a completely isolated hierarchy for this test
      final parentScope = ZenTestHelper.createIsolatedTestScope('path-parent');
      final childScope = parentScope.createChild(name: 'path-child');
      final grandChildScope = childScope.createChild(name: 'path-grandchild');

      try {
        // Act
        final path = ZenScopeInspector.getScopePath(grandChildScope);

        // Assert - The path should include our created scopes
        expect(path.length, greaterThanOrEqualTo(3));
        expect(path, contains('path-child'));
        expect(path, contains('path-grandchild'));

        // Check that grandchild is the last element
        expect(path.last, equals('path-grandchild'));
      } finally {
        // Clean up
        parentScope.dispose(); // This will dispose all children
      }
    });

    test('should handle tagged dependencies correctly', () {
      // Arrange
      testScope.put<TestService>(TestService('service1'), tag: 'tag1');
      testScope.put<TestService>(TestService('service2'), tag: 'tag2');
      testScope.put<TestController>(TestController('controller1'), tag: 'controller-tag');

      // Act
      final breakdown = ZenScopeInspector.getDependencyBreakdown(testScope);

      // Assert
      expect(breakdown['services'], hasLength(2)); // Two tagged services
      expect(breakdown['controllers'], hasLength(1)); // One tagged controller
      expect(breakdown['summary']['totalServices'], equals(2));
      expect(breakdown['summary']['totalControllers'], equals(1));
    });


    test('should inspect disposed scope gracefully', () {
      // Arrange
      testScope.put<TestService>(TestService('test'));
      // Create child just to verify it affects the initial state
      testScope.createChild(name: 'disposable-child');

      // Get initial state
      var debugMap = ZenScopeInspector.toDebugMap(testScope);
      expect(debugMap['scopeInfo']['disposed'], isFalse);
      expect(debugMap['scopeInfo']['childCount'], greaterThanOrEqualTo(1));

      // Dispose the scope
      testScope.dispose();

      // Act
      debugMap = ZenScopeInspector.toDebugMap(testScope);

      // Assert - Should handle disposed scope gracefully
      expect(debugMap['scopeInfo']['disposed'], isTrue);
      expect(debugMap['dependencies']['totalDependencies'], equals(0));
      expect(debugMap['children'], isEmpty);

      // Should return empty instances
      final instances = ZenScopeInspector.getAllInstances(testScope);
      expect(instances, isEmpty);
    });
  });
}