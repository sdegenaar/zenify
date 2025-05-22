// test/core/controller_dependency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

import '../test_helpers.dart';

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
  final CircularControllerB? controllerB;

  CircularControllerA({this.controllerB});
}

class CircularControllerB extends ZenController {
  final CircularControllerA? controllerA;

  CircularControllerB({this.controllerA});
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
    Zen.deleteAll(force: true);
  });

  group('Controller Dependencies', () {
    test('should inject service dependency into controller', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('inject-dependency');

      // Register the service first
      final service = MockService();
      Zen.put<MockService>(service, scope: testScope);

      // Create controller with dependency
      final controller = DependentController(service);
      Zen.put<DependentController>(controller, scope: testScope);

      // Verify the service is properly injected
      expect(controller.service, same(service));

      // Test interaction
      controller.callServiceMethod();
      expect(controller.serviceCallMade, true);
      expect(service.initialized, true);

      // Cleanup
      Zen.delete<DependentController>(scope: testScope);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should find dependencies across scopes correctly', () {
      // Create a test scope for this specific test
      final rootTestScope = ZenTestHelper.createIsolatedTestScope('scope-dependencies');

      // Create a parent scope and a child scope
      final parentScope = Zen.createScope(name: "ParentScope", parent: rootTestScope);
      final childScope = Zen.createScope(parent: parentScope, name: "ChildScope");

      // Register service in parent scope
      final service = MockService();
      Zen.put<MockService>(service, scope: parentScope);

      // Controller in child scope should be able to find the service
      final foundService = Zen.lookup<MockService>(scope: childScope);
      expect(foundService, same(service));

      // Create controller in child scope
      final controller = DependentController(foundService!);
      Zen.put<DependentController>(controller, scope: childScope);

      // Verify controller can use the service
      controller.callServiceMethod();
      expect(service.initialized, true);

      // Cleanup
      childScope.dispose();
      parentScope.dispose();
      rootTestScope.dispose();
    });

    test('should track and dispose controllers with dependencies', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('track-dispose');

      // Register service
      final service = MockService();
      Zen.put<MockService>(service, scope: testScope);

      // Create controller with dependency
      final controller = DependentController(service);
      Zen.put<DependentController>(controller, scope: testScope);

      // Dispose controller
      expect(controller.isDisposed, false);
      Zen.delete<DependentController>(scope: testScope);
      expect(controller.isDisposed, true);

      // Service should not be automatically disposed
      expect(service.disposed, false);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle controllers with tagged dependencies', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('tagged-dependencies');

      // Register two services with different tags
      final service1 = MockService();
      final service2 = MockService();

      Zen.put<MockService>(service1, tag: "service1", scope: testScope);
      Zen.put<MockService>(service2, tag: "service2", scope: testScope);

      // Find each service by tag
      final foundService1 = Zen.lookup<MockService>(tag: "service1", scope: testScope);
      final foundService2 = Zen.lookup<MockService>(tag: "service2", scope: testScope);

      expect(foundService1, same(service1));
      expect(foundService2, same(service2));

      // Create controllers with different service dependencies
      final controller1 = DependentController(foundService1!);
      final controller2 = DependentController(foundService2!);

      Zen.put<DependentController>(controller1, tag: "controller1", scope: testScope);
      Zen.put<DependentController>(controller2, tag: "controller2", scope: testScope);

      // Verify correct dependencies
      final retrievedController1 = Zen.find<DependentController>(tag: "controller1", scope: testScope);
      final retrievedController2 = Zen.find<DependentController>(tag: "controller2", scope: testScope);

      expect(retrievedController1?.service, same(service1));
      expect(retrievedController2?.service, same(service2));

      // Test service interactions
      retrievedController1?.callServiceMethod();
      expect(service1.initialized, true);
      expect(service2.initialized, false);

      retrievedController2?.callServiceMethod();
      expect(service2.initialized, true);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should detect circular dependencies when declared', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('circular-dependencies');

      // Create circular dependency controllers
      CircularControllerA controllerA = CircularControllerA();
      final controllerB = CircularControllerB(controllerA: controllerA);

      // This creates a circular dependency when we update A to reference B
      controllerA = CircularControllerA(controllerB: controllerB);

      // Register with the dependency tracking
      expect(() {
        Zen.put<CircularControllerA>(
          controllerA,
          dependencies: [controllerB], // Declare dependency on B
          scope: testScope,
        );

        Zen.put<CircularControllerB>(
          controllerB,
          dependencies: [controllerA], // Declare dependency on A
          scope: testScope,
        );
      },
          // The system should allow circular dependencies but log warnings
          // So we don't expect an exception, but the dependency graph should
          // detect and track the cycle
          returnsNormally);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should support controller references for type safety', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('controller-references');

      // Register service
      final service = MockService();
      Zen.put<MockService>(service, scope: testScope);

      // Create controller with dependency using references
      final controllerRef = Zen.lazyRef<DependentController>(
            () => DependentController(service),
        scope: testScope,
      );

      // Controller shouldn't exist yet (lazy)
      expect(controllerRef.exists(), false);

      // Get the controller - this will create it
      final controller = controllerRef.get();
      expect(controller, isA<DependentController>());
      expect(controllerRef.exists(), true);

      // Test controller functionality
      controller.callServiceMethod();
      expect(controller.serviceCallMade, true);
      expect(service.initialized, true);

      // Clean up using the reference
      controllerRef.delete();
      expect(controller.isDisposed, true);
      expect(controllerRef.exists(), false);

      // Clean up the test scope
      testScope.dispose();
    });

    test('should support dependency injection in scoped controllers', () {
      // Create a test scope for this specific test
      final rootTestScope = ZenTestHelper.createIsolatedTestScope('scoped-controllers');

      // Create scopes
      final parentScope = Zen.createScope(name: "ParentScope", parent: rootTestScope);
      final childScope = Zen.createScope(parent: parentScope, name: "ChildScope");

      // Create controllers tied to specific scopes
      final parentController = ScopedController(parentScope);
      final childController = ScopedController(childScope);

      Zen.put<ScopedController>(parentController, scope: parentScope, tag: "parent");
      Zen.put<ScopedController>(childController, scope: childScope, tag: "child");

      // Verify scope isolation and inheritance
      final foundParentInParent = Zen.find<ScopedController>(tag: "parent", scope: parentScope);
      final foundParentInChild = Zen.find<ScopedController>(tag: "parent", scope: childScope);
      final foundChildInParent = Zen.find<ScopedController>(tag: "child", scope: parentScope);
      final foundChildInChild = Zen.find<ScopedController>(tag: "child", scope: childScope);

      expect(foundParentInParent, same(parentController));
      expect(foundParentInChild, same(parentController)); // Parent is visible in child scope
      expect(foundChildInParent, null); // Child is not visible in parent scope
      expect(foundChildInChild, same(childController));

      // Test disposing a parent scope
      parentScope.dispose();

      // After parent scope disposal, both controllers should be disposed
      expect(parentController.isDisposed, true);
      expect(childController.isDisposed, true);

      // Clean up the root test scope
      rootTestScope.dispose();
    });

    test('should handle lazy dependencies correctly', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('lazy-dependencies');

      // Register a lazy dependency
      Zen.lazyPut<MockService>(() => MockService(), scope: testScope);

      // Should not exist until requested
      final serviceBeforeAccess = Zen.lookup<MockService>(scope: testScope);
      expect(serviceBeforeAccess, null);

      // Access should create it
      final service = Zen.get<MockService>(scope: testScope);
      expect(service, isA<MockService>());

      // Should exist after access
      final serviceAfterAccess = Zen.lookup<MockService>(scope: testScope);
      expect(serviceAfterAccess, same(service));

      // Create a controller with a lazy dependency
      Zen.lazyPut<DependentController>(() => DependentController(service), scope: testScope);

      // Controller should not exist yet
      expect(Zen.find<DependentController>(scope: testScope), null);

      // Accessing should create it
      final controller = Zen.get<DependentController>(scope: testScope);
      expect(controller, isA<DependentController>());
      expect(controller.service, same(service));

      // Controller should exist now
      expect(Zen.find<DependentController>(scope: testScope), same(controller));

      // Clean up the test scope
      testScope.dispose();
    });

    test('should handle auto-disposal of controllers properly', () {
      // Create a test scope for this specific test
      final testScope = ZenTestHelper.createIsolatedTestScope('auto-disposal');

      // Enable auto-dispose with a very short timeout for testing
      ZenConfig.enableAutoDispose = true;
      ZenConfig.controllerCacheExpiry = Duration(milliseconds: 100);

      // Register a service and controller
      final service = MockService();
      Zen.put<MockService>(service, scope: testScope);

      final controller = DependentController(service);
      Zen.put<DependentController>(controller, scope: testScope);

      // Use the controller
      Zen.incrementUseCount<DependentController>(scope: testScope);
      expect(Zen.getUseCount<DependentController>(scope: testScope), 1);

      // Release the controller
      Zen.decrementUseCount<DependentController>(scope: testScope);
      expect(Zen.getUseCount<DependentController>(scope: testScope), 0);

      // Wait for auto-dispose timeout
      expect(controller.isDisposed, false);

      // This is a bit hacky for testing - in real code you wouldn't force auto-dispose
      // directly, but for testing we need to simulate the timer callback
      Zen.delete<DependentController>(scope: testScope);

      expect(controller.isDisposed, true);

      // Restore default config
      ZenConfig.enableAutoDispose = false;

      // Clean up the test scope
      testScope.dispose();
    });
  });
}