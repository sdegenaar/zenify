import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenMutation.when()', () {
    testWidgets('shows idle widget before mutation is triggered',
        (tester) async {
      final mutation = ZenMutation<String, String>(
        mutationFn: (s) async => s.toUpperCase(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              loading: () => const Text('loading'),
              success: (data) => Text('success: $data'),
              error: (e) => const Text('error'),
            ),
          ),
        ),
      );

      expect(find.text('idle'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('shows loading widget while mutation is running',
        (tester) async {
      // Use a Completer so we control exactly when the mutation completes
      final completer = Completer<String>();
      final mutation = ZenMutation<String, String>(
        mutationFn: (_) => completer.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              loading: () => const Text('loading'),
              success: (data) => Text('success: $data'),
            ),
          ),
        ),
      );

      // Fire mutation without awaiting — mutation is now in loading state
      final future = mutation.mutate('hello');
      await tester.pump();

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('idle'), findsNothing);

      // Complete and clean up
      completer.complete('HELLO');
      await future;
      await tester.pump();
      expect(find.text('success: HELLO'), findsOneWidget);
    });

    testWidgets('shows success widget after mutation succeeds', (tester) async {
      final mutation = ZenMutation<String, String>(
        mutationFn: (s) async => s.toUpperCase(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              success: (data) => Text('success: $data'),
            ),
          ),
        ),
      );

      await mutation.mutate('hello');
      await tester.pumpAndSettle();

      expect(find.text('success: HELLO'), findsOneWidget);
      expect(find.text('idle'), findsNothing);
    });

    testWidgets('shows error widget after mutation fails', (tester) async {
      final mutation = ZenMutation<String, String>(
        mutationFn: (_) async => throw Exception('boom'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              error: (e) => const Text('error occurred'),
            ),
          ),
        ),
      );

      await mutation.mutate('hello');
      await tester.pumpAndSettle();

      expect(find.text('error occurred'), findsOneWidget);
      expect(find.text('idle'), findsNothing);
    });

    testWidgets('falls back to idle when optional builders not provided',
        (tester) async {
      final mutation = ZenMutation<String, String>(
        mutationFn: (s) async => s.toUpperCase(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              // no loading, success, or error provided
            ),
          ),
        ),
      );

      await mutation.mutate('hello');
      await tester.pumpAndSettle();

      // success builder not provided — falls back to idle
      expect(find.text('idle'), findsOneWidget);
    });

    testWidgets('reset() returns to idle state', (tester) async {
      final mutation = ZenMutation<String, String>(
        mutationFn: (s) async => s.toUpperCase(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mutation.when(
              idle: () => const Text('idle'),
              success: (data) => Text('success: $data'),
            ),
          ),
        ),
      );

      await mutation.mutate('hello');
      await tester.pumpAndSettle();
      expect(find.text('success: HELLO'), findsOneWidget);

      mutation.reset();
      await tester.pumpAndSettle();
      expect(find.text('idle'), findsOneWidget);
    });
  });
}
