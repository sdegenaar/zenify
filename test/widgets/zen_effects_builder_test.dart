import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('ZenEffectBuilder', () {
    late ZenEffect<String> effect;

    setUp(() {
      effect = createEffect<String>(name: 'test');
    });

    tearDown(() {
      effect.dispose();
    });

    testWidgets('should show initial state when effect is in initial state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Success: test'), findsNothing);
    });

    testWidgets('should show empty widget when no onInitial provided and in initial state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Initial'), findsNothing);
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Success: test'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should show loading state when effect is loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      // Start loading
      effect.loading();
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Initial'), findsNothing);
      expect(find.text('Success: test'), findsNothing);
    });

    testWidgets('should show success state when effect has data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      // Set success data
      effect.success('test data');
      await tester.pump();

      expect(find.text('Success: test data'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Initial'), findsNothing);
    });

    testWidgets('should show success state even when data is null', (tester) async {
      final nullableEffect = createEffect<String?>(name: 'nullable_test');

      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String?>(
            effect: nullableEffect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: ${data ?? 'null'}'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      // Set null data explicitly
      nullableEffect.success(null);
      await tester.pump();

      expect(find.text('Success: null'), findsOneWidget);
      expect(find.text('Initial'), findsNothing);

      nullableEffect.dispose();
    });

    testWidgets('should show error state when effect has error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      // Set error
      effect.setError('test error');
      await tester.pump();

      expect(find.text('Error: test error'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Initial'), findsNothing);
      expect(find.text('Success: test'), findsNothing);
    });

    testWidgets('should transition through states correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      // Initial state
      expect(find.text('Initial'), findsOneWidget);

      // Start loading
      effect.loading();
      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Initial'), findsNothing);

      // Success
      effect.success('test data');
      await tester.pump();
      expect(find.text('Success: test data'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);

      // Error
      effect.setError('test error');
      await tester.pump();
      expect(find.text('Error: test error'), findsOneWidget);
      expect(find.text('Success: test data'), findsNothing);

      // Reset to initial
      effect.reset();
      await tester.pump();
      expect(find.text('Initial'), findsOneWidget);
      expect(find.text('Error: test error'), findsNothing);
    });

    testWidgets('should use custom builder when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
            builder: (context, child) => Container(
              key: const Key('custom_container'),
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom_container')), findsOneWidget);
      expect(find.text('Initial'), findsOneWidget);

      // Verify custom builder is used for all states
      effect.loading();
      await tester.pump();
      expect(find.byKey(const Key('custom_container')), findsOneWidget);
      expect(find.text('Loading'), findsOneWidget);

      effect.success('test');
      await tester.pump();
      expect(find.byKey(const Key('custom_container')), findsOneWidget);
      expect(find.text('Success: test'), findsOneWidget);

      effect.setError('error');
      await tester.pump();
      expect(find.byKey(const Key('custom_container')), findsOneWidget);
      expect(find.text('Error: error'), findsOneWidget);
    });

    testWidgets('should handle effect changes when widget updates', (tester) async {
      final effect1 = createEffect<String>(name: 'effect1');
      final effect2 = createEffect<String>(name: 'effect2');

      effect1.success('data from effect1');
      effect2.success('data from effect2');

      // Start with effect1
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect1,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Success: data from effect1'), findsOneWidget);

      // Update to effect2
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect2,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Success: data from effect2'), findsOneWidget);
      expect(find.text('Success: data from effect1'), findsNothing);

      effect1.dispose();
      effect2.dispose();
    });

    testWidgets('should not rebuild when disposed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Remove the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Try to trigger state change (should not cause any issues)
      effect.success('test data');
      await tester.pump();

      // Should not throw or cause any issues
      expect(find.text('Success: test data'), findsNothing);
    });

    testWidgets('should work with run method', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Use run method which automatically handles loading/success/error states
      final future = effect.run(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'async data';
      });

      // Should show loading immediately
      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      // Advance the timer to complete the delay
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for completion
      await future;
      await tester.pump();
      expect(find.text('Success: async data'), findsOneWidget);
    });

    testWidgets('should work with run method without delays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Use run method without delay
      final future = effect.run(() async {
        return 'immediate data';
      });

      // Should show loading briefly
      await tester.pump();

      // Complete the future
      await future;
      await tester.pump();

      expect(find.text('Success: immediate data'), findsOneWidget);
    });

    testWidgets('should work with manual error state transition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text('Success: $data'),
            onError: (error) => Text('Error: $error'),
            onInitial: () => const Text('Initial'),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      // Manual test of the error flow without using run()
      // This simulates what run() would do when an error occurs

      // 1. Set loading state (what run() does first)
      effect.loading();
      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      // 2. Set error state (what run() does when an exception occurs)
      effect.setError(Exception('async error'));
      await tester.pump();
      expect(find.text('Error: Exception: async error'), findsOneWidget);
    });

    group('Edge cases', () {
      testWidgets('should handle rapid state changes', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ZenEffectBuilder<String>(
              effect: effect,
              onLoading: () => const Text('Loading'),
              onSuccess: (data) => Text('Success: $data'),
              onError: (error) => Text('Error: $error'),
              onInitial: () => const Text('Initial'),
            ),
          ),
        );

        // Rapid state changes
        effect.loading();
        effect.success('data1');
        effect.setError('error1');
        effect.loading();
        effect.success('data2');

        await tester.pump();
        expect(find.text('Success: data2'), findsOneWidget);
      });

      testWidgets('should handle complex data types', (tester) async {
        final complexEffect = createEffect<Map<String, dynamic>>(name: 'complex');

        await tester.pumpWidget(
          MaterialApp(
            home: ZenEffectBuilder<Map<String, dynamic>>(
              effect: complexEffect,
              onLoading: () => const Text('Loading'),
              onSuccess: (data) => Text('Success: ${data['key']}'),
              onError: (error) => Text('Error: $error'),
              onInitial: () => const Text('Initial'),
            ),
          ),
        );

        complexEffect.success({'key': 'complex value'});
        await tester.pump();

        expect(find.text('Success: complex value'), findsOneWidget);

        complexEffect.dispose();
      });

      testWidgets('should handle multiple effects on same widget', (tester) async {
        final effect1 = createEffect<String>(name: 'effect1');
        final effect2 = createEffect<String>(name: 'effect2');

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                ZenEffectBuilder<String>(
                  effect: effect1,
                  onLoading: () => const Text('Loading 1'),
                  onSuccess: (data) => Text('Success 1: $data'),
                  onError: (error) => Text('Error 1: $error'),
                  onInitial: () => const Text('Initial 1'),
                ),
                ZenEffectBuilder<String>(
                  effect: effect2,
                  onLoading: () => const Text('Loading 2'),
                  onSuccess: (data) => Text('Success 2: $data'),
                  onError: (error) => Text('Error 2: $error'),
                  onInitial: () => const Text('Initial 2'),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Initial 1'), findsOneWidget);
        expect(find.text('Initial 2'), findsOneWidget);

        effect1.success('data 1');
        effect2.setError('error 2');

        await tester.pump();

        expect(find.text('Success 1: data 1'), findsOneWidget);
        expect(find.text('Error 2: error 2'), findsOneWidget);
        expect(find.text('Initial 1'), findsNothing);
        expect(find.text('Initial 2'), findsNothing);

        effect1.dispose();
        effect2.dispose();
      });

      testWidgets('should handle state priority correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ZenEffectBuilder<String>(
              effect: effect,
              onLoading: () => const Text('Loading'),
              onSuccess: (data) => Text('Success: $data'),
              onError: (error) => Text('Error: $error'),
              onInitial: () => const Text('Initial'),
            ),
          ),
        );

        // Set both error and loading - loading should take priority
        effect.setError('test error');
        effect.loading();

        await tester.pump();
        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('Error: test error'), findsNothing);

        // Set both success and error - error should take priority
        effect.success('test data');
        effect.setError('new error');

        await tester.pump();
        expect(find.text('Error: new error'), findsOneWidget);
        expect(find.text('Success: test data'), findsNothing);
      });
    });

    group('Performance tests', () {
      testWidgets('should not rebuild unnecessarily', (tester) async {
        int buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ZenEffectBuilder<String>(
              effect: effect,
              onLoading: () {
                buildCount++;
                return const Text('Loading');
              },
              onSuccess: (data) {
                buildCount++;
                return Text('Success: $data');
              },
              onError: (error) {
                buildCount++;
                return Text('Error: $error');
              },
              onInitial: () {
                buildCount++;
                return const Text('Initial');
              },
            ),
          ),
        );

        expect(buildCount, 1); // Initial build

        // Setting the same state multiple times should not trigger rebuilds
        effect.loading();
        await tester.pump();
        expect(buildCount, 2); // Loading build

        effect.loading(); // Same state
        await tester.pump();
        expect(buildCount, 2); // No additional build

        effect.success('data');
        await tester.pump();
        expect(buildCount, 3); // Success build

        effect.success('data'); // Same data
        await tester.pump();
        expect(buildCount, 3); // No additional build

        effect.success('different data'); // Different data
        await tester.pump();
        expect(buildCount, 4); // New build for different data
      });
    });
  });
}