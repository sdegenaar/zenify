import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestController extends ZenController {
  int value = 0;
  void increment() {
    value++;
    update();
  }
}

void main() {
  setUp(() {
    Zen.init();
  });
  tearDown(() {
    Zen.reset();
  });

  group('ZenUpdater Core Functionality', () {
    testWidgets('should find existing controller in global scope and rebuild',
        (tester) async {
      final controller = TestController();
      Zen.put<TestController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenUpdater<TestController>(
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);

      controller.increment();
      await tester.pump();

      expect(find.text('Value: 1'), findsOneWidget);
    });

    testWidgets('should handle missing controller gracefully with onError',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenUpdater<TestController>(
            onError: (error) => Text('Error Caught'),
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Error Caught'), findsOneWidget);
    });
  });

  group('ZenUpdater Scoping', () {
    testWidgets('should respect nearest scope over global scope',
        (tester) async {
      final globalCtrl = TestController()..value = 10;
      Zen.put<TestController>(globalCtrl);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<TestController>(
            create: () => TestController()..value = 20,
            child: ZenUpdater<TestController>(
              builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Value: 20'), findsOneWidget);
    });
  });
}
