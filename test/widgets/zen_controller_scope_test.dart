import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class CounterController extends ZenController {
  int count = 0;
  void increment() {
    count++;
    update();
  }
}

class DependentController extends ZenController {
  late final CounterController counter;

  @override
  void onInit() {
    super.onInit();
    counter = Zen.find<CounterController>();
  }

  void incrementCounter() {
    counter.increment();
    update();
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

  group('ZenProvider.create Tests', () {
    testWidgets('should create controller and make it available to children',
        (tester) async {
      bool controllerCreated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider.create<CounterController>(
            create: () {
              controllerCreated = true;
              return CounterController();
            },
            child: ZenUpdater<CounterController>(
              builder: (context, controller) {
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controllerCreated, isTrue);
      expect(find.text('Count: 0'), findsOneWidget);

      final BuildContext context = tester.element(find.byType(Text));
      final controller = context.controller<CounterController>();

      controller.increment();
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets(
        'should automatically dispose controller when widget is removed',
        (tester) async {
      bool disposerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider.create<CounterController>(
            create: () {
              final controller = CounterController();
              controller.addDisposer(() => disposerCalled = true);
              return controller;
            },
            child: const Text('Scope'),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(Text));
      final controller = context.controller<CounterController>();
      expect(controller, isNotNull);
      expect(disposerCalled, isFalse);

      await tester
          .pumpWidget(const MaterialApp(home: Text('Different Widget')));
      await tester.pumpAndSettle();

      expect(disposerCalled, isTrue);
      expect(Zen.findOrNull<CounterController>(), isNull);
    });
  });
}
