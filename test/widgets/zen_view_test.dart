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
    testWidgets('should get controller from local DI', (tester) async {
      final controller = CounterController();

      await tester.pumpWidget(MaterialApp(
        home: ZenProvider.create(
          create: () => controller,
          child: const TestZenView(),
        ),
      ));

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Context API Count: 0'), findsOneWidget);
    });

    testWidgets('should allow controller interaction with manual updates',
        (tester) async {
      final controller = CounterController();

      await tester.pumpWidget(MaterialApp(
        home: ZenProvider.create(
          create: () => controller,
          child: const TestZenView(),
        ),
      ));

      expect(find.text('Count: 0'), findsOneWidget);

      controller.increment();
      expect(controller.count, 1);

      // UI doesn't auto-update because ZenView is stateless and we didn't use an Observer
      await tester.pump();
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should automatically update UI with ZenUpdater inside ZenView',
        (tester) async {
      final controller = CounterController();

      await tester.pumpWidget(MaterialApp(
        home: ZenProvider.create(
          create: () => controller,
          child: const TestReactiveZenView(),
        ),
      ));

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should find scoped controller via ZenProvider.create',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider.create<CounterController>(
            create: () => CounterController(),
            child: const TestZenView(),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.findOrNull<CounterController>(),
          isNull); // Ensures it's NOT in global scope
    });

    testWidgets('should create and find controller with tag', (tester) async {
      final scope = Zen.createScope(name: 'TaggedScope');
      scope.put<CounterController>(CounterController(), tag: 'custom_tag');

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
            scope: scope,
            child: const TaggedTestView(),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets(
        'should use ZenProvider for explicit scope (correct V2 pattern)',
        (tester) async {
      final customScope = Zen.createScope(name: 'CustomScope');
      final controller = CounterController()..count = 42;
      customScope.put<CounterController>(controller);

      // V2: wrap the view in ZenProvider — do NOT pass scope directly to ZenView
      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
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

    testWidgets(
        'should fail with ZenControllerNotFoundException if controller registered globally via Zen.put',
        (tester) async {
      // GetX anti-pattern: registering UI controller globally
      Zen.put<CounterController>(CounterController());

      bool exceptionCaught = false;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception is ZenControllerNotFoundException) {
          exceptionCaught = true;
        }
      };

      await tester.pumpWidget(const MaterialApp(home: TestZenView()));

      expect(exceptionCaught, isTrue,
          reason: 'ZenView should not fallback to Zen.rootScope');
      FlutterError.onError = FlutterError.dumpErrorToConsole;
    });
  });
}
