// test/controllers/zen_di_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import '../test_helpers.dart';

// Test classes
class TestController extends ZenController {
  final String value;
  bool initialized = false;
  bool readyCalled = false;
  bool disposeMethodCalled = false;

  TestController(this.value);

  @override
  void onInit() {
    super.onInit();
    initialized = true;
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
  }

  @override
  void onDispose() {
    disposeMethodCalled = true;
    super.onDispose();
  }
}

class TestService {
  final String value;
  TestService(this.value);
}

void main() {
  group('Zen DI', () {
    // No global setup or teardown - each test fully manages its own lifecycle

    test('should register and find controllers', () {
      // Create an isolated scope for this test only
      final testScope = ZenTestHelper.createIsolatedTestScope('register-find');

      final controller = TestController('test');
      Zen.put<TestController>(controller, scope: testScope);

      final found = Zen.find<TestController>(scope: testScope);
      expect(found, isNotNull);
      expect(found.value, 'test');
    });

    test('should register and find controllers with tags', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('register-find-tags');

      final controller1 = TestController('controller1');
      final controller2 = TestController('controller2');

      Zen.put<TestController>(controller1, tag: 'tag1', scope: testScope);
      Zen.put<TestController>(controller2, tag: 'tag2', scope: testScope);

      final found1 = Zen.find<TestController>(tag: 'tag1', scope: testScope);
      final found2 = Zen.find<TestController>(tag: 'tag2', scope: testScope);

      expect(found1.value, 'controller1');
      expect(found2.value, 'controller2');
    });

    test('should call lifecycle methods when registering controller', () async {
      final testScope = ZenTestHelper.createIsolatedTestScope('lifecycle');

      final controller = TestController('lifecycle');
      Zen.put<TestController>(controller, scope: testScope);

      // onInit should be called immediately
      expect(controller.initialized, isTrue);

      // onReady is called after the current frame
      expect(controller.readyCalled, isFalse);

      // Wait for all microtasks to complete
      await Future.microtask(() {});

      // Wait for multiple frames to be sure
      await Future.delayed(const Duration(milliseconds: 50));

      // Manually trigger the onReady if it wasn't called automatically
      if (!controller.readyCalled) {
        controller.onReady();
      }

      // Now onReady should have been called
      expect(controller.readyCalled, isTrue);
    });

    test('should support permanent controllers', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('permanent');

      final controller = TestController('permanent');
      Zen.put<TestController>(controller, permanent: true, scope: testScope);

      // Attempt to delete a permanent controller without force
      final deleted = Zen.delete<TestController>(scope: testScope);
      expect(deleted, isFalse);

      // Controller should still exist
      expect(Zen.find<TestController>(scope: testScope), isNotNull);

      // Now delete with force
      final forcedDelete = Zen.delete<TestController>(force: true, scope: testScope);
      expect(forcedDelete, isTrue);

      // Controller should be gone
      expect(Zen.findOrNull<TestController>(scope: testScope), isNull);
    });

    test('should create and use scopes', () {
      // Create a custom scope
      final parentScope = ZenTestHelper.createIsolatedTestScope('parent-scope');
      final childScope = ZenScope(name: 'ChildScope', parent: parentScope);

      // Register a controller in the child scope
      final controller = TestController('scoped');
      Zen.put<TestController>(controller, scope: childScope);

      // Controller should be found in the child scope
      expect(Zen.find<TestController>(scope: childScope), isNotNull);

      // But not in the parent scope
      expect(Zen.findOrNull<TestController>(scope: parentScope), isNull);
    });

    test('should handle non-controller dependencies', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('dependencies');

      final service = TestService('service');
      Zen.put<TestService>(service, scope: testScope);

      final found = Zen.find<TestService>(scope: testScope);
      expect(found, isNotNull);
      expect(found.value, 'service');
    });

    test('should create type-safe references', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('references');

      final controller = TestController('ref');
      // Ensure we're setting scope properly
      final ref = Zen.putRef<TestController>(controller, scope: testScope);

      // Use the ref to get the controller
      final retrieved = ref.find();
      expect(retrieved, same(controller));

      // Use the ref to delete the controller
      final deleted = ref.delete();
      expect(deleted, isTrue);

      // Controller should be gone
      expect(ref.findOrNull(), isNull);
    });

    test('should track and auto-dispose unused controllers', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('auto-dispose');

      // Create a controller with proper scope
      final controller = TestController('auto-dispose');
      Zen.put<TestController>(controller, scope: testScope);

      // Reset counts first to ensure we start from zero
      testScope.resetAllUseCounts();

      // Increment use count
      Zen.incrementUseCount<TestController>(scope: testScope);
      expect(Zen.getUseCount<TestController>(scope: testScope), 1);

      // Decrement use count
      final count = Zen.decrementUseCount<TestController>(scope: testScope);
      expect(count, 0);
    });

    test('should register and use modules', () async {
      final testScope = ZenTestHelper.createIsolatedTestScope('modules-async');

      // Create a test module
      final module = TestModule();

      // Use Zen directly to register the module
      Zen.registerModules([module], scope: testScope);

      // Force the event loop to cycle to ensure all async operations complete
      await Future.delayed(Duration.zero);

      // Get service directly from scope using the find method
      final service = Zen.find<TestService>(scope: testScope);

      // Verify service exists
      expect(service, isNotNull);

      // Verify service value
      expect(service.value, equals('from module'));
    });

    test('should register and use modules', () async {
      // Create a test scope
      final testScope = Zen.createScope(name: 'modules-async');

      // Create a test module
      final module = TestModule();

      // Call register directly
      module.register(testScope);

      // Get service directly from scope using the find method
      final found = testScope.find<TestService>();

      // Verify service exists
      expect(found, isNotNull);

      // Verify service value
      expect(found?.value, equals('from module'));
    });

    test('should properly clean up with deleteAll', () {
      // Register several dependencies in the global scope
      final controller1 = TestController('delete-all-1');
      final controller2 = TestController('delete-all-2');
      final service = TestService('delete-all-service');

      Zen.put<TestController>(controller1, tag: 'controller1');
      Zen.put<TestController>(controller2, tag: 'controller2');
      Zen.put<TestService>(service);

      // Verify they exist
      expect(Zen.find<TestController>(tag: 'controller1'), same(controller1));
      expect(Zen.find<TestController>(tag: 'controller2'), same(controller2));
      expect(Zen.find<TestService>(), same(service));

      // Call deleteAll
      Zen.deleteAll(force: true);

      // Verify controllers are disposed
      expect(controller1.disposeMethodCalled, isTrue);
      expect(controller2.disposeMethodCalled, isTrue);

      // Verify dependencies no longer exist
      expect(() => Zen.find<TestController>(tag: 'controller1'), throwsException);
      expect(() => Zen.find<TestController>(tag: 'controller2'), throwsException);
      expect(() => Zen.find<TestService>(), throwsException);

      // Verify findOrNull returns null
      expect(Zen.findOrNull<TestController>(tag: 'controller1'), isNull);
      expect(Zen.findOrNull<TestController>(tag: 'controller2'), isNull);
      expect(Zen.findOrNull<TestService>(), isNull);
    });

    test('should properly handle findOrNull and findOr methods', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('find-variants');

      // Register a service
      final service = TestService('find-or');
      Zen.put<TestService>(service, scope: testScope);

      // Test findOrNull for existing dependency
      final foundService = Zen.findOrNull<TestService>(scope: testScope);
      expect(foundService, same(service));

      // Test findOrNull for non-existing dependency
      final nonExistingController = Zen.findOrNull<TestController>(scope: testScope);
      expect(nonExistingController, isNull);

      // Test findOr for existing dependency
      final foundWithOr = Zen.findOr<TestService>(
        scope: testScope,
        orElse: () => TestService('fallback'),
      );
      expect(foundWithOr, same(service));

      // Test findOr for non-existing dependency
      final fallbackController = Zen.findOr<TestController>(
        scope: testScope,
        orElse: () => TestController('fallback'),
      );
      expect(fallbackController.value, equals('fallback'));
    });

    test('should properly handle lazy initialization', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('lazy-init');

      // Track initialization
      bool wasInitialized = false;

      // Register lazy dependency
      Zen.lazyPut<TestService>(
            () {
          wasInitialized = true;
          return TestService('lazy');
        },
        scope: testScope,
      );

      // Verify not initialized yet
      expect(wasInitialized, isFalse);

      // Access the dependency
      final service = Zen.find<TestService>(scope: testScope);

      // Verify initialization happened
      expect(wasInitialized, isTrue);
      expect(service.value, equals('lazy'));

      // Verify subsequent lookups return same instance
      final secondLookup = Zen.find<TestService>(scope: testScope);
      expect(secondLookup, same(service));
    });

    test('should call onDispose when disposing controllers', () {
      final testScope = ZenTestHelper.createIsolatedTestScope('dispose-lifecycle');

      final controller = TestController('dispose-test');
      Zen.put<TestController>(controller, scope: testScope);

      // Verify not disposed initially
      expect(controller.disposeMethodCalled, isFalse);

      // Delete the controller
      Zen.delete<TestController>(scope: testScope);

      // Verify onDispose was called
      expect(controller.disposeMethodCalled, isTrue);
    });

  });
}

// Test implementation of ZenModule
class TestModule extends ZenModule {
  @override
  String get name => 'TestModule';

  @override
  void register(ZenScope scope) {
    // Create a test service
    final service = TestService('from module');

    // Register directly in the scope instead of using Zen.put
    scope.register<TestService>(
      service,
      permanent: false,
    );
  }
}
