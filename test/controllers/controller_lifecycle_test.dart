// test/controllers/controller_lifecycle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_state/zen_state.dart';
import '../test_helpers.dart';

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
  void onDispose() {
    events.add('onDispose');
    super.onDispose();
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

  const TestScreen({required this.name, super.key});

  @override
  Widget build(BuildContext context) {
    // Get controller from the parent scope
    final scope = ZenScopeWidget.of(context);
    final controller = Zen.find<LifecycleController>(scope: scope);

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

void main() {
  group('Controller Lifecycle Integration', () {
    late LifecycleController rootController;
    late LifecycleController screenController;
    late ZenScope testScope;

    setUp(() {
      // Initialize WidgetsFlutterBinding for tests
      WidgetsFlutterBinding.ensureInitialized();

      // Clear any previous dependencies - do this BEFORE creating new controllers
      Zen.deleteAll(force: true);

      // Create an isolated test scope
      testScope = ZenTestHelper.createIsolatedTestScope('ControllerLifecycleTest');

      // Initialize controllers
      rootController = LifecycleController();
      screenController = LifecycleController();

      // Register global controller in test scope
      Zen.put<LifecycleController>(rootController, tag: 'root', scope: testScope);
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

      // Force clean up everything
      Zen.deleteAll(force: true);
    });

    testWidgets('should properly initialize controllers with widgets',
            (WidgetTester tester) async {
          // Register screenController in the test scope BEFORE creating the widget
          Zen.put<LifecycleController>(screenController, scope: testScope);

          // Build our app with testScope
          await tester.pumpWidget(
            MaterialApp(
              home: ZenScopeWidget(
                name: 'TestScope',
                scope: testScope, // Use the test scope directly
                child: const TestScreen(name: 'Home'),
              ),
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

          // IMPORTANT: Register the controller in the test scope BEFORE using it in widgets
          Zen.put<LifecycleController>(navTestController, scope: testScope);

          // Build app with navigation
          await tester.pumpWidget(
            MaterialApp(
              initialRoute: '/',
              routes: {
                '/': (context) => ZenScopeWidget(
                  name: 'HomeScope',
                  scope: testScope, // Use test scope directly
                  // Don't use the create parameter since we registered the controller already
                  child: const TestScreen(name: 'Home'),
                ),
                '/next': (context) => Builder(
                  builder: (context) {
                    // Use same controller as previous screen
                    final prevScreenName = ModalRoute.of(context)!.settings.arguments as String;
                    return ZenScopeWidget(
                      name: 'NextScope',
                      scope: testScope, // Use test scope directly
                      // Don't use create parameter here either
                      child: TestScreen(name: 'Next from $prevScreenName'),
                    );
                  },
                ),
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

          // Increment on second screen - again finding button by type
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
                              name: 'DisposableScope',
                              scope: testScope, // Use test scope as parent
                              create: () => disposableController,
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
          expect(disposableController.hasEvent('onDispose'), isFalse);
          expect(disposableController.isDisposed, isFalse);

          // Toggle widget off to remove the scope
          await tester.tap(find.text('Toggle Widget'));
          await tester.pumpAndSettle();

          // Controller should now be disposed
          expect(disposableController.hasEvent('onDispose'), isTrue);
          expect(disposableController.isDisposed, isTrue);
        });

    testWidgets('should handle app lifecycle events properly',
            (WidgetTester tester) async {
          // Create isolated scope for this test
          final testScope = ZenTestHelper.createIsolatedTestScope('lifecycle-test');

          // Create the controller for this test
          final lifecycleController = LifecycleController();

          // Register controller in the scope
          Zen.put<LifecycleController>(lifecycleController, scope: testScope);

          // Start observing app lifecycle - THIS IS THE KEY PART THAT WAS MISSING
          lifecycleController.startObservingAppLifecycle();

          // Build our app and widget tree
          await tester.pumpWidget(
            MaterialApp(
              home: ZenScopeWidget(
                name: 'LifecycleTestScope',
                scope: testScope,
                child: const TestScreen(name: 'Home'),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Simulate app lifecycle events
          WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);

          // Now the onPause event should be triggered
          expect(lifecycleController.hasEvent('onPause'), isTrue);

          // Reset for next test
          WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          expect(lifecycleController.hasEvent('onResume'), isTrue);

          // Cleanup
          lifecycleController.stopObservingAppLifecycle();
        });

    testWidgets('should support multiple controller scopes',
            (WidgetTester tester) async {
          // Create parent scope
          final parentScope = ZenTestHelper.createIsolatedTestScope('parent-scope');

          // Create child scope with parent reference - automatically establishes parent-child relationship
          final childScope = ZenScope(name: 'child-scope', parent: parentScope);

          // Create controllers for the test
          final parentController = LifecycleController();
          final childController = LifecycleController();

          // Register controllers in their respective scopes
          Zen.put<LifecycleController>(parentController, scope: parentScope);
          Zen.put<LifecycleController>(childController, scope: childScope);

          // Build a simple widget tree with both scopes
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: ZenScopeWidget(
                  scope: parentScope,
                  child: Builder(
                    builder: (context) {
                      // Access controller from parent scope
                      final parent = Zen.find<LifecycleController>(scope: ZenScopeWidget.of(context));

                      return Column(
                        children: [
                          Text('Parent: ${parent.hashCode}'),

                          // Child scope
                          ZenScopeWidget(
                            scope: childScope,
                            child: Builder(
                              builder: (context) {
                                // Access controller from child scope
                                final child = Zen.find<LifecycleController>(scope: ZenScopeWidget.of(context));

                                // Try to access parent controller through hierarchy
                                final parentFromChild = Zen.find<LifecycleController>(
                                    scope: ZenScopeWidget.of(context).parent
                                );

                                return Column(
                                  children: [
                                    Text('Child: ${child.hashCode}'),
                                    Text('Parent via child: ${parentFromChild.hashCode}'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Verify parent controller is accessible from parent scope
          expect(Zen.find<LifecycleController>(scope: parentScope), equals(parentController));

          // Verify child controller is accessible from child scope
          expect(Zen.find<LifecycleController>(scope: childScope), equals(childController));

          // Verify parent controller is accessible through hierarchy
          expect(Zen.find<LifecycleController>(scope: childScope.parent), equals(parentController));

          // Verify child controller is different from parent controller
          expect(childController, isNot(equals(parentController)));

          // Verify the text widgets show the different controllers
          expect(find.text('Parent: ${parentController.hashCode}'), findsOneWidget);
          expect(find.text('Child: ${childController.hashCode}'), findsOneWidget);
          expect(find.text('Parent via child: ${parentController.hashCode}'), findsOneWidget);
        });
  });
}