import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class CounterController extends ZenController {
  int count = 0;
  bool disposeCalled = false;
  bool initCalled = false;

  CounterController() {
    onInit();
  }

  void increment() {
    count++;
    update();
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

class TestZenView extends ZenView<CounterController> {
  const TestZenView({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Count: ${controller.count}'),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
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

class TestReactiveZenView extends ZenView<CounterController> {
  const TestReactiveZenView({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ZenUpdater<CounterController>(
            builder: (context, controller) => Text('Count: ${controller.count}'),
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

class TaggedTestView extends ZenView<CounterController> {
  const TaggedTestView({super.key});

  @override
  String? get tag => 'custom_tag';

  @override
  Widget build(BuildContext context, CounterController controller) {
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

class ScopedView extends ZenView<CounterController> {
  const ScopedView({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
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
    ZenConfig.logLevel = ZenLogLevel.none;
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenView Widget Tests', () {
    testWidgets('should get controller from global DI', (tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(const MaterialApp(home: TestZenView()));

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Context API Count: 0'), findsOneWidget);
    });

    testWidgets('should allow controller interaction with manual updates', (tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(const MaterialApp(home: TestZenView()));

      expect(find.text('Count: 0'), findsOneWidget);

      controller.increment();
      expect(controller.count, 1);
      
      // UI doesn't auto-update because ZenView is stateless and we didn't use an Observer
      await tester.pump();
      expect(find.text('Count: 0'), findsOneWidget); 
    });

    testWidgets('should automatically update UI with ZenUpdater inside ZenView', (tester) async {
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      await tester.pumpWidget(const MaterialApp(home: TestReactiveZenView()));

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should find scoped controller via ZenScopeWidget.create', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<CounterController>(
            create: () => CounterController(),
            child: const TestZenView(),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.findOrNull<CounterController>(), isNull); // Ensures it's NOT in global scope
    });

    testWidgets('should create and find controller with tag', (tester) async {
      Zen.put<CounterController>(CounterController(), tag: 'custom_tag');
      
      await tester.pumpWidget(
        const MaterialApp(
          home: TaggedTestView(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should use ZenScopeWidget for explicit scope (correct V2 pattern)', (tester) async {
      final customScope = Zen.createScope(name: "CustomScope");
      final controller = CounterController()..count = 42;
      customScope.put<CounterController>(controller);

      // V2: wrap the view in ZenScopeWidget — do NOT pass scope directly to ZenView
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            scope: customScope,
            child: const ScopedView(),
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('should fail fast when controller not found', (tester) async {
      bool exceptionCaught = false;
      FlutterError.onError = (FlutterErrorDetails details) {
        exceptionCaught = true;
      };

      await tester.pumpWidget(const MaterialApp(home: TestZenView()));
      
      expect(exceptionCaught, isTrue);
      FlutterError.onError = FlutterError.dumpErrorToConsole;
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // initController — element-owned lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  group('ZenView.initController (element-owned lifecycle)', () {
    testWidgets('should create and own controller via initController', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SelfOwnedView(label: 'owned')),
      );
      await tester.pumpAndSettle(); // let onReady fire

      // View renders using its own controller — no global or scope registration needed
      expect(find.text('owned:0'), findsOneWidget);
      // Controller is NOT in global DI
      expect(Zen.findOrNull<CounterController>(), isNull);
    });

    testWidgets('should call onInit and onClose on owned controller', (tester) async {
      SelfOwnedController? capturedController;

      await tester.pumpWidget(
        MaterialApp(
          home: LifecycleTrackingView(onCreated: (c) => capturedController = c),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedController, isNotNull);
      expect(capturedController!.initCalled, isTrue);
      expect(capturedController!.disposeCalled, isFalse);

      // Remove from tree — should call onClose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(capturedController!.disposeCalled, isTrue);
    });

    testWidgets('should give each instance its own controller (multi-instance safe)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              Flexible(child: SelfOwnedView(label: 'A')),
              Flexible(child: SelfOwnedView(label: 'B')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both views render — each with their own controller starting at 0
      expect(find.text('A:0'), findsOneWidget);
      expect(find.text('B:0'), findsOneWidget);

      // Increment via the first view's button
      await tester.tap(find.byKey(const ValueKey('btn-A')));
      await tester.pump();

      // Only A updates — B remains isolated
      expect(find.text('A:1'), findsOneWidget);
      expect(find.text('B:0'), findsOneWidget);
    });

    testWidgets('initController takes priority over scope', (tester) async {
      // Register a DIFFERENT SelfOwnedController in scope — initController should win
      final scoped = SelfOwnedController()..count.value = 99;
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            scope: Zen.createScope(name: 'PriorityTest')..put<SelfOwnedController>(scoped),
            child: const SelfOwnedView(label: 'priority'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelfOwnedView creates its own controller starting at 0, not the scoped 99
      expect(find.text('priority:0'), findsOneWidget);
    });

    testWidgets('auto-scoped controller is accessible to child widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ParentOwningView()),
      );
      await tester.pumpAndSettle();

      // The child widget should be able to read the controller created by ParentOwningView
      expect(find.text('child found ctrl: 0'), findsOneWidget);
    });
  });
}

// ─── Test widget fixtures ──────────────────────────────────────────────────

/// Dedicated controller for element-owned tests.
/// Uses Rx<int> so ZenObserver can react without tree lookup.
class SelfOwnedController extends ZenController {
  final count = Rx<int>(0);
  bool initCalled = false;
  bool disposeCalled = false;

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

  void increment() => count.value++;
}

/// A ZenView that creates its own controller (no parent scope needed).
/// Uses ZenObserver + Rx<int> for reactive display — no tree lookup required.
class SelfOwnedView extends ZenView<SelfOwnedController> {
  final String label;
  const SelfOwnedView({required this.label, super.key});

  @override
  SelfOwnedController Function() get initController => SelfOwnedController.new;

  @override
  Widget build(BuildContext context, SelfOwnedController controller) {
    return Column(
      children: [
        // ZenObserver directly subscribes to the Rx value — no tree lookup needed
        ZenObserver(() => Text('$label:${controller.count.value}')),
        ElevatedButton(
          key: ValueKey('btn-$label'),
          onPressed: controller.increment,
          child: Text('Inc $label'),
        ),
      ],
    );
  }
}

/// A ZenView that captures its controller on creation for lifecycle assertions.
class LifecycleTrackingView extends ZenView<SelfOwnedController> {
  final void Function(SelfOwnedController) onCreated;
  const LifecycleTrackingView({required this.onCreated, super.key});

  @override
  SelfOwnedController Function() get initController => () {
    final c = SelfOwnedController();
    onCreated(c);
    return c;
  };

  @override
  Widget build(BuildContext context, SelfOwnedController controller) {
    return Text('lifecycle:${controller.count.value}');
  }
}

/// A ZenView that creates its own controller and expects a child widget to find it.
class ParentOwningView extends ZenView<SelfOwnedController> {
  const ParentOwningView({super.key});

  @override
  SelfOwnedController Function() get initController => SelfOwnedController.new;

  @override
  Widget build(BuildContext context, SelfOwnedController controller) {
    return const ChildConsumer();
  }
}

class ChildConsumer extends StatelessWidget {
  const ChildConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.controller<SelfOwnedController>();
    return Text('child found ctrl: ${ctrl.count.value}');
  }
}


