// test/zen_effects_builder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller with an effect
class UserController extends ZenController {
  final userEffect = ZenEffect<Map<String, dynamic>?>(name: 'userEffect');

  Future<void> loadUser() async {
    try {
      // Simulate a successful API call
      final userData = {'id': '123', 'name': 'Test User'};
      userEffect.success(userData);
    } catch (e) {
      userEffect.setError('Failed to load user');
    }
  }

  Future<void> loadUserWithError() async {
    userEffect.setError('Failed to load user');
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
  });

  tearDown(() {
    Zen.deleteAll(force: true);
  });

  group('ZenEffectBuilder Widget', () {
    testWidgets('should render loading state correctly', (WidgetTester tester) async {
      // Create controller with effect
      final controller = UserController();
      Zen.put<UserController>(controller);

      // Start loading
      controller.userEffect.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenEffectBuilder<Map<String, dynamic>?>(
              effect: controller.userEffect,
              onLoading: () => const CircularProgressIndicator(),
              onSuccess: (data) => data != null
                  ? Text('User: ${data['name']}')
                  : const Text('No data'),
              onError: (error) => Text('Error: $error'),
            ),
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render success state with data', (WidgetTester tester) async {
      // Create controller with effect
      final controller = UserController();
      Zen.put<UserController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenEffectBuilder<Map<String, dynamic>?>(
              effect: controller.userEffect,
              onLoading: () => const CircularProgressIndicator(),
              onSuccess: (data) => data != null
                  ? Text('User: ${data['name']}')
                  : const Text('No data'),
              onError: (error) => Text('Error: $error'),
            ),
          ),
        ),
      );

      // Load user (success)
      await controller.loadUser();
      await tester.pump();

      // Should show success view with user data
      expect(find.text('User: Test User'), findsOneWidget);
    });

    testWidgets('should render error state', (WidgetTester tester) async {
      // Create controller with effect
      final controller = UserController();
      Zen.put<UserController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenEffectBuilder<Map<String, dynamic>?>(
              effect: controller.userEffect,
              onLoading: () => const CircularProgressIndicator(),
              onSuccess: (data) => data != null
                  ? Text('User: ${data['name']}')
                  : const Text('No data'),
              onError: (error) => Text('Error: $error'),
            ),
          ),
        ),
      );

      // Load user with error
      await controller.loadUserWithError();
      await tester.pump();

      // Should show error view
      expect(find.text('Error: Failed to load user'), findsOneWidget);
    });

    testWidgets('should update when effect state changes', (WidgetTester tester) async {
      // Create controller with effect
      final controller = UserController();
      Zen.put<UserController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenEffectBuilder<Map<String, dynamic>?>(
              effect: controller.userEffect,
              onLoading: () => const CircularProgressIndicator(),
              onSuccess: (data) => data != null
                  ? Text('User: ${data['name']}')
                  : const Text('No data'),
              onError: (error) => Text('Error: $error'),
            ),
          ),
        ),
      );

      // Start with loading
      controller.userEffect.loading();
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Then show error
      controller.userEffect.setError('Failed to load user');
      await tester.pump();

      // Should show error view
      expect(find.text('Error: Failed to load user'), findsOneWidget);

      // Finally show success
      controller.userEffect.success({'id': '123', 'name': 'Test User'});
      await tester.pump();

      // Should show success view
      expect(find.text('User: Test User'), findsOneWidget);
    });

    // Add this to the test that's failing
    testWidgets('should handle null data', (WidgetTester tester) async {
      final effect = ZenEffect<Map<String, dynamic>?>(name: 'testEffect');

      // Build a simple widget with the effect
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ZenEffectBuilder<Map<String, dynamic>?>(
              effect: effect,
              onLoading: () => const Text('Loading'),
              onError: (error) => Text('Error: $error'),
              onSuccess: (data) {
                // Use ZenLogger instead of print
                ZenLogger.logDebug('onSuccess called with: $data');
                return data == null
                    ? const Text('No data')
                    : Text('Data: ${data['name']}');
              },
            ),
          ),
        ),
      );

      // Initial state should be empty (no success yet)
      expect(find.text('No data'), findsNothing);

      // Set null data
      effect.success(null);

      // Make sure hasData is true
      expect(effect.hasData, isTrue);

      // Trigger a frame
      await tester.pump();

      // Log widget tree for debugging using ZenLogger instead of print
      ZenLogger.logDebug('Widget tree:');
      for (var widget in tester.allWidgets) {
        if (widget is Text) {
          ZenLogger.logDebug('Text widget found: "${widget.data}"');
        }
      }

      // Should now show "No data"
      expect(find.text('No data'), findsOneWidget);
    });
  });
}