// test/widgets/zen_builder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller
class CounterController extends ZenController {
  int count = 0;

  void increment() {
    count++;
    update(); // Notify UI to update
  }

  void reset() {
    count = 0;
    update();
  }
}

// Test widget using ZenBuilder
class TestZenBuilderWidget extends StatelessWidget {
  const TestZenBuilderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZenBuilder<CounterController>(
        builder: (context, controller) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Count: ${controller.count}',
                style: Theme.of(context).textTheme.headlineMedium, // ✅ Using context
              ),
              ElevatedButton(
                onPressed: controller.increment,
                child: const Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Test widget with navigation using context
class TestNavigationWidget extends StatelessWidget {
  const TestNavigationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZenBuilder<CounterController>(
        builder: (context, controller) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Count: ${controller.count}'),
              ElevatedButton(
                onPressed: () {
                  // ✅ Using context for navigation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Count is ${controller.count}')),
                  );
                },
                child: const Text('Show Snackbar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Test widget with MediaQuery using context
class TestResponsiveWidget extends StatelessWidget {
  const TestResponsiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZenBuilder<CounterController>(
        builder: (context, controller) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isWideScreen = screenWidth > 600;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: isWideScreen ? screenWidth * 0.5 : screenWidth * 0.9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Count: ${controller.count}',
                      style: TextStyle(
                        fontSize: isWideScreen ? 24 : 16,
                      ),
                    ),
                    const SizedBox(height: 32), // Larger spacing for better visual separation
                    ElevatedButton(
                      onPressed: controller.increment,
                      child: const Text('Increment'),
                    ),
                    const SizedBox(height: 16), // Space for additional buttons
                    // Add more widgets here if needed
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Test widget with initialization callback
class TestInitWidget extends StatelessWidget {
  const TestInitWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZenBuilder<CounterController>(
        init: (controller) {
          // Initialize controller with context-aware value
          controller.count = 5;
        },
        builder: (context, controller) {
          return Column(
            children: [
              Text('Initialized Count: ${controller.count}'),
              ElevatedButton(
                onPressed: controller.increment,
                child: const Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.enableDebugLogs = false;
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenBuilder Widget Tests', () {
    testWidgets('should provide context and controller to builder', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(
              headlineMedium: TextStyle(fontSize: 24, color: Colors.blue),
            ),
          ),
          home: const TestZenBuilderWidget(),
        ),
      );

      // Verify the view shows the controller's initial value with theme styling
      expect(find.text('Count: 0'), findsOneWidget);

      // Verify theme is applied (text should be blue from theme)
      final textWidget = tester.widget<Text>(find.text('Count: 0'));
      expect(textWidget.style?.color, Colors.blue);
      expect(textWidget.style?.fontSize, 24);
    });

    testWidgets('should handle navigation and context-dependent actions', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      controller.count = 3;
      Zen.put<CounterController>(controller);

      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestNavigationWidget(),
        ),
      );

      // Tap button to show snackbar
      await tester.tap(find.text('Show Snackbar'));
      await tester.pump();

      // Verify snackbar is shown with correct message
      expect(find.text('Count is 3'), findsOneWidget);
    });

    testWidgets('should handle responsive design with MediaQuery', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Set a wide screen size
      await tester.binding.setSurfaceSize(const Size(800, 600));

      // Build widget
      await tester.pumpWidget(
        const MaterialApp(
          home: TestResponsiveWidget(),
        ),
      );

      // Find the SizedBox instead of Container
      final sizedBoxFinder = find.byType(SizedBox);
      expect(sizedBoxFinder, findsWidgets); // There are multiple SizedBox widgets

      // Find the specific SizedBox that has the width constraint
      final centerFinder = find.byType(Center);
      expect(centerFinder, findsOneWidget);

      final center = tester.widget<Center>(centerFinder);
      final sizedBox = center.child as SizedBox;

      // Verify wide screen layout - width should be 400.0 (800 * 0.5)
      expect(sizedBox.width, 400.0);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should handle initialization with context awareness', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget with init callback
      await tester.pumpWidget(
        const MaterialApp(
          home: TestInitWidget(),
        ),
      );

      // Verify the controller was initialized with the value from init callback
      expect(find.text('Initialized Count: 5'), findsOneWidget);
    });

    testWidgets('should support ZenListener with context', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget using ZenListener
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenListener<CounterController>(
              builder: (context, controller) {
                return Column(
                  children: [
                    Text(
                      'Reactive: ${controller.count}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    ElevatedButton(
                      onPressed: controller.increment,
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Reactive: 0'), findsOneWidget);

      // Tap button to increment
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // UI should automatically update
      expect(find.text('Reactive: 1'), findsOneWidget);
    });

    testWidgets('should support SimpleBuilder with context', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget using SimpleBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleBuilder<CounterController>(
              builder: (context, controller) {
                return Column(
                  children: [
                    Text(
                      'Simple: ${controller.count}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    ElevatedButton(
                      onPressed: controller.increment,
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify it works the same as ZenBuilder
      expect(find.text('Simple: 0'), findsOneWidget);

      // Update controller
      controller.increment();
      await tester.pump();

      expect(find.text('Simple: 1'), findsOneWidget);
    });

    testWidgets('should handle theme changes through context', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      Zen.put<CounterController>(controller);

      // Build widget with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
          ),
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              builder: (context, controller) {
                return Container(
                  color: Theme.of(context).primaryColor,
                  child: Text('Count: ${controller.count}'),
                );
              },
            ),
          ),
        ),
      );

      // Find the container
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      // Verify light theme color
      final container = tester.widget<Container>(containerFinder);
      expect(container.color, Colors.blue);

      // Change to dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            primaryColor: Colors.red,
          ),
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              builder: (context, controller) {
                return Container(
                  color: Theme.of(context).primaryColor,
                  child: Text('Count: ${controller.count}'),
                );
              },
            ),
          ),
        ),
      );

      // Important: Call pumpAndSettle to ensure all animations and rebuilds complete
      await tester.pumpAndSettle();

      // Get the updated container widget after the theme change
      final updatedContainer = tester.widget<Container>(containerFinder);
      expect(updatedContainer.color, Colors.red);

      // Verify the text is still there
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should support locale-aware formatting', (WidgetTester tester) async {
      // Register a controller
      final controller = CounterController();
      controller.count = 1234;
      Zen.put<CounterController>(controller);

      // Build widget with US locale
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: ZenBuilder<CounterController>(
              builder: (context, controller) {
                // Use context for locale-aware formatting
                final locale = Localizations.localeOf(context);
                final isUS = locale.countryCode == 'US';
                return Text('Count: ${controller.count}${isUS ? ' (US)' : ''}');
              },
            ),
          ),
        ),
      );

      // Verify locale-aware display
      expect(find.text('Count: 1234 (US)'), findsOneWidget);
    });
  });
}