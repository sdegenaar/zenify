// test/controllers/zen_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zenify/zenify.dart';

// Test controller implementation
class TestController extends ZenController {
  bool onInitCalled = false;
  bool onReadyCalled = false;
  bool onDisposeCalled = false;
  bool onPauseCalled = false;
  bool onResumeCalled = false;
  bool onInactiveCalled = false;
  bool onDetachedCalled = false;
  bool onHiddenCalled = false;

  int customDisposerCalled = 0;
  int value = 0;
  int updateCallCount = 0;

  void increment() {
    value++;
    update();
  }

  void incrementWithId(String id) {
    value++;
    update([id]);
  }

  @override
  void onInit() {
    // Check if already initialized using the parent class's flag
    if (isInitialized) {
      // Don't update onInitCalled because we're skipping the init logic
      super.onInit(); // This is a no-op if already initialized
      return;
    }

    // If we get here, we're actually going to execute the init logic
    onInitCalled = true;
    super.onInit();
  }

  @override
  void onReady() {
    // Check if already ready using the parent class's flag
    if (isReady) {
      // Don't update onReadyCalled because we're skipping the ready logic
      super.onReady(); // This is a no-op if already ready
      return;
    }

    // If we get here, we're actually going to execute the ready logic
    onReadyCalled = true;
    super.onReady();
  }

  @override
  void onClose() {
    onDisposeCalled = true;
    super.onClose();
  }

  @override
  void onPause() {
    onPauseCalled = true;
    super.onPause();
  }

  @override
  void onResume() {
    onResumeCalled = true;
    super.onResume();
  }

  @override
  void onInactive() {
    onInactiveCalled = true;
    super.onInactive();
  }

  @override
  void onDetached() {
    onDetachedCalled = true;
    super.onDetached();
  }

  @override
  void onHidden() {
    onHiddenCalled = true;
    super.onHidden();
  }

  void addTestDisposer() {
    addDisposer(() {
      customDisposerCalled++;
    });
  }
}

// Additional test controller for multiple instances
class AnotherTestController extends ZenController {
  final String name;
  AnotherTestController(this.name);
}

void main() {
  group('ZenController', () {
    late TestController controller;

    setUp(() {
      // Initialize WidgetsFlutterBinding for lifecycle callbacks
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Zen
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.development);

      controller = TestController();
    });

    tearDown(() {
      if (!controller.isDisposed) {
        controller.dispose();
      }
      // Reset Zen
      Zen.reset();
    });

    test('should call lifecycle methods in the right order', () async {
      // Reset the state for a clean test
      controller.onInitCalled = false;

      // Call init manually (normally done by Zen.put)
      controller.onInit();

      // onInit should be called and isInitialized flag set
      expect(controller.onInitCalled, isTrue);
      expect(controller.isInitialized, isTrue);
      expect(controller.onReadyCalled, isFalse);
      expect(controller.isReady, isFalse);

      // Call ready manually
      controller.onReady();

      // onReady should be called and isReady flag set
      expect(controller.onReadyCalled, isTrue);
      expect(controller.isReady, isTrue);

      // Verify that calling lifecycle methods multiple times doesn't re-execute their logic
      // This is essential to prevent duplicate initialization and resource allocation
      controller.onInitCalled = false;
      controller.onReadyCalled = false;

      controller.onInit();
      controller.onReady();

      expect(controller.onInitCalled, isFalse);
      expect(controller.onReadyCalled, isFalse);
    });

    test('should work with ZenScope registration and tagged lookup', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'controller-tag-test');

      // Create multiple controllers
      final controllerA = TestController();
      final controllerB = TestController();
      final controllerC = TestController();

      testScope.put<TestController>(controllerA, tag: 'A');
      testScope.put<TestController>(controllerB, tag: 'B');
      testScope.put<TestController>(controllerC);

      // Test tagged lookups
      final foundA = testScope.find<TestController>(tag: 'A');
      final foundB = testScope.find<TestController>(tag: 'B');
      final foundC = testScope.find<TestController>();

      // Verify tagged controllers are found
      expect(foundA, same(controllerA));
      expect(foundB, same(controllerB));
      expect(foundC, same(controllerC));

      // Test findAllOfType
      final allControllers = testScope.findAllOfType<TestController>();

      expect(allControllers.length, 3);
      expect(
          allControllers, containsAll([controllerA, controllerB, controllerC]));

      // Verify all controllers were auto-initialized
      expect(controllerA.isInitialized, isTrue);
      expect(controllerA.isReady, isTrue);
      expect(controllerB.isInitialized, isTrue);
      expect(controllerB.isReady, isTrue);
      expect(controllerC.isInitialized, isTrue);
      expect(controllerC.isReady, isTrue);

      // Clean up
      testScope.dispose();
    });

    test('should work with different controller types and tags', () {
      // Create a test scope
      final testScope = Zen.createScope(name: 'multi-type-test');

      // Create different types of controllers
      final testController1 = TestController();
      final testController2 = TestController();
      final anotherController1 = AnotherTestController('first');
      final anotherController2 = AnotherTestController('second');

      // Register with different tags
      testScope.put<TestController>(testController1, tag: 'test1');
      testScope.put<TestController>(testController2, tag: 'test2');
      testScope.put<AnotherTestController>(anotherController1, tag: 'another1');
      testScope.put<AnotherTestController>(anotherController2, tag: 'another2');

      // Test findAllOfType for each type
      final allTestControllers = testScope.findAllOfType<TestController>();
      final allAnotherControllers =
          testScope.findAllOfType<AnotherTestController>();
      final allZenControllers = testScope.findAllOfType<ZenController>();

      expect(allTestControllers.length, 2);
      expect(allAnotherControllers.length, 2);
      expect(
          allZenControllers.length, 4); // All controllers extend ZenController

      expect(
          allTestControllers, containsAll([testController1, testController2]));
      expect(allAnotherControllers,
          containsAll([anotherController1, anotherController2]));

      // Clean up
      testScope.dispose();
    });

    test('should track created at timestamp', () {
      final beforeCreation = DateTime.now();
      final controller = TestController();
      final afterCreation = DateTime.now();

      expect(
          controller.createdAt.isAfter(beforeCreation) ||
              controller.createdAt.isAtSameMomentAs(beforeCreation),
          isTrue);
      expect(
          controller.createdAt.isBefore(afterCreation) ||
              controller.createdAt.isAtSameMomentAs(afterCreation),
          isTrue);
    });

    test('should execute disposers when controller is disposed', () {
      controller.addTestDisposer();
      controller.addTestDisposer();

      expect(controller.customDisposerCalled, 0);
      expect(controller.isDisposed, isFalse);

      controller.dispose();

      expect(controller.customDisposerCalled, 2);
      expect(controller.isDisposed, isTrue);
      expect(controller.onDisposeCalled, isTrue);

      // Disposing an already disposed controller should not run disposers again
      controller.customDisposerCalled = 0;
      controller.dispose();
      expect(controller.customDisposerCalled, 0);
    });

    test('should add and remove update listeners', () {
      int updateCount1 = 0;
      int updateCount2 = 0;

      callback1() => updateCount1++;
      callback2() => updateCount2++;

      // Register listeners
      controller.addUpdateListener('id1', callback1);
      controller.addUpdateListener('id2', callback2);

      // Call update, all listeners should be notified
      controller.update();
      expect(updateCount1, 1);
      expect(updateCount2, 1);

      // Call update with specific id
      controller.update(['id1']);
      expect(updateCount1, 2);
      expect(updateCount2, 1); // id2 not updated

      // Remove listener and update again
      controller.removeUpdateListener('id1', callback1);
      controller.update();
      expect(updateCount1, 2); // id1 no longer receiving updates
      expect(updateCount2, 2); // id2 still receiving updates

      // Remove last listener and update
      controller.removeUpdateListener('id2', callback2);
      controller.update();
      expect(updateCount1, 2);
      expect(updateCount2, 2);
    });

    test('should handle convenience methods for updating', () {
      int updateCount = 0;

      // Add listener
      controller.addUpdateListener('test', () => updateCount++);

      // Use increment which calls update()
      controller.increment();
      expect(controller.value, 1);
      expect(updateCount, 1);

      // Use incrementWithId which calls update([id])
      controller.incrementWithId('test');
      expect(controller.value, 2);
      expect(updateCount, 2);

      // Use incrementWithId with a different id
      controller.incrementWithId('other');
      expect(controller.value, 3);
      expect(updateCount, 2); // 'test' listener not called
    });

    test('should track disposers correctly', () {
      final disposer1Called = ValueNotifier<bool>(false);
      final disposer2Called = ValueNotifier<bool>(false);

      // Add two disposers
      controller.addDisposer(() => disposer1Called.value = true);
      controller.addDisposer(() => disposer2Called.value = true);

      // Initially neither called
      expect(disposer1Called.value, isFalse);
      expect(disposer2Called.value, isFalse);

      // Dispose controller
      controller.dispose();

      // Both disposers should be called
      expect(disposer1Called.value, isTrue);
      expect(disposer2Called.value, isTrue);

      // Clean up
      disposer1Called.dispose();
      disposer2Called.dispose();
    });

    test('should call application lifecycle methods', () {
      // Register controller so ZenLifecycleManager knows about it and can propagate events
      Zen.put(controller);

      // Simulate app lifecycle events
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(controller.onInactiveCalled, isTrue);

      controller.onInactiveCalled = false; // reset

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.onPauseCalled, isTrue);

      controller.onPauseCalled = false; // reset

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.onResumeCalled, isTrue);

      controller.onResumeCalled = false; // reset

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(controller.onDetachedCalled, isTrue);

      controller.onDetachedCalled = false; // reset

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(controller.onHiddenCalled, isTrue);
    });

    test('should not throw when disposing controller twice', () {
      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
    });

    test('should not throw when adding disposer to disposed controller', () {
      controller.dispose();
      expect(() => controller.addDisposer(() {}), returnsNormally);
    });

    test('should clear update listeners when controller is disposed', () {
      int updateCount = 0;
      controller.addUpdateListener('test', () => updateCount++);

      controller.update();
      expect(updateCount, 1);

      controller.dispose();

      // After disposal, update should not notify listeners
      controller.update();
      expect(updateCount, 1); // still 1, not incremented
    });
  });

  // ============================================================================
  // AUTOMATIC CHILD CONTROLLER TRACKING TESTS
  // ============================================================================

  group('ZenController - Automatic Child Tracking', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      Zen.testMode();
      Zen.clearQueryCache();
    });

    tearDown(() {
      Zen.reset();
    });

    test('should automatically track ZenQuery created in onInit', () {
      // Controller that creates a query in onInit
      final controller = _ControllerWithQuery();

      // Manually call onInit to trigger tracking
      controller.onInit();

      // Verify query was created
      expect(controller.userQuery, isNotNull);
      expect(controller.userQuery!.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Verify query was automatically disposed
      expect(controller.userQuery!.isDisposed, isTrue);
    });

    test('should automatically track multiple queries created in onInit', () {
      final controller = _ControllerWithMultipleQueries();

      controller.onInit();

      // Verify all queries were created
      expect(controller.userQuery, isNotNull);
      expect(controller.postsQuery, isNotNull);
      expect(controller.commentsQuery, isNotNull);

      // All should be alive
      expect(controller.userQuery!.isDisposed, isFalse);
      expect(controller.postsQuery!.isDisposed, isFalse);
      expect(controller.commentsQuery!.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // All queries should be disposed
      expect(controller.userQuery!.isDisposed, isTrue);
      expect(controller.postsQuery!.isDisposed, isTrue);
      expect(controller.commentsQuery!.isDisposed, isTrue);
    });

    test('should automatically track ZenStreamQuery created in onInit', () {
      final controller = _ControllerWithStreamQuery();

      controller.onInit();

      // Verify stream query was created
      expect(controller.notificationStream, isNotNull);
      expect(controller.notificationStream!.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Verify stream query was automatically disposed
      expect(controller.notificationStream!.isDisposed, isTrue);
    });

    test('should automatically track ZenMutation created in onInit', () {
      final controller = _ControllerWithMutation();

      controller.onInit();

      // Verify mutation was created
      expect(controller.updateUserMutation, isNotNull);
      expect(controller.updateUserMutation!.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Verify mutation was automatically disposed
      expect(controller.updateUserMutation!.isDisposed, isTrue);
    });

    test('should NOT automatically track queries created in constructor', () {
      final controller = _ControllerWithConstructorQuery();

      // Query was created in constructor, not in onInit
      expect(controller.userQuery, isNotNull);
      expect(controller.userQuery.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Query should NOT be automatically disposed (not tracked)
      expect(controller.userQuery.isDisposed, isFalse);

      // Clean up manually
      controller.userQuery.dispose();
    });

    test('should support manual tracking via trackController', () {
      final controller = _ControllerWithManualTracking();

      // Query was manually tracked in constructor
      expect(controller.userQuery, isNotNull);
      expect(controller.userQuery.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Query SHOULD be disposed (manually tracked)
      expect(controller.userQuery.isDisposed, isTrue);
    });

    test('should track nested child controllers', () {
      final controller = _ControllerWithNestedController();

      controller.onInit();

      // Verify child controller was created and tracked
      expect(controller.childController, isNotNull);
      expect(controller.childController!.isDisposed, isFalse);

      // Verify child's query was created
      expect(controller.childController!.userQuery, isNotNull);
      expect(controller.childController!.userQuery!.isDisposed, isFalse);

      // Dispose parent controller
      controller.dispose();

      // Child controller should be disposed
      expect(controller.childController!.isDisposed, isTrue);

      // Child's query should also be disposed
      expect(controller.childController!.userQuery!.isDisposed, isTrue);
    });

    test('should not double-dispose tracked controllers', () {
      final controller = _ControllerWithQuery();

      controller.onInit();

      final query = controller.userQuery!;
      expect(query.isDisposed, isFalse);

      // Dispose controller (should dispose query)
      controller.dispose();
      expect(query.isDisposed, isTrue);

      // Dispose query again (should not throw)
      expect(() => query.dispose(), returnsNormally);
      expect(query.isDisposed, isTrue);
    });

    test('should handle mixed automatic and manual tracking', () {
      final controller = _ControllerWithMixedTracking();

      controller.onInit();

      // Both queries should be alive
      expect(controller.autoQuery, isNotNull);
      expect(controller.manualQuery, isNotNull);
      expect(controller.autoQuery!.isDisposed, isFalse);
      expect(controller.manualQuery!.isDisposed, isFalse);

      // Dispose controller
      controller.dispose();

      // Both should be disposed
      expect(controller.autoQuery!.isDisposed, isTrue);
      expect(controller.manualQuery!.isDisposed, isTrue);
    });

    test('should not track queries created outside controller context', () {
      // Create query outside any controller
      final standaloneQuery = ZenQuery<String>(
        queryKey: 'standalone',
        fetcher: (_) async => 'data',
      );

      expect(standaloneQuery.isDisposed, isFalse);

      // Creating a controller and disposing it should not affect standalone query
      final controller = TestController();
      controller.onInit();
      controller.dispose();

      // Standalone query should still be alive
      expect(standaloneQuery.isDisposed, isFalse);

      // Clean up
      standaloneQuery.dispose();
    });
  });
}

// ============================================================================
// TEST CONTROLLERS FOR AUTOMATIC TRACKING TESTS
// ============================================================================

class _ControllerWithQuery extends ZenController {
  ZenQuery<String>? userQuery;

  @override
  void onInit() {
    super.onInit();
    // This query should be automatically tracked
    userQuery = ZenQuery<String>(
      queryKey: 'user:123',
      fetcher: (_) async => 'John Doe',
    );
  }
}

class _ControllerWithMultipleQueries extends ZenController {
  ZenQuery<String>? userQuery;
  ZenQuery<List<String>>? postsQuery;
  ZenQuery<List<String>>? commentsQuery;

  @override
  void onInit() {
    super.onInit();
    userQuery = ZenQuery<String>(
      queryKey: 'user',
      fetcher: (_) async => 'User',
    );
    postsQuery = ZenQuery<List<String>>(
      queryKey: 'posts',
      fetcher: (_) async => ['Post 1', 'Post 2'],
    );
    commentsQuery = ZenQuery<List<String>>(
      queryKey: 'comments',
      fetcher: (_) async => ['Comment 1'],
    );
  }
}

class _ControllerWithStreamQuery extends ZenController {
  ZenStreamQuery<String>? notificationStream;

  @override
  void onInit() {
    super.onInit();
    notificationStream = ZenStreamQuery<String>(
      queryKey: 'notifications',
      streamFn: () => Stream.value('notification'),
      autoSubscribe: false,
    );
  }
}

class _ControllerWithMutation extends ZenController {
  ZenMutation<String, String>? updateUserMutation;

  @override
  void onInit() {
    super.onInit();
    updateUserMutation = ZenMutation<String, String>(
      mutationFn: (name) async => 'Updated: $name',
    );
  }
}

class _ControllerWithConstructorQuery extends ZenController {
  late final ZenQuery<String> userQuery;

  _ControllerWithConstructorQuery() {
    // Created in constructor - NOT automatically tracked
    userQuery = ZenQuery<String>(
      queryKey: 'user',
      fetcher: (_) async => 'User',
    );
  }
}

class _ControllerWithManualTracking extends ZenController {
  late final ZenQuery<String> userQuery;

  _ControllerWithManualTracking() {
    userQuery = ZenQuery<String>(
      queryKey: 'user',
      fetcher: (_) async => 'User',
    );
    // Manually track it
    trackController(userQuery);
  }
}

class _ControllerWithNestedController extends ZenController {
  _ControllerWithQuery? childController;

  @override
  void onInit() {
    super.onInit();
    // Create child controller in onInit - should be automatically tracked
    childController = _ControllerWithQuery();
    childController!.onInit();
  }
}

class _ControllerWithMixedTracking extends ZenController {
  ZenQuery<String>? autoQuery;
  ZenQuery<String>? manualQuery;

  _ControllerWithMixedTracking() {
    // Manual tracking in constructor
    manualQuery = ZenQuery<String>(
      queryKey: 'manual',
      fetcher: (_) async => 'Manual',
    );
    trackController(manualQuery!);
  }

  @override
  void onInit() {
    super.onInit();
    // Automatic tracking in onInit
    autoQuery = ZenQuery<String>(
      queryKey: 'auto',
      fetcher: (_) async => 'Auto',
    );
  }
}
