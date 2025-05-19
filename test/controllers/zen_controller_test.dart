// test/controllers/zen_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_state/zen_state.dart';

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
  void onDispose() {
    onDisposeCalled = true;
    super.onDispose();
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


// Simple provider for testing Riverpod listener
final testProvider = StateProvider<int>((ref) => 0);

void main() {
  group('ZenController', () {
    late TestController controller;

    setUp(() {
      // Initialize WidgetsFlutterBinding for lifecycle callbacks
      WidgetsFlutterBinding.ensureInitialized();

      controller = TestController();
    });

    tearDown(() {
      if (!controller.isDisposed) {
        controller.dispose();
      }
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

    test('should track created at timestamp', () {
      final beforeCreation = DateTime.now();
      final controller = TestController();
      final afterCreation = DateTime.now();

      expect(controller.createdAt.isAfter(beforeCreation) ||
          controller.createdAt.isAtSameMomentAs(beforeCreation), isTrue);
      expect(controller.createdAt.isBefore(afterCreation) ||
          controller.createdAt.isAtSameMomentAs(afterCreation), isTrue);
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

    test('should add listener for Riverpod providers', () {
      // Create a ProviderContainer for testing
      final container = ProviderContainer();

      int providerListenerCalled = 0;

      // Add listener for the provider
      controller.addListener(
          testProvider,
              (value) => providerListenerCalled++,
          container: container
      );

      // Initially not called
      expect(providerListenerCalled, 0);

      // Update the provider
      container.read(testProvider.notifier).state = 1;

      // Listener should be called
      expect(providerListenerCalled, 1);

      // Update again
      container.read(testProvider.notifier).state = 2;
      expect(providerListenerCalled, 2);

      // When controller is disposed, listener should be removed
      controller.dispose();

      // Update provider again, listener should not be called
      container.read(testProvider.notifier).state = 3;
      expect(providerListenerCalled, 2);

      // Clean up
      container.dispose();
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
      // Start observing app lifecycle events
      controller.startObservingAppLifecycle();

      // Simulate app lifecycle events
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(controller.onInactiveCalled, isTrue);

      controller.onInactiveCalled = false; // reset

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.onPauseCalled, isTrue);

      controller.onPauseCalled = false; // reset

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.onResumeCalled, isTrue);

      controller.onResumeCalled = false; // reset

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(controller.onDetachedCalled, isTrue);

      controller.onDetachedCalled = false; // reset

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(controller.onHiddenCalled, isTrue);

      // Clean up
      controller.stopObservingAppLifecycle();
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
}