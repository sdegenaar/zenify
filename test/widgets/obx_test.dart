// test/widgets/obx_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Controller for testing reactive properties
class ReactiveController extends ZenController {
  final counter = 0.obs();
  final name = 'John'.obs();
  final isActive = false.obs();
  final items = <String>[].obs();

  void incrementCounter() {
    counter.value++;
  }

  void updateName(String newName) {
    name.value = newName;
  }

  void toggleActive() {
    isActive.toggle();
  }

  void addItem(String item) {
    items.value.add(item);
    items.refresh(); // Need to call refresh for collections
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test); // Apply test settings
    ZenConfig.logLevel = ZenLogLevel.none; // Override to disable all logs
  });

  tearDown(() {
    Zen.deleteAll(force: true);
  });

  group('ZenObserver Widget Tests', () {
    testWidgets('should rebuild when Rx values change',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widgets with ZenObserver
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Counter: ${controller.counter.value}')),
                ZenObserver(() => Text('Name: ${controller.name.value}')),
                ZenObserver(() => Text('Active: ${controller.isActive.value}')),
                ZenObserver(() => Text('Items: ${controller.items.value.length}')),
                ElevatedButton(
                  onPressed: controller.incrementCounter,
                  child: const Text('Increment'),
                ),
                ElevatedButton(
                  onPressed: () => controller.updateName('Doe'),
                  child: const Text('Update Name'),
                ),
                ElevatedButton(
                  onPressed: controller.toggleActive,
                  child: const Text('Toggle Active'),
                ),
                ElevatedButton(
                  onPressed: () => controller.addItem('Item 1'),
                  child: const Text('Add Item'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('Name: John'), findsOneWidget);
      expect(find.text('Active: false'), findsOneWidget);
      expect(find.text('Items: 0'), findsOneWidget);

      // Tap increment button
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Counter should update
      expect(find.text('Counter: 1'), findsOneWidget);
      expect(find.text('Name: John'), findsOneWidget); // Name unchanged

      // Tap update name button
      await tester.tap(find.text('Update Name'));
      await tester.pump();

      // Name should update
      expect(find.text('Counter: 1'), findsOneWidget); // Counter unchanged
      expect(find.text('Name: Doe'), findsOneWidget);

      // Tap toggle active button
      await tester.tap(find.text('Toggle Active'));
      await tester.pump();

      // Active state should update
      expect(find.text('Active: true'), findsOneWidget);

      // Tap add item button
      await tester.tap(find.text('Add Item'));
      await tester.pump();

      // Items count should update
      expect(find.text('Items: 1'), findsOneWidget);
    });

    testWidgets('should only rebuild specific ZenObserver widgets',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Track rebuild counts
      int counterRebuildCount = 0;
      int nameRebuildCount = 0;

      // Build widgets with ZenObserver that track rebuilds
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() {
                  counterRebuildCount++;
                  return Text(
                      'Counter: ${controller.counter.value} (Rebuilds: $counterRebuildCount)');
                }),
                ZenObserver(() {
                  nameRebuildCount++;
                  return Text(
                      'Name: ${controller.name.value} (Rebuilds: $nameRebuildCount)');
                }),
                ElevatedButton(
                  onPressed: controller.incrementCounter,
                  child: const Text('Increment Counter'),
                ),
                ElevatedButton(
                  onPressed: () => controller.updateName('Doe'),
                  child: const Text('Update Name'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial build counts
      expect(counterRebuildCount, 1);
      expect(nameRebuildCount, 1);

      // Tap increment counter button
      await tester.tap(find.text('Increment Counter'));
      await tester.pump();

      // Only counter ZenObserver should rebuild
      expect(counterRebuildCount, 2);
      expect(nameRebuildCount, 1); // Unchanged

      // Tap update name button
      await tester.tap(find.text('Update Name'));
      await tester.pump();

      // Only name ZenObserver should rebuild
      expect(counterRebuildCount, 2); // Unchanged
      expect(nameRebuildCount, 2);
    });

    testWidgets('should handle complex expressions',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widget with complex expression
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Complex expression combining multiple observables
                ZenObserver(() => Text(
                      'Status: ${controller.isActive.value ? "Active" : "Inactive"} user ${controller.name.value} has ${controller.counter.value} points',
                    )),
                ElevatedButton(
                  onPressed: () {
                    controller.incrementCounter();
                    controller.toggleActive();
                    controller.updateName('Jane');
                  },
                  child: const Text('Update All'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state
      expect(
          find.text('Status: Inactive user John has 0 points'), findsOneWidget);

      // Tap update all button
      await tester.tap(find.text('Update All'));
      await tester.pump();

      // Should update with all changes
      expect(
          find.text('Status: Active user Jane has 1 points'), findsOneWidget);
    });

    testWidgets('should handle conditionally shown widgets',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widget with conditional rendering
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => controller.isActive.value
                    ? Text('Welcome ${controller.name.value}')
                    : const Text('Please activate your account')),
                ElevatedButton(
                  onPressed: controller.toggleActive,
                  child: const Text('Toggle Active'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state (inactive)
      expect(find.text('Please activate your account'), findsOneWidget);
      expect(find.textContaining('Welcome'), findsNothing);

      // Tap toggle button
      await tester.tap(find.text('Toggle Active'));
      await tester.pump();

      // Should switch to welcome message
      expect(find.text('Please activate your account'), findsNothing);
      expect(find.text('Welcome John'), findsOneWidget);
    });

    testWidgets('should work with nested ZenObserver widgets',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Track rebuild counts
      int outerRebuildCount = 0;
      int innerRebuildCount = 0;

      // Build widget with nested ZenObserver
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() {
                  outerRebuildCount++;
                  return Column(
                    children: [
                      Text('Outer: ${controller.counter.value}'),
                      ZenObserver(() {
                        innerRebuildCount++;
                        return Text('Inner: ${controller.name.value}');
                      }),
                    ],
                  );
                }),
                ElevatedButton(
                  onPressed: controller.incrementCounter,
                  child: const Text('Increment Counter'),
                ),
                ElevatedButton(
                  onPressed: () => controller.updateName('Doe'),
                  child: const Text('Update Name'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial rebuild counts
      expect(outerRebuildCount, 1);
      expect(innerRebuildCount, 1);

      // Update counter - should rebuild outer and inner
      await tester.tap(find.text('Increment Counter'));
      await tester.pump();

      expect(outerRebuildCount, 2);
      expect(innerRebuildCount, 2); // Inner rebuilds because outer rebuilds

      // Update name - should only rebuild inner
      await tester.tap(find.text('Update Name'));
      await tester.pump();

      expect(outerRebuildCount, 2); // Unchanged
      expect(innerRebuildCount, 3); // Incremented
    });

    testWidgets('should handle list operations correctly',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widget for list manipulation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Items: ${controller.items.value.join(", ")}')),
                ElevatedButton(
                  onPressed: () => controller
                      .addItem('Item ${controller.items.value.length + 1}'),
                  child: const Text('Add Item'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.items.value.isNotEmpty) {
                      controller.items.value.removeLast();
                      controller.items.refresh();
                    }
                  },
                  child: const Text('Remove Last'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state (empty list)
      expect(find.text('Items: '), findsOneWidget);

      // Add an item
      await tester.tap(find.text('Add Item'));
      await tester.pump();

      // List should update
      expect(find.text('Items: Item 1'), findsOneWidget);

      // Add another item
      await tester.tap(find.text('Add Item'));
      await tester.pump();

      // List should update again
      expect(find.text('Items: Item 1, Item 2'), findsOneWidget);

      // Remove an item
      await tester.tap(find.text('Remove Last'));
      await tester.pump();

      // List should update after removal
      expect(find.text('Items: Item 1'), findsOneWidget);
    });

    testWidgets('should work with operator syntax on rx',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widget using ZenObserver
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Counter: ${controller.counter.value}')),
                ElevatedButton(
                  // Use operator syntax directly
                  onPressed: () => controller.counter.value += 1,
                  child: const Text('Increment +1'),
                ),
                ElevatedButton(
                  onPressed: () => controller.counter.value *= 2,
                  child: const Text('Double'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Counter: 0'), findsOneWidget);

      // Increment using operator
      await tester.tap(find.text('Increment +1'));
      await tester.pump();

      // Counter should update
      expect(find.text('Counter: 1'), findsOneWidget);

      // Double using operator
      await tester.tap(find.text('Double'));
      await tester.pump();

      // Counter should double
      expect(find.text('Counter: 2'), findsOneWidget);
    });

    testWidgets('should handle rx methods like toggle() for boolean',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Build widget using toggle method
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Active: ${controller.isActive.value}')),
                ElevatedButton(
                  onPressed: () => controller.isActive.toggle(),
                  child: const Text('Toggle'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial state (false)
      expect(find.text('Active: false'), findsOneWidget);

      // Toggle first time
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(find.text('Active: true'), findsOneWidget);

      // Toggle again
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      expect(find.text('Active: false'), findsOneWidget);
    });

    testWidgets('should handle disposal correctly',
        (WidgetTester tester) async {
      // Create a controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Add ZenObserver widget
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ZenObserver(() => Text('Counter: ${controller.counter.value}')),
              ElevatedButton(
                onPressed: () {
                  controller.dispose();
                  Zen.delete<ReactiveController>();
                },
                child: const Text('Dispose Controller'),
              ),
            ],
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Counter: 0'), findsOneWidget);

      // Dispose controller
      await tester.tap(find.text('Dispose Controller'));
      await tester.pump();

      // Verify that the controller was disposed without errors
      expect(controller.isDisposed, isTrue);
    });

    testWidgets('should maintain referential equality for Rx objects',
        (WidgetTester tester) async {
      // Create controller
      final controller = ReactiveController();
      Zen.put(controller);

      // Track object identity changes
      final initialCounter = controller.counter;

      // Build widget using ZenObserver
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Counter: ${controller.counter.value}')),
                ElevatedButton(
                  onPressed: controller.incrementCounter,
                  child: const Text('Increment'),
                ),
              ],
            ),
          ),
        ),
      );

      // Increment counter
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify counter instance is the same object (referential equality)
      expect(identical(initialCounter, controller.counter), isTrue);
    });

    testWidgets('should work with multiple independent ZenObserver widgets',
        (WidgetTester tester) async {
      // Create multiple controllers
      final controller1 = ReactiveController();
      final controller2 = ReactiveController();

      Zen.put(controller1, tag: 'c1');
      Zen.put(controller2, tag: 'c2');

      // Build widgets with ZenObserver
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('C1 Counter: ${controller1.counter.value}')),
                ZenObserver(() => Text('C2 Counter: ${controller2.counter.value}')),
                ElevatedButton(
                  onPressed: controller1.incrementCounter,
                  child: const Text('Increment C1'),
                ),
                ElevatedButton(
                  onPressed: controller2.incrementCounter,
                  child: const Text('Increment C2'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('C1 Counter: 0'), findsOneWidget);
      expect(find.text('C2 Counter: 0'), findsOneWidget);

      // Increment first controller
      await tester.tap(find.text('Increment C1'));
      await tester.pump();

      // Only first counter should change
      expect(find.text('C1 Counter: 1'), findsOneWidget);
      expect(find.text('C2 Counter: 0'), findsOneWidget);

      // Increment second controller
      await tester.tap(find.text('Increment C2'));
      await tester.pump();

      // Both counters should reflect their individual states
      expect(find.text('C1 Counter: 1'), findsOneWidget);
      expect(find.text('C2 Counter: 1'), findsOneWidget);
    });
  });

  // V2: ZenObserver is the sole reactive widget. Obx alias is removed.
  group('ZenObserver (primary reactive widget)', () {
    testWidgets('ZenObserver is the canonical reactive widget',
        (WidgetTester tester) async {
      final controller = ReactiveController();
      Zen.put(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenObserver(() => Text('Count: ${controller.counter.value}')),
                ZenObserver(() => Text('Name: ${controller.name.value}')),
                ElevatedButton(
                  onPressed: controller.incrementCounter,
                  child: const Text('Increment'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Name: John'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Name: John'), findsOneWidget);
    });

    testWidgets('ZenObserver is a StatefulWidget',
        (WidgetTester tester) async {
      final controller = ReactiveController();
      Zen.put(controller);

      final widget = ZenObserver(() => Text('${controller.counter.value}'));
      expect(widget, isA<ZenObserver>());
    });
  });
}

