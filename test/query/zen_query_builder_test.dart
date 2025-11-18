import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    // Use test mode - automatically configures cache and clears it
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  testWidgets('should render loading state initially', (tester) async {
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: () async {
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

    // Wait for post-frame callback to execute and start the fetch
    await tester.pump();

    expect(find.text('Loading...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('data'), findsOneWidget);
  });

  testWidgets('should render success state with data', (tester) async {
    final query = ZenQuery<String>(
      queryKey: 'test',
      fetcher: () async => 'success',
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
      fetcher: () async => throw Exception('Test error'),
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
      fetcher: () async {
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

    // Trigger refetch
    query.refetch();
    await tester.pump();

    // Should still show old data while refetching
    expect(find.text('data-1'), findsOneWidget);

    await tester.pumpAndSettle();

    // Should now show new data
    expect(find.text('data-2'), findsOneWidget);
  });
}
