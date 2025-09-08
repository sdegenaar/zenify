// test/debug/zen_system_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import 'package:zenify/debug/debug.dart';
import '../test_helpers.dart';

void main() {
  group('ZenSystemStats', () {
    setUp(() {
      ZenTestHelper.resetDI();
    });

    test('should calculate system stats correctly', () {
      // Arrange
      final rootScope = Zen.rootScope;
      rootScope.put<TestService>(TestService('root'));
      rootScope.put<TestController>(TestController('root'));

      final childScope = rootScope.createChild(name: 'child');
      childScope.put<TestService>(TestService('child'));

      // Act
      final stats = ZenSystemStats.getSystemStats();

      // Assert
      expect(stats['scopes']['total'], greaterThanOrEqualTo(2));
      expect(stats['dependencies']['total'], greaterThanOrEqualTo(3));
      expect(stats['dependencies']['controllers'], greaterThanOrEqualTo(1));
      expect(stats['dependencies']['services'], greaterThanOrEqualTo(2));
    });

    test('should find all instances of specific type', () {
      // Verify clean state first
      var initialServices =
          ZenSystemStats.findAllInstancesOfType<TestService>();
      expect(initialServices, isEmpty,
          reason: 'Should start with no TestService instances');

      final service1 = TestService('service1');
      final service2 = TestService('service2');

      // Register instances
      Zen.put<TestService>(service1, tag: 'tag1');

      final childScope = Zen.createScope(name: 'isolated-child');
      childScope.put<TestService>(service2, tag: 'tag2');

      // Act
      final services = ZenSystemStats.findAllInstancesOfType<TestService>();

      // Assert
      expect(services.length, equals(2),
          reason: 'Should find exactly 2 TestService instances');
      expect(services, contains(service1));
      expect(services, contains(service2));
    });

    test('should find scope containing specific instance', () {
      // Verify clean state
      final initialServices =
          ZenSystemStats.findAllInstancesOfType<TestService>();
      expect(initialServices, isEmpty,
          reason: 'Should start with no TestService instances');

      final service = TestService('isolated-test');
      final childScope = Zen.createScope(name: 'isolated-scope');
      childScope.put<TestService>(service);

      // Act
      final foundScope = ZenSystemStats.findScopeContaining(service);

      // Assert
      expect(foundScope, isNotNull,
          reason: 'Should find a scope containing the service');
      expect(foundScope, equals(childScope),
          reason: 'Should find the child scope, not root scope');
      expect(foundScope?.name, equals('isolated-scope'));
    });

    test('should generate comprehensive system report', () {
      // Arrange
      Zen.rootScope.put<TestService>(TestService('test'));
      Zen.rootScope.put<TestController>(TestController('test'));

      // Act
      final report = ZenSystemStats.generateSystemReport();

      // Assert
      expect(report, contains('ZEN SYSTEM REPORT'));
      expect(report, contains('SCOPES:'));
      expect(report, contains('DEPENDENCIES:'));
      expect(report, contains('PERFORMANCE:'));
      expect(report, contains('HIERARCHY'));
    });

    test('should handle empty system gracefully', () {
      // Arrange - verify clean system (already clean from setUp)
      final initialServices =
          ZenSystemStats.findAllInstancesOfType<TestService>();
      expect(initialServices, isEmpty,
          reason: 'Should start with clean system');

      // Act
      final stats = ZenSystemStats.getSystemStats();

      // Assert
      expect(stats['scopes']['total'],
          greaterThanOrEqualTo(1)); // At least root scope
      expect(stats['dependencies']['total'],
          equals(0)); // Should be exactly 0 for clean system
    });

    test('should find instances across complex scope hierarchy', () {
      // Verify clean state
      final initialServices =
          ZenSystemStats.findAllInstancesOfType<TestService>();
      expect(initialServices, isEmpty,
          reason: 'Should start with no TestService instances');

      final rootService = TestService('root-isolated');
      final childService = TestService('child-isolated');
      final grandChildService = TestService('grandchild-isolated');

      // Build hierarchy with unique names
      Zen.put<TestService>(rootService, tag: 'root-tag');

      final childScope = Zen.createScope(name: 'isolated-child-scope');
      childScope.put<TestService>(childService, tag: 'child-tag');

      final grandChildScope =
          childScope.createChild(name: 'isolated-grandchild-scope');
      grandChildScope.put<TestService>(grandChildService,
          tag: 'grandchild-tag');

      // Act - Find all services
      final allServices = ZenSystemStats.findAllInstancesOfType<TestService>();

      // Assert
      expect(allServices.length, equals(3),
          reason:
              'Should find exactly 3 TestService instances across all scopes');
      expect(allServices,
          containsAll([rootService, childService, grandChildService]));

      // Test finding specific scopes
      final foundRootScope = ZenSystemStats.findScopeContaining(rootService);
      final foundChildScope = ZenSystemStats.findScopeContaining(childService);
      final foundGrandChildScope =
          ZenSystemStats.findScopeContaining(grandChildService);

      expect(foundRootScope?.name, equals('RootScope'));
      expect(foundChildScope?.name, equals('isolated-child-scope'));
      expect(foundGrandChildScope?.name, equals('isolated-grandchild-scope'));
    });
  });
}
