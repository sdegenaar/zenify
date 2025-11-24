// test/controllers/controller_lifecycle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller that tracks lifecycle events
class LifecycleController extends ZenController {
  final events = <String>[];
  final counter = 0.obs();

  void increment() {
    counter.value++;
  }

  @override
  void onInit() {
    events.add('onInit');
    super.onInit();
  }

  @override
  void onReady() {
    events.add('onReady');
    super.onReady();
  }

  @override
  void onClose() {
    events.add('onClose');
    super.onClose();
  }

  @override
  void onPause() {
    events.add('onPause');
    super.onPause();
  }

  @override
  void onResume() {
    events.add('onResume');
    super.onResume();
  }

  @override
  void onInactive() {
    events.add('onInactive');
    super.onInactive();
  }

  @override
  void onDetached() {
    events.add('onDetached');
    super.onDetached();
  }

  @override
  void onHidden() {
    events.add('onHidden');
    super.onHidden();
  }

  bool hasEvent(String event) => events.contains(event);
  int eventCount(String event) => events.where((e) => e == event).length;
}

// Simple screen with a controller
class TestScreen extends StatelessWidget {
  final String name;
  final ZenScope? scope;

  const TestScreen({required this.name, this.scope, super.key});

  @override
  Widget build(BuildContext context) {
    // Get controller from the specified scope or root scope
    final controller = scope?.find<LifecycleController>() ??
        Zen.findOrNull<LifecycleController>();

    // Handle case where controller is not found
    if (controller == null) {
      return const Center(child: Text('Controller not found'));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Screen $name')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() => Text('Counter: ${controller.counter.value}')),
            ElevatedButton(
              onPressed: controller.increment,
              child: const Text('Increment'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/next', arguments: name);
              },
              child: const Text('Navigate to Next Screen'),
            ),
          ],
        ),
      ),
    );
  }
}

// Test module for controller disposal test
class DisposableModule extends ZenModule {
  final LifecycleController controller;

  DisposableModule(this.controller);

  @override
  String get name => 'DisposableModule';

  @override
  void register(ZenScope scope) {
    scope.put<LifecycleController>(controller);
  }
}

void main() {
  group('Controller Lifecycle Integration', () {
    late LifecycleController rootController;
    late LifecycleController screenController;
    late ZenScope testScope;

    setUp(() {
      // Initialize WidgetsFlutterBinding for tests
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Zen system
      Zen.init();

      // Create an isolated test scope
      testScope = Zen.createScope(name: 'ControllerLifecycleTest');

      // Initialize controllers
      rootController = LifecycleController();
      screenController = LifecycleController();

      // Register global controller in root scope
      Zen.put<LifecycleController>(rootController, tag: 'root');
    });

    tearDown(() {
      // Ensure controllers are properly disposed
      if (!rootController.isDisposed) {
        rootController.dispose();
      }

      if (!screenController.isDisposed) {
        screenController.dispose();
      }

      // Dispose test scope
      if (!testScope.isDisposed) {
        testScope.dispose();
      }

      // Reset Zen system
      Zen.reset();
    });

    testWidgets('should properly initialize controllers with widgets',
        (WidgetTester tester) async {
      // Register screenController in the test scope
      testScope.put<LifecycleController>(screenController);

      // Build our app with testScope
      await tester.pumpWidget(
        MaterialApp(
          home: TestScreen(name: 'Home', scope: testScope),
        ),
      );

      // Let the dust settle (frames for onReady callbacks)
      await tester.pumpAndSettle();

      // Check that controllers were initialized properly
      expect(rootController.hasEvent('onInit'), isTrue);
      expect(rootController.hasEvent('onReady'), isTrue);
      expect(screenController.hasEvent('onInit'), isTrue);
      expect(screenController.hasEvent('onReady'), isTrue);

      // Verify counter starts at 0
      expect(find.text('Counter: 0'), findsOneWidget);

      // Tap the increment button
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify counter incremented
      expect(find.text('Counter: 1'), findsOneWidget);
    });

    testWidgets('should maintain controller state during navigation',
        (WidgetTester tester) async {
      // Create fresh controller for this test to avoid state leakage
      final navTestController = LifecycleController();

      // Register the controller in the test scope
      testScope.put<LifecycleController>(navTestController);

      // Build app with navigation
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => TestScreen(name: 'Home', scope: testScope),
            '/next': (context) {
              // Use same scope for next screen
              final prevScreenName =
                  ModalRoute.of(context)!.settings.arguments as String;
              return TestScreen(
                  name: 'Next from $prevScreenName', scope: testScope);
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      // Find the increment button by type rather than text
      final incrementButton = find.byType(ElevatedButton).first;

      // Tap the increment button
      await tester.tap(incrementButton);
      await tester.pump();

      expect(find.text('Counter: 1'), findsOneWidget);

      // Navigate to next screen
      await tester.tap(find.text('Navigate to Next Screen'));
      await tester.pumpAndSettle();

      // Verify we're on the next screen but counter state is preserved
      expect(find.text('Screen Next from Home'), findsOneWidget);
      expect(find.text('Counter: 1'), findsOneWidget);

      // Increment on second screen
      final incrementButtonOnNextScreen = find.byType(ElevatedButton).first;
      await tester.tap(incrementButtonOnNextScreen);
      await tester.pump();

      expect(find.text('Counter: 2'), findsOneWidget);

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify we're back on first screen with updated counter
      expect(find.text('Screen Home'), findsOneWidget);
      expect(find.text('Counter: 2'), findsOneWidget);

      // Controller should not have been re-initialized
      expect(navTestController.eventCount('onInit'), 1);
      expect(navTestController.eventCount('onReady'), 1);
    });

    testWidgets('should dispose controllers when widgets are removed',
        (WidgetTester tester) async {
      // Create a fresh controller specifically for this test
      final disposableController = LifecycleController();

      // Flag to control widget presence
      bool showWidget = true;

      // Build our app with a stateful wrapper to control child presence
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Lifecycle Test')),
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showWidget = !showWidget;
                        });
                      },
                      child: const Text('Toggle Widget'),
                    ),
                    if (showWidget)
                      Expanded(
                        child: ZenScopeWidget(
                          moduleBuilder: () =>
                              DisposableModule(disposableController),
                          child: const Center(child: Text('Scoped Widget')),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Wait for everything to settle
      await tester.pumpAndSettle();

      // Controller should be initialized but not disposed
      expect(disposableController.hasEvent('onInit'), isTrue);
      expect(disposableController.hasEvent('onReady'), isTrue);
      expect(disposableController.hasEvent('onClose'), isFalse);
      expect(disposableController.isDisposed, isFalse);

      // Toggle widget off to remove the scope
      await tester.tap(find.text('Toggle Widget'));
      await tester.pumpAndSettle();

      // When using the moduleBuilder approach, the widget should dispose the scope
      expect(disposableController.hasEvent('onClose'), isTrue);
      expect(disposableController.isDisposed, isTrue);
    });

    testWidgets('should handle app lifecycle events properly',
        (WidgetTester tester) async {
      // Create a controller that observes app lifecycle
      final lifecycleController = LifecycleController();

      // Register in test scope
      testScope.put<LifecycleController>(lifecycleController);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: TestScreen(name: 'Lifecycle', scope: testScope),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate app lifecycle events
      final binding = tester.binding;

      // Test pause event
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(lifecycleController.hasEvent('onPause'), isTrue);

      // Test resume event
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(lifecycleController.hasEvent('onResume'), isTrue);

      // Test inactive event
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(lifecycleController.hasEvent('onInactive'), isTrue);

      // Test detached event
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(lifecycleController.hasEvent('onDetached'), isTrue);

      // Test hidden event
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(lifecycleController.hasEvent('onHidden'), isTrue);
    });

    test('should track controller lifecycle events correctly', () async {
      final controller = LifecycleController();

      // Initially no events
      expect(controller.events, isEmpty);
      expect(controller.isInitialized, isFalse);
      expect(controller.isReady, isFalse);

      // Call onInit
      controller.onInit();
      expect(controller.hasEvent('onInit'), isTrue);
      expect(controller.isInitialized, isTrue);
      expect(controller.isReady, isFalse);

      // Call onReady
      controller.onReady();
      expect(controller.hasEvent('onReady'), isTrue);
      expect(controller.isReady, isTrue);

      // Call lifecycle events
      controller.onPause();
      controller.onResume();
      controller.onInactive();
      controller.onDetached();
      controller.onHidden();

      expect(controller.hasEvent('onPause'), isTrue);
      expect(controller.hasEvent('onResume'), isTrue);
      expect(controller.hasEvent('onInactive'), isTrue);
      expect(controller.hasEvent('onDetached'), isTrue);
      expect(controller.hasEvent('onHidden'), isTrue);

      // Dispose
      controller.dispose();
      expect(controller.hasEvent('onClose'), isTrue);
      expect(controller.isDisposed, isTrue);
    });

    test('should handle worker lifecycle with controller', () {
      final controller = LifecycleController();
      controller.onInit();

      // Create some workers
      final counter = ValueNotifier<int>(0);

      final everWorker = controller.ever(counter, (value) {
        // Worker callback
      });

      final onceWorker = controller.once(counter, (value) {
        // Worker callback
      });

      expect(everWorker.isActive, isTrue);
      expect(onceWorker.isActive, isTrue);

      // Pause all workers
      controller.pauseAllWorkers();
      expect(everWorker.isPaused, isTrue);
      expect(onceWorker.isPaused, isTrue);

      // Resume all workers
      controller.resumeAllWorkers();
      expect(everWorker.isActive, isTrue);
      expect(onceWorker.isActive, isTrue);

      // Get worker stats
      final stats = controller.getWorkerStats();
      expect(stats['total_active'], equals(2));
      expect(stats['total_paused'], equals(0));

      // Dispose controller should dispose workers
      controller.dispose();
      expect(everWorker.isDisposed, isTrue);
      expect(onceWorker.isDisposed, isTrue);
    });

    test('should handle scoped controller registration and lookup', () {
      final scope1 = Zen.createScope(name: 'Scope1');
      final scope2 = Zen.createScope(name: 'Scope2');

      final controller1 = LifecycleController();
      final controller2 = LifecycleController();

      // Register in different scopes
      scope1.put<LifecycleController>(controller1);
      scope2.put<LifecycleController>(controller2);

      // Find in correct scopes
      expect(scope1.find<LifecycleController>(), same(controller1));
      expect(scope2.find<LifecycleController>(), same(controller2));

      // Should not find in wrong scopes
      expect(scope1.findInThisScope<LifecycleController>(), same(controller1));
      expect(scope2.findInThisScope<LifecycleController>(), same(controller2));

      // Clean up
      scope1.dispose();
      scope2.dispose();

      expect(controller1.isDisposed, isTrue);
      expect(controller2.isDisposed, isTrue);
    });

    test('should handle controller effects correctly', () {
      final controller = LifecycleController();
      controller.onInit();

      // Create an effect
      final effect = controller.createEffect<String>(name: 'testEffect');
      expect(effect.name, equals('testEffect'));

      // Effect should be disposed when controller is disposed
      controller.dispose();
      expect(effect.isDisposed, isTrue);
    });

    test('should handle disposer functions correctly', () {
      final controller = LifecycleController();
      controller.onInit();

      bool disposerCalled = false;

      // Add a disposer
      controller.addDisposer(() {
        disposerCalled = true;
      });

      expect(disposerCalled, isFalse);

      // Dispose controller
      controller.dispose();

      expect(disposerCalled, isTrue);
      expect(controller.isDisposed, isTrue);
    });
  });
}
