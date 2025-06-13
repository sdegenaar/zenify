// test/core/controller_dependency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Mock controllers and services for testing
class MockService {
  bool initialized = false;
  bool disposed = false;

  void initialize() {
    initialized = true;
  }

  void dispose() {
    disposed = true;
  }
}

class DependentController extends ZenController {
  final MockService service;

  DependentController(this.service);

  bool serviceCallMade = false;

  void callServiceMethod() {
    service.initialize();
    serviceCallMade = true;
  }
}

class CircularControllerA extends ZenController {
  CircularControllerB? controllerB;

  CircularControllerA();

  void setControllerB(CircularControllerB controllerB) {
    this.controllerB = controllerB;
  }
}

class CircularControllerB extends ZenController {
  CircularControllerA? controllerA;

  CircularControllerB();

  void setControllerA(CircularControllerA controllerA) {
    this.controllerA = controllerA;
  }
}

class ScopedController extends ZenController {
  final ZenScope scope;
  final String? tag;

  ScopedController(this.scope, {this.tag});
}

void main() {
  setUp(() {
    // Initialize the Flutter binding first
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Zen for testing
    Zen.init();
    ZenConfig.enableDebugLogs = false; // Disable logs for cleaner test output
  });

  tearDown(() {
    // Clean up after each test
    Zen.reset();
  });

  group('Controller Dependencies', () {
    test('should inject service dependency into controller', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'inject-dependency');

      // Register the service first
      final service = MockService();
      testScope.put<MockService>(service);

      // Create controller with dependency
      final controller = DependentController(service);
      testScope.put<DependentController>(controller);

      // Verify the service is properly injected
      expect(controller.service, same(service));

      // Test interaction
      controller.callServiceMethod();
      expect(controller.serviceCallMade, true);
      expect(service.initialized, true);

      // Cleanup
      testScope.delete<DependentController>();

      // Clean up the test scope
      testScope.dispose();
    });

    test('should find dependencies across scopes correctly', () {
      // Create parent and child scopes
      final parentScope = Zen.createScope(name: "ParentScope");
      final childScope = Zen.createScope(parent: parentScope, name: "ChildScope");

      // Register service in parent scope
      final service = MockService();
      parentScope.put<MockService>(service);

      // Controller in child scope should be able to find the service
      final foundService = childScope.find<MockService>();
      expect(foundService, same(service));

      // Create controller in child scope
      final controller = DependentController(foundService!);
      childScope.put<DependentController>(controller);

      // Verify controller can use the service
      controller.callServiceMethod();
      expect(service.initialized, true);

      // Cleanup
      childScope.dispose();
      parentScope.dispose();
    });

    test('should track and dispose controllers with dependencies', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'track-dispose');

      // Register service
      final service = MockService();
      testScope.put<MockService>(service);

      // Create controller with dependency
      final controller = DependentController(service);
      testScope.put<DependentController>(controller);

      // Dispose controller
      expect(controller.isDisposed, false);
      testScope.delete<DependentController>();
      expect(controller.isDisposed, true);

      // Service should not be automatically disposed
      expect(service.disposed, false);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle controllers with tagged dependencies', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'tagged-dependencies');

      // Register two services with different tags
      final service1 = MockService();
      final service2 = MockService();

      testScope.put<MockService>(service1, tag: "service1");
      testScope.put<MockService>(service2, tag: "service2");

      // Find each service by tag
      final foundService1 = testScope.find<MockService>(tag: "service1");
      final foundService2 = testScope.find<MockService>(tag: "service2");

      expect(foundService1, same(service1));
      expect(foundService2, same(service2));

      // Create controllers with different service dependencies
      final controller1 = DependentController(foundService1!);
      final controller2 = DependentController(foundService2!);

      testScope.put<DependentController>(controller1, tag: "controller1");
      testScope.put<DependentController>(controller2, tag: "controller2");

      // Verify correct dependencies
      final retrievedController1 = testScope.find<DependentController>(tag: "controller1");
      final retrievedController2 = testScope.find<DependentController>(tag: "controller2");

      expect(retrievedController1!.service, same(service1));
      expect(retrievedController2!.service, same(service2));

      // Test service interactions
      retrievedController1.callServiceMethod();
      expect(service1.initialized, true);
      expect(service2.initialized, false);

      retrievedController2.callServiceMethod();
      expect(service2.initialized, true);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle circular dependencies when manually created', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'circular-dependencies');

      // Create circular dependency controllers manually
      final controllerA = CircularControllerA();
      final controllerB = CircularControllerB();

      // Set up circular references
      controllerA.setControllerB(controllerB);
      controllerB.setControllerA(controllerA);

      // Register both controllers
      testScope.put<CircularControllerA>(controllerA);
      testScope.put<CircularControllerB>(controllerB);

      // Verify they can find each other
      final foundA = testScope.find<CircularControllerA>();
      final foundB = testScope.find<CircularControllerB>();

      expect(foundA, same(controllerA));
      expect(foundB, same(controllerB));
      expect(foundA!.controllerB, same(controllerB));
      expect(foundB!.controllerA, same(controllerA));

      // Clean up the test scope
      testScope.dispose();
    });

    test('should support dependency injection in scoped controllers', () {
      // Create scopes
      final parentScope = Zen.createScope(name: "ParentScope");
      final childScope = Zen.createScope(parent: parentScope, name: "ChildScope");

      // Create controllers tied to specific scopes
      final parentController = ScopedController(parentScope);
      final childController = ScopedController(childScope);

      parentScope.put<ScopedController>(parentController, tag: "parent");
      childScope.put<ScopedController>(childController, tag: "child");

      // Verify scope isolation and inheritance
      final foundParentInParent = parentScope.find<ScopedController>(tag: "parent");
      final foundParentInChild = childScope.find<ScopedController>(tag: "parent");
      final foundChildInParent = parentScope.findInThisScope<ScopedController>(tag: "child");
      final foundChildInChild = childScope.find<ScopedController>(tag: "child");

      expect(foundParentInParent, same(parentController));
      expect(foundParentInChild, same(parentController)); // Parent is visible in child scope
      expect(foundChildInParent, isNull); // Child is not visible in parent scope
      expect(foundChildInChild, same(childController));

      // Test disposing a parent scope
      parentScope.dispose();

      // After parent scope disposal, both controllers should be disposed
      expect(parentController.isDisposed, true);
      expect(childController.isDisposed, true);
    });

    test('should handle lazy dependencies correctly', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'lazy-dependencies');

      bool factoryCalled = false;

      // Register a lazy dependency
      testScope.putLazy<MockService>(() {
        factoryCalled = true;
        return MockService();
      });

      // Factory should not be called yet
      expect(factoryCalled, false);

      // Access should create it
      final service = testScope.find<MockService>();
      expect(service, isA<MockService>());
      expect(factoryCalled, true);

      // Should return same instance on subsequent calls
      final serviceAfterAccess = testScope.find<MockService>();
      expect(serviceAfterAccess, same(service));

      // Create a controller with a lazy dependency
      bool controllerFactoryCalled = false;
      testScope.putLazy<DependentController>(() {
        controllerFactoryCalled = true;
        return DependentController(service!);
      });

      expect(controllerFactoryCalled, false);

      // Accessing should create it
      final controller = testScope.find<DependentController>();
      expect(controller, isA<DependentController>());
      expect(controllerFactoryCalled, true);
      expect(controller!.service, same(service));

      // Controller should return same instance
      expect(testScope.find<DependentController>(), same(controller));

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle factory dependencies correctly', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'factory-dependencies');

      int factoryCallCount = 0;

      // Register a factory dependency (new instance each time)
      testScope.putFactory<MockService>(() {
        factoryCallCount++;
        return MockService();
      });

      // First access should create instance
      final service1 = testScope.find<MockService>();
      expect(service1, isA<MockService>());
      expect(factoryCallCount, 1);

      // Second access should create new instance
      final service2 = testScope.find<MockService>();
      expect(service2, isA<MockService>());
      expect(factoryCallCount, 2);

      // Should be different instances
      expect(service1, isNot(same(service2)));

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle dependency deletion correctly', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'dependency-deletion');

      // Register service and controller
      final service = MockService();
      testScope.put<MockService>(service);

      final controller = DependentController(service);
      testScope.put<DependentController>(controller, permanent: false);

      // Verify they exist
      expect(testScope.find<MockService>(), same(service));
      expect(testScope.find<DependentController>(), same(controller));

      // Delete controller (should dispose it)
      final deleted = testScope.delete<DependentController>();
      expect(deleted, true);
      expect(controller.isDisposed, true);
      expect(testScope.find<DependentController>(), isNull);

      // Service should still exist
      expect(testScope.find<MockService>(), same(service));

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle permanent vs temporary dependencies', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'permanent-temp');

      // Register permanent service
      final service = MockService();
      testScope.put<MockService>(service, permanent: true);

      // Register temporary controller
      final controller = DependentController(service);
      testScope.put<DependentController>(controller, permanent: false);

      // Try to delete permanent service (should fail without force)
      final serviceDeleted = testScope.delete<MockService>();
      expect(serviceDeleted, false);
      expect(testScope.find<MockService>(), same(service));

      // Delete temporary controller (should succeed)
      final controllerDeleted = testScope.delete<DependentController>();
      expect(controllerDeleted, true);
      expect(controller.isDisposed, true);

      // Force delete permanent service
      final forceDeleted = testScope.delete<MockService>(force: true);
      expect(forceDeleted, true);
      expect(testScope.find<MockService>(), isNull);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle multiple dependencies of same type with tags', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'multiple-dependencies');

      // Temporarily enable debug logs for this test
      final originalDebugState = ZenConfig.enableDebugLogs;
      ZenConfig.enableDebugLogs = true;

      try {
        // Register multiple services of same type
        final serviceA = MockService();
        final serviceB = MockService();
        final serviceC = MockService();

        testScope.put<MockService>(serviceA, tag: 'A');
        testScope.put<MockService>(serviceB, tag: 'B');
        testScope.put<MockService>(serviceC); // No tag

        // Verify existence checks
        expect(testScope.exists<MockService>(tag: 'A'), isTrue);
        expect(testScope.exists<MockService>(tag: 'B'), isTrue);
        expect(testScope.exists<MockService>(), isTrue);

        // Verify individual service lookups
        expect(testScope.find<MockService>(tag: 'A'), same(serviceA));
        expect(testScope.find<MockService>(tag: 'B'), same(serviceB));
        expect(testScope.find<MockService>(), same(serviceC));

        // Find all services of type
        final allServices = testScope.findAllOfType<MockService>();
        expect(allServices.length, 3);
        expect(allServices, containsAll([serviceA, serviceB, serviceC]));
      } finally {
        // Restore debug state
        ZenConfig.enableDebugLogs = originalDebugState;

        // Clean up the test scope
        testScope.dispose();
      }
    });

    test('should handle dependency existence checks', () {
      // Create a test scope for this specific test
      final testScope = Zen.createScope(name: 'existence-checks');

      // Initially no dependencies
      expect(testScope.exists<MockService>(), false);
      expect(testScope.exists<DependentController>(), false);

      // Register service
      final service = MockService();
      testScope.put<MockService>(service);

      expect(testScope.exists<MockService>(), true);
      expect(testScope.exists<DependentController>(), false);

      // Register controller
      final controller = DependentController(service);
      testScope.put<DependentController>(controller);

      expect(testScope.exists<MockService>(), true);
      expect(testScope.exists<DependentController>(), true);

      // Check tagged existence
      expect(testScope.exists<MockService>(tag: 'nonexistent'), false);

      testScope.put<MockService>(MockService(), tag: 'tagged');
      expect(testScope.exists<MockService>(tag: 'tagged'), true);

      // Clean up the test scope
      testScope.dispose();
    });
  });
}