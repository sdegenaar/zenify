import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import '../test_helpers.dart';

void main() {
  group('Navigation Memory Management', () {
    setUp(() {
      ZenTestHelper.resetDI();
    });

    tearDown(() {
      ZenTestHelper.resetDI();
    });

    testWidgets('should create separate controller instances with disposeOnRemove', (tester) async {
      final controllerInstances = <TestController>[];

      Widget buildZenBuilder() {
        return ZenBuilder<TestController>(
          create: () {
            final controller = TestController('test_${controllerInstances.length + 1}');
            controllerInstances.add(controller);
            return controller;
          },
          disposeOnRemove: true,
          builder: (context, controller) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecondPage()),
            ),
            child: Text('Value: ${controller.value}'),
          ),
        );
      }

      // First page
      await tester.pumpWidget(MaterialApp(home: buildZenBuilder()));
      expect(controllerInstances.length, 1);
      expect(find.text('Value: test_1'), findsOneWidget);

      // Navigate to second page (first ZenBuilder goes out of scope)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Navigate back with a NEW ZenBuilder widget
      await tester.pageBack();
      await tester.pumpWidget(MaterialApp(home: buildZenBuilder()));
      await tester.pumpAndSettle();

      // Should have created a second controller instance
      expect(controllerInstances.length, 2);
      expect(find.text('Value: test_2'), findsOneWidget);

      // First controller should be disposed when its widget was removed
      expect(controllerInstances[0].isDisposed, true);
    });

    testWidgets('should share controllers when disposeOnRemove is false', (tester) async {
      final controller = TestController('shared');
      Zen.put<TestController>(controller);

      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            ZenBuilder<TestController>(
              builder: (context, ctrl) => Text('A: ${ctrl.value}'),
            ),
            ZenBuilder<TestController>(
              builder: (context, ctrl) => Text('B: ${ctrl.value}'),
            ),
          ],
        ),
      ));

      expect(find.text('A: shared'), findsOneWidget);
      expect(find.text('B: shared'), findsOneWidget);
      expect(controller.isDisposed, false);
    });

    testWidgets('should dispose local controllers on widget disposal', (tester) async {
      late TestController controller;

      await tester.pumpWidget(MaterialApp(
        home: ZenBuilder<TestController>(
          create: () {
            controller = TestController('local');
            return controller;
          },
          disposeOnRemove: true,
          builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
        ),
      ));

      expect(find.text('Value: local'), findsOneWidget);
      expect(controller.isDisposed, false);

      // Remove the widget entirely
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Controller should be disposed
      expect(controller.isDisposed, true);
    });
  });
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Page')),
      body: const Center(child: Text('Second Page')),
    );
  }
}