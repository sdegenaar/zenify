// test/widgets/zen_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller
class CounterController extends ZenController {
  int count = 0;

  void increment() {
    count++;
    update(); // Notify UI to update
  }
}

// Test ZenView implementation
class TestZenView extends ZenView<CounterController> {
  const TestZenView({Key? key}) : super(key: key);

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
        ],
      ),
    );
  }
}

// Test ZenViewReactive implementation
class TestZenViewReactive extends ZenViewReactiveBase<CounterController> {
  const TestZenViewReactive({Key? key}) : super(key: key);

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
  const CreateControllerTestView({Key? key}) : super(key: key);

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
  const TaggedTestView({Key? key}) : super(key: key);

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

  const ScopedTestView(this.customScope, {Key? key}) : super(key: key);

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
      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );
      await tester.pump();

      // Now the UI should reflect the updated state
      expect(find.text('Count: 1'), findsOneWidget);
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
  });
}