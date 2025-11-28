// test/debug/zen_hierarchy_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import 'package:zenify/debug/debug.dart';
import '../test_helpers.dart';

void main() {
  group('ZenHierarchyBuilder', () {
    setUp(() {
      ZenTestHelper.resetDI();
    });

    test('should build hierarchy tree correctly', () {
      // Arrange
      final rootScope = Zen.rootScope;
      rootScope.put<TestService>(TestService('root'));

      // Create a uniquely named child to avoid conflicts with other tests
      final childScope = rootScope.createChild(name: 'hierarchy-test-child');
      childScope.put<TestController>(TestController('child'));

      // Act
      final tree = ZenHierarchyDebug.buildHierarchyTree(rootScope);

      // Assert
      expect(tree['scope']['scopeInfo']['name'], equals('RootScope'));

      // More flexible assertion - check that we have at least one child and find our specific child
      expect(tree['children'], isA<List>());
      expect(tree['children'].length, greaterThanOrEqualTo(1));

      // Find our specific child in the children list
      final children = tree['children'] as List;
      final ourChild = children.cast<Map<String, dynamic>>().firstWhere(
            (child) =>
                child['scope']['scopeInfo']['name'] == 'hierarchy-test-child',
            orElse: () =>
                <String, dynamic>{}, // Return empty map instead of null
          );

      expect(ourChild.isNotEmpty, isTrue,
          reason: 'Should find our created child scope');
      expect(ourChild['scope']['scopeInfo']['name'],
          equals('hierarchy-test-child'));

      // Clean up
      childScope.dispose();
    });

    test('should get complete hierarchy info', () {
      // Act
      final info = ZenHierarchyDebug.getCompleteHierarchyInfo();

      // Assert
      expect(info['currentScope'], isNotNull);
      expect(info['rootScope'], isNotNull);
      expect(info['hierarchy'], isNotNull);
      expect(info['scopeStats'], isNotNull);
    });

    test('should collect all scopes recursively', () {
      // Arrange
      final rootScope = Zen.rootScope;
      final child1 = rootScope.createChild(name: 'collect-child1');
      final child2 = rootScope.createChild(name: 'collect-child2');
      final grandChild = child1.createChild(name: 'collect-grandchild');

      // Act
      final allScopes = ZenDebug.allScopes;

      // Assert
      expect(allScopes.length, greaterThanOrEqualTo(4)); // root + 3 created
      expect(allScopes, contains(rootScope));
      expect(allScopes, contains(child1));
      expect(allScopes, contains(child2));
      expect(allScopes, contains(grandChild));

      // Clean up
      child1.dispose(); // This will dispose grandChild too
      child2.dispose();
    });

    test('should dump hierarchy as formatted string', () {
      // Arrange
      final rootScope = Zen.rootScope;
      rootScope.put<TestService>(TestService('test'));

      // Actually create a child scope that the test expects to find
      final childScope = rootScope.createChild(name: 'dump-test-child');
      childScope.put<TestService>(TestService('child-service'));

      // Act
      final dump = ZenHierarchyDebug.dumpCompleteHierarchy();

      // Assert
      expect(dump, contains('ZEN SCOPE HIERARCHY'));
      expect(dump, contains('RootScope'));
      expect(dump, contains('dump-test-child')); // Use our specific child name
      expect(dump, contains('Dependencies:'));

      // Clean up
      childScope.dispose();
    });

    test('should dump simple hierarchy with only root scope', () {
      // Arrange
      final rootScope = Zen.rootScope;
      rootScope.put<TestService>(TestService('test'));
      // Note: NOT creating any child scopes

      // Act
      final dump = ZenHierarchyDebug.dumpCompleteHierarchy();

      // Assert
      expect(dump, contains('ZEN SCOPE HIERARCHY'));
      expect(dump, contains('RootScope'));
      expect(dump, contains('Dependencies: 1'));
      expect(dump, contains('Services: 1'));
    });

    test('should dump complex hierarchy correctly', () {
      // Arrange
      final rootScope = Zen.rootScope;
      rootScope.put<TestService>(TestService('root-service'));

      final child1 = rootScope.createChild(name: 'complex-child1');
      child1.put<TestController>(TestController('child1-controller'));

      final child2 = rootScope.createChild(name: 'complex-child2');
      child2.put<TestService>(TestService('child2-service'));

      final grandChild = child1.createChild(name: 'complex-grandchild');
      grandChild.put<TestService>(TestService('grandchild-service'));

      // Act
      final dump = ZenHierarchyDebug.dumpCompleteHierarchy();

      // Assert
      expect(dump, contains('RootScope'));
      expect(dump, contains('complex-child1'));
      expect(dump, contains('complex-child2'));
      expect(dump, contains('complex-grandchild'));
      expect(dump, contains('Controllers: 1'));
      expect(dump, contains('Services:'));

      // Clean up
      child1.dispose(); // This will dispose grandChild too
      child2.dispose();
    });
  });
}
