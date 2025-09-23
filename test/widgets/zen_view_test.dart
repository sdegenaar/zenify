// test/widgets/zen_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller
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
  void onClose() {
    disposeCalled = true;
    super.onClose();
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
          // Test BuildContext extension
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

// Test reactive ZenView with ZenBuilder (which handles reactivity automatically)
class TestReactiveZenView extends ZenView<CounterController> {
  const TestReactiveZenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Using ZenBuilder for reactivity - automatically rebuilds on controller.update()
          ZenBuilder<CounterController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

// Custom ZenView with createController
class CreateControllerTestView extends ZenView<CounterController> {
  const CreateControllerTestView({super.key});

  @override
  CounterController Function()? get createController =>
      () => CounterController();

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

// Custom ZenView with tag
class TaggedTestView extends ZenView<CounterController> {
  const TaggedTestView({super.key});

  @override
  String? get tag => 'custom_tag';

  @override
  CounterController Function()? get createController =>
      () => CounterController();

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

// Custom ZenView with scope
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

// Parent view for testing nested context
class ParentZenView extends ZenView<CounterController> {
  const ParentZenView({super.key});

  @override
  CounterController Function()? get createController =>
      () => CounterController();

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

// Context test view
class ContextTestView extends ZenView<CounterController> {
  const ContextTestView({super.key});

  @override
  CounterController Function()? get createController =>
      () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Count: ${controller.count}'),
          Builder(
            builder: (innerContext) {
              final contextController =
                  innerContext.controller<CounterController>();
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
    Zen.reset();
  });

  group('ZenView Widget Tests', () {
    testWidgets('should get controller from dependency injection',
        (WidgetTester tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Context API Count: 0'), findsOneWidget);
    });

    testWidgets('should allow controller interaction with manual updates',
        (WidgetTester tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(
        const MaterialApp(
          home: TestZenView(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      controller.increment();
      expect(controller.count, 1);
      expect(find.text('Count: 0'), findsOneWidget); // UI doesn't auto-update

      await tester.pump();
      expect(find.text('Count: 0'),
          findsOneWidget); // Still doesn't update without reactive wrapper
    });

    testWidgets('should automatically update UI with ZenBuilder in ZenView',
        (WidgetTester tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(
        const MaterialApp(
          home: TestReactiveZenView(), // Uses ZenBuilder internally
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to increment
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // UI should automatically update because of ZenBuilder
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should create controller using createController',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateControllerTestView(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.find<CounterController>(), isNotNull);
    });

    testWidgets('should create controller with tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaggedTestView(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.find<CounterController>(tag: 'custom_tag'), isNotNull);
    });

    testWidgets('should use controller from scope',
        (WidgetTester tester) async {
      final customScope = Zen.createScope(name: "CustomScope");
      final controller = CounterController();
      controller.count = 42;
      customScope.put<CounterController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: ScopedTestView(customScope),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('should handle error when controller not found',
        (WidgetTester tester) async {
      bool exceptionCaught = false;
      final originalOnError = FlutterError.onError;

      FlutterError.onError = (FlutterErrorDetails details) {
        exceptionCaught = true;
      };

      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: TestZenView(), // No controller registered
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      expect(exceptionCaught, isTrue);
    });

    testWidgets('should call controller lifecycle methods',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateControllerTestView(),
        ),
      );

      final controller = Zen.find<CounterController>();
      expect(controller.initCalled, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different widget'),
        ),
      );

      expect(Zen.find<CounterController>(), isNotNull);
    });

    testWidgets('should access controller via BuildContext extension',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContextTestView(),
        ),
      );

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

      expect(find.text('Parent: 0'), findsOneWidget);
      expect(find.text('Child: 0'), findsOneWidget);
    });
  });
}
