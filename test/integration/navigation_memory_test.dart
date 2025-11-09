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

    testWidgets('should dispose controllers when widget is removed from tree',
        (tester) async {
      late TestController controller;

      await tester.pumpWidget(MaterialApp(
        home: ZenBuilder<TestController>(
          create: () {
            controller = TestController('local');
            return controller;
          },
          disposeOnRemove: true,
          builder: (context, ctrl) => Scaffold(
            body: Text('Value: ${ctrl.value}'),
          ),
        ),
      ));

      expect(find.text('Value: local'), findsOneWidget);
      expect(controller.isDisposed, false);

      // Remove the widget entirely by replacing with different content
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Replaced')),
      ));
      await tester.pumpAndSettle();

      // Controller should be disposed when widget was removed
      expect(controller.isDisposed, true);
    });

    testWidgets('should share controllers when disposeOnRemove is false',
        (tester) async {
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

    testWidgets('should dispose local controllers on widget disposal',
        (tester) async {
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
