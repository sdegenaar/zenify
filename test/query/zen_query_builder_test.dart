import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  testWidgets('should render loading state initially', (tester) async {
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data';
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZenQueryBuilder<String>(
            query: query,
            builder: (context, data) => Text(data),
            loading: () => const Text('Loading...'),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('data'), findsOneWidget);
  });

  testWidgets('should render success state with data', (tester) async {
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: (_) async => 'success',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZenQueryBuilder<String>(
            query: query,
            builder: (context, data) => Text(data),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('success'), findsOneWidget);
  });

  testWidgets('should render error state on failure', (tester) async {
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: (_) async => throw Exception('Test error'),
      config: const ZenQueryConfig(retryCount: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZenQueryBuilder<String>(
            query: query,
            builder: (context, data) => Text(data),
            error: (error, retry) => Text('Error: $error'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('should show stale data while refetching', (tester) async {
    int fetchCount = 0;
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: (_) async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data-$fetchCount';
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZenQueryBuilder<String>(
            query: query,
            showStaleData: true,
            builder: (context, data) => Text(data),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('data-1'), findsOneWidget);

    query.refetch();
    await tester.pump();

    expect(find.text('data-1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('data-2'), findsOneWidget);
  });

  testWidgets('keepPreviousData shows old data while new query loads',
      (tester) async {
    final query1 = ZenQuery<String>(
      queryKey: 'q1',
      fetcher: (_) async {
        // ADDED DELAY to fix test flake
        await Future.delayed(const Duration(milliseconds: 50));
        return 'Data 1';
      },
    );

    // Use a ValueNotifier to drive the test
    final queryNotifier = ValueNotifier<ZenQuery<String>>(query1);

    // Build the widget tree ONCE
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<ZenQuery<String>>(
            valueListenable: queryNotifier,
            builder: (context, query, child) {
              return ZenQueryBuilder<String>(
                key: const GlobalObjectKey(
                    'builder'), // Use GlobalKey to force reuse
                query: query,
                keepPreviousData: true,
                builder: (context, data) => Text(data),
                loading: () => const Text('Loading...'),
              );
            },
          ),
        ),
      ),
    );

    // 1. Initial load (query1)
    await tester.pump(); // Start fetch
    expect(find.text('Loading...'), findsOneWidget);
    await tester.pumpAndSettle(); // Finish fetch
    expect(find.text('Data 1'), findsOneWidget);

    // 2. Create query2 AFTER query1 is loaded to prevent background fetching
    final query2 = ZenQuery<String>(
      queryKey: 'q2',
      fetcher: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'Data 2';
      },
    );

    // 3. Switch to Query 2
    queryNotifier.value = query2;
    await tester.pump(); // Trigger rebuild. This calls didUpdateWidget.

    // At this exact moment:
    // - query1 has data 'Data 1'
    // - query2 is idle/loading
    // - keepPreviousData is true
    // - didUpdateWidget should have set _previousData = 'Data 1'

    // Should show 'Data 1' (from previous)
    expect(find.text('Data 1'), findsOneWidget);
    // Should NOT show loading
    expect(find.text('Loading...'), findsNothing);

    // 4. Finish loading Query 2
    await tester.pumpAndSettle();
  });

  group('Missing Coverage Paths for ZenQueryBuilder', () {
    testWidgets('wrapper builder is called', (tester) async {
      final query =
          ZenQuery<String>(queryKey: 'wrapper', fetcher: (_) async => 'data');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenQueryBuilder<String>(
              query: query,
              builder: (context, data) => Text(data),
              wrapper: (context, child) => Container(
                key: const Key('wrapper-key'),
                child: child,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wrapper-key')), findsOneWidget);
    });

    testWidgets('default error UI branch and retry failure', (tester) async {
      bool failRetry = false;
      final query = ZenQuery<String>(
        queryKey: 'defaulterror',
        fetcher: (_) async {
          throw Exception(failRetry ? 'Retry fail' : 'First fail');
        },
        config: const ZenQueryConfig(retryCount: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenQueryBuilder<String>(
              query: query,
              builder: (context, data) => Text(data),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Verify default error UI elements
      expect(find.text('Query Error'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Trigger retry which fails again to hit _retry error handler
      failRetry = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle(); // will naturally complete and catch error

      // Delay to let timers complete
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('didUpdateWidget state transitions', (tester) async {
      final query1 = ZenQuery<String>(
        queryKey: 'q1',
        fetcher: (_) async => 'data1',
      );
      final queryNotifier = ValueNotifier<ZenQuery<String>>(query1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<ZenQuery<String>>(
              valueListenable: queryNotifier,
              builder: (context, query, child) {
                return ZenQueryBuilder<String>(
                  query: query,
                  builder: (context, data) => Text(data),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('data1'), findsOneWidget);

      // 1. Same query but re-pumped - hits 'else if (widget.query.hasData)'
      queryNotifier.notifyListeners();
      await tester.pump();

      // 2. Switch to a NEW query that ALREADY has data - hits 'if (widget.query.hasData)' inside switch
      final query2 = ZenQuery<String>(
        queryKey: 'q2',
        fetcher: (_) async => 'data2',
      );
      await query2.fetch(); // Pre-fetch so it has data

      queryNotifier.value = query2;
      await tester.pump();
      expect(find.text('data2'), findsOneWidget);

      // 3. Switch to a NEW query that has NO data, NO keepPreviousData
      final query3 = ZenQuery<String>(
        queryKey: 'q3',
        fetcher: (_) async => 'data3',
      );

      queryNotifier.value = query3;
      await tester.pump(); // hits 'No previous data strategy - reset'

      // 4. Switch to a NEW query that FAILS auto-fetch immediately
      final query4 = ZenQuery<String>(
        queryKey: 'q4',
        fetcher: (_) async => throw Exception('Autofetch fail'),
        config: const ZenQueryConfig(retryCount: 0),
      );

      queryNotifier.value = query4;
      await tester.pump();
      await tester.pumpAndSettle(); // let the fetch fail

      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });
}
