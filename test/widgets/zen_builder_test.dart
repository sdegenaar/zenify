import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller
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

  group('ZenBuilder Core Functionality', () {
    testWidgets('should find existing controller in global scope',
        (WidgetTester tester) async {
      final controller = TestController();
      Zen.put<TestController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
    });

    testWidgets('should create controller if not found and create provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () => TestController(),
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
    });

    testWidgets('should handle missing controller gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            onError: (error) =>
                Text(error.toString()), // Simplified error widget
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Now we can check for the exact error message
      expect(
          find.text(
              'Bad state: Controller of type TestController not found and no create function provided'),
          findsOneWidget);
    });

    testWidgets('should initialize controller with init callback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () => TestController(),
            init: (ctrl) => ctrl.value = 42,
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 42'), findsOneWidget);
    });
  });

  group('ZenBuilder Update Mechanism', () {
    testWidgets('should rebuild when controller updates',
        (WidgetTester tester) async {
      late TestController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () {
              controller = TestController();
              return controller;
            },
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);

      controller.increment();
      await tester.pump();

      expect(find.text('Value: 1'), findsOneWidget);
    });

    testWidgets('should handle multiple builders with same controller',
        (WidgetTester tester) async {
      final controller = TestController();
      Zen.put<TestController>(controller);

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(find.text('A: 0'), findsOneWidget);
      expect(find.text('B: 0'), findsOneWidget);

      controller.increment();
      await tester.pump();

      expect(find.text('A: 1'), findsOneWidget);
      expect(find.text('B: 1'), findsOneWidget);
    });
  });

  group('ZenBuilder Lifecycle', () {
    testWidgets('should dispose controller when disposeOnRemove is true',
        (WidgetTester tester) async {
      late TestController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () {
              controller = TestController();
              return controller;
            },
            disposeOnRemove: true,
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Try to access disposed controller
      expect(
        () => Zen.find<TestController>(),
        throwsA(isA<ZenDependencyNotFoundException>()),
      );
    });

    testWidgets('should cleanup listeners on dispose',
        (WidgetTester tester) async {
      final controller = TestController();
      Zen.put<TestController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      controller.increment(); // Should not cause errors
    });
  });

  group('ZenBuilder Error Handling', () {
    testWidgets('should show custom error widget on error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () => TestController(),
            builder: (_, __) => throw Exception('Test error'),
            onError: (error) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Error: Exception: Test error'), findsOneWidget);
    });

    testWidgets('should show default error widget if no custom handler',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            create: () => TestController(),
            builder: (_, __) => throw Exception('Test error'),
          ),
        ),
      );

      expect(find.text('Controller Error'), findsOneWidget);
    });
  });

  group('ZenBuilder Scoping', () {
    testWidgets('should respect explicit scope', (WidgetTester tester) async {
      final scope = Zen.createScope(name: 'TestScope');
      final controller = TestController();
      scope.put<TestController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            scope: scope,
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
    });

    testWidgets('should reinitialize on scope change',
        (WidgetTester tester) async {
      final scope1 = Zen.createScope(name: 'Scope1');
      final scope2 = Zen.createScope(name: 'Scope2');

      final controller1 = TestController()..value = 1;
      final controller2 = TestController()..value = 2;

      scope1.put<TestController>(controller1);
      scope2.put<TestController>(controller2);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            scope: scope1,
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 1'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<TestController>(
            scope: scope2,
            builder: (context, ctrl) => Text('Value: ${ctrl.value}'),
          ),
        ),
      );

      expect(find.text('Value: 2'), findsOneWidget);
    });
  });
}
