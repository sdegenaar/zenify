// test/widgets/zen_builder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controllers
class CounterController extends ZenController {
  int count = 0;

  void increment() {
    count++;
    update(); // Trigger UI update for all listeners
  }

  void incrementWithId(String id) {
    count++;
    update([id]); // Trigger UI update for specific listeners
  }
}

class ConfigController extends ZenController {
  bool isDarkMode = false;
  String theme = 'light';

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    theme = isDarkMode ? 'dark' : 'light';
    update();
  }
}

// Test widget wrapper for controller tag switching
class TagSwitchWrapper extends StatefulWidget {
  const TagSwitchWrapper({super.key});

  @override
  State<TagSwitchWrapper> createState() => _TagSwitchWrapperState();
}

class _TagSwitchWrapperState extends State<TagSwitchWrapper> {
  String tag = 'counter1';

  void switchTag() {
    setState(() {
      tag = tag == 'counter1' ? 'counter2' : 'counter1';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZenBuilder<CounterController>(
          tag: tag,
          builder: (controller) => Text('Count: ${controller.count}'),
        ),
        ElevatedButton(
          onPressed: switchTag,
          child: const Text('Switch Controller'),
        ),
      ],
    );
  }
}

// Test widget wrapper for ID switching
class IdSwitchWrapper extends StatefulWidget {
  const IdSwitchWrapper({super.key});

  @override
  State<IdSwitchWrapper> createState() => _IdSwitchWrapperState();
}

class _IdSwitchWrapperState extends State<IdSwitchWrapper> {
  String? id;

  void setId(String? newId) {
    setState(() {
      id = newId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZenBuilder<CounterController>(
          id: id,
          autoCreate: true,  // Add autoCreate: true
          create: () => CounterController(),  // Provide a create function
          builder: (controller) => Text('Count: ${controller.count}'),
        ),
        ElevatedButton(
          onPressed: () => setId('specific'),
          child: const Text('Set Specific ID'),
        ),
        ElevatedButton(
          onPressed: () => setId(null),
          child: const Text('Set Default ID'),
        ),
        ElevatedButton(
          onPressed: () => Zen.find<CounterController>()?.incrementWithId('specific'),
          child: const Text('Update Specific'),
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.enableDebugLogs = false;
  });

  tearDown(() {
    Zen.deleteAll(force: true);
  });

  group('ZenBuilder Widget Tests', () {
    testWidgets('should build with controller', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              builder: (controller) => Text('Count: ${controller.count}'),
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should update UI when controller calls update()', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              builder: (controller) => Column(
                children: [
                  Text('Count: ${controller.count}'),
                  ElevatedButton(
                    onPressed: controller.increment,
                    child: const Text('Increment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to increment
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify updated state
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should only update specific builders with ID', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget with two builders, one with specific ID
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // This builder uses a specific ID
                ZenBuilder<CounterController>(
                  id: 'specific',
                  builder: (controller) => Text('Specific: ${controller.count}'),
                ),
                // This builder gets all updates
                ZenBuilder<CounterController>(
                  builder: (controller) => Text('General: ${controller.count}'),
                ),
                ElevatedButton(
                  onPressed: () => controller.incrementWithId('specific'),
                  child: const Text('Update Specific'),
                ),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Text('Update All'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Specific: 0'), findsOneWidget);
      expect(find.text('General: 0'), findsOneWidget);

      // Tap button to update specific
      await tester.tap(find.text('Update Specific'));
      await tester.pump();

      // Only the specific builder should update
      expect(find.text('Specific: 1'), findsOneWidget);
      expect(find.text('General: 0'), findsOneWidget);

      // Tap button to update all
      await tester.tap(find.text('Update All'));
      await tester.pump();

      // Both builders should update
      expect(find.text('Specific: 2'), findsOneWidget);
      expect(find.text('General: 2'), findsOneWidget);
    });

    testWidgets('should auto-create controller when needed', (WidgetTester tester) async {
      // Don't register controller beforehand

      // Build widget with autoCreate
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              autoCreate: true,
              create: () => CounterController(),
              builder: (controller) => Text('Count: ${controller.count}'),
            ),
          ),
        ),
      );

      // Verify controller was created and widget rendered
      expect(find.text('Count: 0'), findsOneWidget);
      expect(Zen.find<CounterController>(), isNotNull);
    });

    testWidgets('should work with tagged controllers', (WidgetTester tester) async {
      // Register multiple controllers with different tags
      final controller1 = CounterController();
      final controller2 = CounterController();
      controller2.count = 10; // Different initial value

      Zen.put<CounterController>(controller1, tag: 'counter1');
      Zen.put<CounterController>(controller2, tag: 'counter2');

      // Build widget with two builders using different tags
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenBuilder<CounterController>(
                  tag: 'counter1',
                  builder: (controller) => Text('Counter1: ${controller.count}'),
                ),
                ZenBuilder<CounterController>(
                  tag: 'counter2',
                  builder: (controller) => Text('Counter2: ${controller.count}'),
                ),
                ElevatedButton(
                  onPressed: controller1.increment,
                  child: const Text('Increment Counter1'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Counter1: 0'), findsOneWidget);
      expect(find.text('Counter2: 10'), findsOneWidget);

      // Tap button to increment counter1
      await tester.tap(find.text('Increment Counter1'));
      await tester.pump();

      // Only counter1 should be updated
      expect(find.text('Counter1: 1'), findsOneWidget);
      expect(find.text('Counter2: 10'), findsOneWidget);
    });

    testWidgets('should dispose controller when disposeController is true', (WidgetTester tester) async {
      // Build widget with disposeController = true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              autoCreate: true,
              create: () => CounterController(),
              disposeController: true,
              builder: (controller) => Text('Count: ${controller.count}'),
            ),
          ),
        ),
      );

      // Verify controller exists
      expect(Zen.find<CounterController>(), isNotNull);

      // Rebuild with different widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Different Widget'),
          ),
        ),
      );

      // Verify controller was disposed
      expect(Zen.find<CounterController>(), isNull);
    });

    testWidgets('should respect findScopeFn for scoped controllers', (WidgetTester tester) async {
      // Create scopes
      final customScope = Zen.createScope(name: "CustomScope");

      // Register controllers in different scopes
      final rootController = CounterController();
      final scopedController = CounterController();
      scopedController.count = 100;

      Zen.put<CounterController>(rootController);
      Zen.put<CounterController>(scopedController, scope: customScope);

      // Build widget with scope function
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Use root scope controller
                ZenBuilder<CounterController>(
                  builder: (controller) => Text('Root: ${controller.count}'),
                ),
                // Use custom scope controller
                ZenBuilder<CounterController>(
                  findScopeFn: () => customScope,
                  builder: (controller) => Text('Custom: ${controller.count}'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify correct controllers are used
      expect(find.text('Root: 0'), findsOneWidget);
      expect(find.text('Custom: 100'), findsOneWidget);
    });

    testWidgets('should handle controller changes when widget updates', (WidgetTester tester) async {
      // Register controllers
      final controller1 = CounterController();
      final controller2 = CounterController();
      controller2.count = 50;

      Zen.put<CounterController>(controller1, tag: 'counter1');
      Zen.put<CounterController>(controller2, tag: 'counter2');

      // Render the test wrapper
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TagSwitchWrapper(),
          ),
        ),
      );

      // Initially should show controller1's count
      expect(find.text('Count: 0'), findsOneWidget);

      // Switch to controller2
      await tester.tap(find.text('Switch Controller'));
      await tester.pump();

      // Should now show controller2's count
      expect(find.text('Count: 50'), findsOneWidget);

      // Increment controller2 and verify update
      controller2.increment();
      await tester.pump();
      expect(find.text('Count: 51'), findsOneWidget);

      // Switch back to controller1
      await tester.tap(find.text('Switch Controller'));
      await tester.pump();

      // Should show controller1's count again (still 0)
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should handle ID changes correctly', (WidgetTester tester) async {
      // Register a controller first
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build our widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdSwitchWrapper(),
          ),
        ),
      );

      // Verify the initial builder shows up with Count: 0
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to set specific ID
      await tester.tap(find.text('Set Specific ID'));
      await tester.pump();

      // Verify the builder still shows the same count
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap button to update controllers with the specific ID
      await tester.tap(find.text('Update Specific'));
      await tester.pump();

      // Verify the builder with specific ID updates
      expect(find.text('Count: 1'), findsOneWidget);

      // Set ID back to default
      await tester.tap(find.text('Set Default ID'));
      await tester.pump();

      // Update again - this should update the default ID view
      await tester.tap(find.text('Update Specific'));
      await tester.pump();

      // Default ID view should remain at Count: 1
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should work with multiple controller types simultaneously', (WidgetTester tester) async {
      // Register different controller types
      final counterController = CounterController();
      final configController = ConfigController();

      Zen.put<CounterController>(counterController);
      Zen.put<ConfigController>(configController);

      // Build widget with two different controller types
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZenBuilder<CounterController>(
                  builder: (controller) => Text('Count: ${controller.count}'),
                ),
                ZenBuilder<ConfigController>(
                  builder: (controller) => Text('Theme: ${controller.theme}'),
                ),
                ElevatedButton(
                  onPressed: counterController.increment,
                  child: const Text('Increment'),
                ),
                ElevatedButton(
                  onPressed: configController.toggleTheme,
                  child: const Text('Toggle Theme'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Theme: light'), findsOneWidget);

      // Increment counter
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Only counter should update
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Theme: light'), findsOneWidget);

      // Toggle theme
      await tester.tap(find.text('Toggle Theme'));
      await tester.pump();

      // Only theme should update
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Theme: dark'), findsOneWidget);
    });

    testWidgets('should handle errors gracefully when controller not found', (WidgetTester tester) async {
      // This is a better approach for testing exceptions in widget tests

      // Use FlutterError.onError to capture the error
      late Object caughtError;
      final originalOnError = FlutterError.onError;

      FlutterError.onError = (FlutterErrorDetails details) {
        caughtError = details.exception;
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZenBuilder<CounterController>(
                builder: (controller) => Text('Count: ${controller.count}'),
                // No autoCreate, should throw exception
              ),
            ),
          ),
        );

        // Wait for any pending frames
        await tester.pump();

        // Check if we caught the error correctly
        expect(caughtError.toString().contains('Controller not found'), isTrue);
      } finally {
        // Restore the original error handler
        FlutterError.onError = originalOnError;
      }
    });
  });
}