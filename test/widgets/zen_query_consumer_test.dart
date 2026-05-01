// test/widgets/zen_query_consumer_test.dart
//
// Widget tests for ZenQueryConsumer.
//
// Pattern note: After any test that successfully fetches data, call
// `await tester.binding.delayed(const Duration(minutes: 6))` to drain
// the 5-minute cache eviction timer set by ZenQueryCache._setCacheEntry.
// This is the established convention across the zenify widget test suite.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps a widget in the minimal Flutter tree required for widget tests.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // =========================================================================
  // Happy path
  // =========================================================================

  group('ZenQueryConsumer happy path', () {
    testWidgets('renders data widget when fetch succeeds', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'greeting',
          fetcher: (_) => completer.future,
          data: (value) => Text('Result: $value'),
          loading: () => const Text('loading'),
        ),
      ));

      // Initial render — loading state
      expect(find.text('loading'), findsOneWidget);

      completer.complete('hello');
      await tester.pumpAndSettle();

      expect(find.text('Result: hello'), findsOneWidget);
      expect(find.text('loading'), findsNothing);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('renders data immediately when initialData is provided',
        (tester) async {
      // Never completes — we rely entirely on initialData
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'initial-data',
          fetcher: (_) => completer.future,
          initialData: 'initial',
          data: (value) => Text('Result: $value'),
        ),
      ));

      // initialData is shown immediately — no pump needed
      expect(find.text('Result: initial'), findsOneWidget);

      // Clean up the pending fetch
      completer.complete('fresh');
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('overwrites initialData with fetched data', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'overwrite-initial',
          fetcher: (_) => completer.future,
          initialData: 'initial',
          data: (value) => Text('Result: $value'),
        ),
      ));

      expect(find.text('Result: initial'), findsOneWidget);

      completer.complete('fresh');
      await tester.pumpAndSettle();

      expect(find.text('Result: fresh'), findsOneWidget);

      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });

  // =========================================================================
  // Loading state
  // =========================================================================

  group('ZenQueryConsumer loading state', () {
    testWidgets('shows custom loading builder while fetching', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'custom-loading',
          fetcher: (_) => completer.future,
          data: (v) => Text(v),
          loading: () => const Text('LOADING'),
        ),
      ));

      expect(find.text('LOADING'), findsOneWidget);

      // Drain the pending fetch + timer
      completer.complete('ok');
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets(
        'shows default CircularProgressIndicator when no loading builder',
        (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'default-loading',
          fetcher: (_) => completer.future,
          data: (v) => Text(v),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete('ok');
      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });

  // =========================================================================
  // Error state
  // =========================================================================

  group('ZenQueryConsumer error state', () {
    testWidgets('shows error builder when fetch throws', (tester) async {
      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'fail-query',
          fetcher: (_) async => throw Exception('network down'),
          data: (v) => Text(v),
          error: (err, _) => Text('ERROR: $err'),
          config: ZenQueryConfig(retryCount: 0),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('ERROR:'), findsOneWidget);
    });

    testWidgets('retry callback triggers a new fetch', (tester) async {
      int fetchCount = 0;
      VoidCallback? capturedRetry;
      bool shouldFail = true;
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'retry-query',
          fetcher: (_) {
            fetchCount++;
            if (shouldFail) return Future.error(Exception('first fail'));
            return completer.future;
          },
          data: (v) => Text('data: $v'),
          error: (err, retry) {
            capturedRetry = retry;
            return const Text('error');
          },
          config: ZenQueryConfig(retryCount: 0),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);
      expect(capturedRetry, isNotNull);
      expect(fetchCount, 1);

      // Trigger retry — new fetch in flight
      shouldFail = false;
      capturedRetry!();
      await tester.pump();

      // While retry fetch is pending, loading state is shown
      expect(find.text('error'), findsNothing);

      completer.complete('ok');
      await tester.pumpAndSettle();
      expect(find.text('data: ok'), findsOneWidget);
      expect(fetchCount, 2);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('shows default error widget when no error builder',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'default-error',
          fetcher: (_) async => throw Exception('boom'),
          data: (v) => Text(v),
          config: ZenQueryConfig(retryCount: 0),
        ),
      ));

      await tester.pumpAndSettle();
      // Built-in error widget shows this title
      expect(find.text('Query Error'), findsOneWidget);
    });
  });

  // =========================================================================
  // Idle state
  // =========================================================================

  group('ZenQueryConsumer idle state', () {
    testWidgets('shows idle builder when autoFetch is false', (tester) async {
      // Use a query that only settles immediately when called explicitly.
      // autoFetch: false means the ZenQueryBuilder won't trigger a fetch.
      // ZenQuery._initData still runs but respects RefetchBehavior.never
      // when the config is set accordingly.
      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'idle-test',
          fetcher: (_) async => 'data',
          autoFetch: false,
          config: ZenQueryConfig(
            refetchOnMount: RefetchBehavior.never,
            retryCount: 0,
          ),
          data: (v) => Text(v),
          idle: () => const Text('IDLE'),
        ),
      ));

      await tester.pump();
      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('data'), findsNothing);
    });
  });

  // =========================================================================
  // queryKey change
  // =========================================================================

  group('ZenQueryConsumer queryKey change', () {
    testWidgets('creates new query when queryKey changes', (tester) async {
      final List<String> fetchedKeys = [];

      Widget buildConsumer(String key) => _wrap(
            ZenQueryConsumer<String>(
              key: ValueKey(key),
              queryKey: key,
              fetcher: (_) async {
                fetchedKeys.add(key);
                return 'data-$key';
              },
              data: (v) => Text(v),
              loading: () => const Text('loading'),
            ),
          );

      // Mount with key-a
      await tester.pumpWidget(buildConsumer('key-a'));
      await tester.pumpAndSettle();
      expect(find.text('data-key-a'), findsOneWidget);

      // Switch to key-b
      await tester.pumpWidget(buildConsumer('key-b'));
      await tester.pumpAndSettle();
      expect(find.text('data-key-b'), findsOneWidget);
      expect(fetchedKeys.contains('key-b'), isTrue);

      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });

  // =========================================================================
  // Disposal
  // =========================================================================

  group('ZenQueryConsumer disposal', () {
    testWidgets('disposes query cleanly when widget is removed',
        (tester) async {
      bool widgetVisible = true;
      final completer = Completer<String>();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(
            Column(
              children: [
                if (widgetVisible)
                  ZenQueryConsumer<String>(
                    queryKey: 'disposable',
                    fetcher: (_) => completer.future,
                    data: (v) => Text(v),
                    loading: () => const Text('loading'),
                  ),
                ElevatedButton(
                  onPressed: () => setState(() => widgetVisible = false),
                  child: const Text('remove'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);

      // Remove the widget — disposes the query
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      expect(find.text('loading'), findsNothing);

      // Completing after disposal should not throw
      expect(() => completer.complete('late'), returnsNormally);
    });
  });

  // =========================================================================
  // API surface
  // =========================================================================

  group('ZenQueryConsumer API surface', () {
    testWidgets('accepts ZenQueryConfig and passes it to query',
        (tester) async {
      int fetchCount = 0;

      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<String>(
          queryKey: 'configured',
          fetcher: (_) async {
            fetchCount++;
            return 'ok';
          },
          config: ZenQueryConfig(
            staleTime: const Duration(minutes: 10),
            retryCount: 0,
          ),
          data: (v) => Text(v),
          loading: () => const Text('loading'),
        ),
      ));

      await tester.pumpAndSettle();

      // Only fetched once — data is fresh for 10 min
      expect(fetchCount, 1);
      expect(find.text('ok'), findsOneWidget);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('data builder receives the correct typed value',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ZenQueryConsumer<int>(
          queryKey: 'typed',
          fetcher: (_) async => 42,
          data: (n) => Text('Number: $n'),
          loading: () => const Text('loading'),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Number: 42'), findsOneWidget);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('widget type is exported from zenify barrel', (tester) async {
      // Smoke test: just verify ZenQueryConsumer is accessible from the
      // public barrel and can be instantiated without compile errors.
      final consumer = ZenQueryConsumer<String>(
        queryKey: 'export-check',
        fetcher: (_) async => 'ok',
        data: (v) => Text(v),
      );
      expect(consumer, isA<ZenQueryConsumer<String>>());
    });
  });
}
