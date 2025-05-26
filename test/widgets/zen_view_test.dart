// test/widgets/zen_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller - defined outside of the test widget
class CounterController extends ZenController {
  int count = 0;
  bool disposeCalled = false;
  bool initCalled = false;

  CounterController() {
    onInit();
  }

  void increment() {
    count++;
    update(); // Notify UI to update
  }

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
  }

  @override
  void onDispose() {
    disposeCalled = true;
    super.onDispose();
  }
}

// Test ZenView implementation
class TestZenView extends ZenView<CounterController> {
  const TestZenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
          // Test BuildContext extension directly in the test view
          Builder(
            builder: (innerContext) {
              final ctrl = innerContext.controller<CounterController>();
              return Text('Context API Count: ${ctrl.count}');
            },
          ),
        ],
      ),
    );
  }
}

// Test ZenViewReactive implementation
class TestZenViewReactive extends ZenViewReactiveBase<CounterController> {
  const TestZenViewReactive({super.key});

  @override
  Widget buildWithController(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Custom ZenView with createController implementation
class CreateControllerTestView extends ZenView<CounterController> {
  const CreateControllerTestView({super.key});

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Custom ZenView with tag implementation
class TaggedTestView extends ZenView<CounterController> {
  const TaggedTestView({super.key});

  @override
  String? get tag => 'custom_tag';

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Custom ZenView with scope implementation
class ScopedTestView extends ZenView<CounterController> {
  final ZenScope customScope;

  const ScopedTestView(this.customScope, {super.key});

  @override
  ZenScope? get scope => customScope;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Custom ZenView with manual controller disposal
class DisposableTestView extends ZenView<CounterController> {
  const DisposableTestView({super.key});

  @override
  bool get disposeControllerOnRemove => true;

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Parent view for testing nested context
class ParentZenView extends ZenView<CounterController> {
  const ParentZenView({super.key});

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Parent: ${controller.count}'),
        const ChildZenView(),
      ],
    );
  }
}

// Child view for testing nested context
class ChildZenView extends ZenView<CounterController> {
  const ChildZenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('Child: ${controller.count}');
  }
}

// Test view with custom reactive behavior
class CustomReactiveView extends ZenViewReactiveBase<CounterController> {
  const CustomReactiveView({super.key});

  @override
  bool get disposeControllerOnRemove => true;

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget buildWithController(BuildContext context, CounterController controller) {
    return Text('Reactive Count: ${controller.count}');
  }
}

// Custom ZenView that tests context.controller()
class ContextTestView extends ZenView<CounterController> {
  const ContextTestView({super.key});

  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          Builder(
            builder: (innerContext) {
              // Access controller through context
              final contextController = innerContext.controller<CounterController>();
              return Text('Context API Count: ${contextController.count}');
            },
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.enableDebugLogs = false;
  });

  tearDown(() {
    Zen.deleteAll(force: true);
  });

  group('ZenView Widget Tests', () {
    testWidgets('should get controller from dependency injection', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );

      // Verify the view shows the controller's initial value
      expect(find.text('Count: 0'), findsOneWidget);

      // Also verify the context access works
      expect(find.text('Context API Count: 0'), findsOneWidget);
    });

    testWidgets('should allow controller interaction with manual updates', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Increment controller directly
      controller.increment();

      // Verify controller state changed but UI hasn't updated yet
      expect(controller.count, 1);
      expect(find.text('Count: 0'), findsOneWidget); // UI still shows old value

      // Rebuild UI
      await tester.pump();

      // UI should STILL show the old value because this is not a reactive view
      expect(find.text('Count: 0'), findsOneWidget);

      // To actually update the UI in a non-reactive view, we would need to use Obs
      // or swap the widget with a reactive one that has the updated value
    });

    testWidgets('should automatically update UI with ZenViewReactive', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget using ZenViewReactive
      await tester.pumpWidget(
        MaterialApp(
          home: ZenViewReactive<CounterController>(
            buildWithController: (context, controller) {
              return Scaffold(
                body: Column(
                  children: [
                    Text('Count: ${controller.count}'),
                    ElevatedButton(
                      onPressed: controller.increment,
                      child: const Text('Increment'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to increment
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // UI should automatically update
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('TestZenViewReactive should automatically update UI', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenViewReactive(),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to increment
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // UI should automatically update
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should create controller using createController', (WidgetTester tester) async {
      // Build widget without registering a controller first
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateControllerTestView(),
        ),
      );

      // Verify a controller was created
      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.find<CounterController>(), isNotNull);
    });

    testWidgets('should create controller with tag', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TaggedTestView(),
        ),
      );

      // Verify a controller with tag was created
      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.find<CounterController>(tag: 'custom_tag'), isNotNull);
    });

    testWidgets('should use controller from scope', (WidgetTester tester) async {
      // Create a scope
      final customScope = Zen.createScope(name: "CustomScope");

      // Register a controller in the scope with non-default value
      final controller = CounterController();
      controller.count = 42;
      Zen.put<CounterController>(controller, scope: customScope);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: ScopedTestView(customScope),
        ),
      );

      // Verify the view is using the controller from the scope
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('should handle error when controller not found', (WidgetTester tester) async {
      // This test expects an exception
      bool exceptionCaught = false;

      // Use FlutterError.onError to capture the error
      final originalOnError = FlutterError.onError;

      FlutterError.onError = (FlutterErrorDetails details) {
        exceptionCaught = true;
      };

      try {
        // Build widget without registering a controller or providing createController
        await tester.pumpWidget(
          const MaterialApp(
            home: TestZenView(), // No controller registered
          ),
        );

        // The framework will report the error after this point
        await tester.pumpAndSettle();
      } finally {
        // Restore original error handler
        FlutterError.onError = originalOnError;
      }

      // Verify that an exception was caught
      expect(exceptionCaught, isTrue);
    });

    testWidgets('should call controller lifecycle methods', (WidgetTester tester) async {
      // Build widget that creates its own controller
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateControllerTestView(),
        ),
      );

      // Get the controller
      final controller = Zen.find<CounterController>();

      // Verify onInit was called
      expect(controller.initCalled, isTrue);

      // Replace with a different widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different widget'),
        ),
      );

      // Controller should still exist as disposeControllerOnRemove is not set
      expect(Zen.find<CounterController>(), isNotNull);
    });

    testWidgets('should reuse the same controller instance between views', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      controller.count = 5;
      Zen.put<CounterController>(controller);

      // Build first widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );

      // Verify it uses the existing controller
      expect(find.text('Count: 5'), findsOneWidget);
      expect(find.text('Context API Count: 5'), findsOneWidget);

      // Update the controller
      controller.count = 10;

      // Replace with a different ZenView that uses the same controller type
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenViewReactive(), // Different view class, same controller type
        ),
      );
      await tester.pump();

      // Should still show the updated count from the same controller instance
      expect(find.text('Count: 10'), findsOneWidget);
    });

    testWidgets('should dispose controller when view is removed with disposeControllerOnRemove set',
            (WidgetTester tester) async {
          // Build widget with disposeControllerOnRemove set to true
          await tester.pumpWidget(
            const MaterialApp(
              home: DisposableTestView(),
            ),
          );

          // Verify a controller was created
          final controller = Zen.find<CounterController>();
          expect(controller, isNotNull);
          expect(controller.disposeCalled, isFalse);

          // Replace with different widget to trigger disposal
          await tester.pumpWidget(
            const MaterialApp(
              home: Text('Different widget'),
            ),
          );

          // Now controller should be gone from the registry
          expect(Zen.findOrNull<CounterController>(), isNull);
        });

    testWidgets('should access controller via BuildContext extension',
            (WidgetTester tester) async {
          // Use the ContextTestView which has a nested builder that uses the context extension
          await tester.pumpWidget(
            const MaterialApp(
              home: ContextTestView(),
            ),
          );

          // Verify both the direct access and context extension access work
          expect(find.text('Count: 0'), findsOneWidget);
          expect(find.text('Context API Count: 0'), findsOneWidget);
        });

    testWidgets('should handle nested ZenViews with correct context stacking',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: ParentZenView(),
            ),
          );

          // Verify both parent and child can access their controllers
          expect(find.text('Parent: 0'), findsOneWidget);
          expect(find.text('Child: 0'), findsOneWidget);
        });

    testWidgets('ZenViewReactiveBase should dispose controller when removed if configured to do so',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: CustomReactiveView(),
            ),
          );

          // Verify controller exists
          final controller = Zen.find<CounterController>();
          expect(controller, isNotNull);

          // Replace with different widget
          await tester.pumpWidget(
            const MaterialApp(
              home: Text('Different widget'),
            ),
          );

          // Controller should be gone
          expect(Zen.findOrNull<CounterController>(), isNull);
        });
  });
}