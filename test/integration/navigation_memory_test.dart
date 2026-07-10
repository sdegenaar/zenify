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

    testWidgets('should dispose controllers when ZenScopeWidget is removed from tree',
        (tester) async {
      late TestController controller;

      await tester.pumpWidget(MaterialApp(
        home: ZenScopeWidget.create<TestController>(
          create: () {
            controller = TestController('local');
            return controller;
          },
          child: ZenUpdater<TestController>(
            builder: (context, ctrl) => Scaffold(
              body: Text('Value: ${ctrl.value}'),
            ),
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

      // Controller should be disposed when scope was removed
      expect(controller.isDisposed, true);
    });

    testWidgets('should share controllers when using global DI',
        (tester) async {
      final controller = TestController('shared');
      Zen.put<TestController>(controller);

      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            ZenUpdater<TestController>(
              builder: (context, ctrl) => Text('A: ${ctrl.value}'),
            ),
            ZenUpdater<TestController>(
              builder: (context, ctrl) => Text('B: ${ctrl.value}'),
            ),
          ],
        ),
      ));

      expect(find.text('A: shared'), findsOneWidget);
      expect(find.text('B: shared'), findsOneWidget);
      expect(controller.isDisposed, false);
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
