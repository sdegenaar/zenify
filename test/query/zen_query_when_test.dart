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

  group('ZenQuery.when()', () {
    testWidgets('shows loading widget while fetching', (tester) async {
      final query = ZenQuery<String>(
        queryKey: 'test-loading',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'data';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
              loading: () => const Text('loading'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('loading'), findsOneWidget);
      expect(find.text('data'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('data'), findsOneWidget);
    });

    testWidgets('shows data widget when query succeeds', (tester) async {
      final query = ZenQuery<String>(
        queryKey: 'test-data',
        fetcher: (_) async => 'hello',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
              loading: () => const Text('loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('shows error widget on failure', (tester) async {
      final query = ZenQuery<String>(
        queryKey: 'test-error',
        fetcher: (_) async => throw Exception('boom'),
        config: const ZenQueryConfig(retryCount: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
              loading: () => const Text('loading'),
              error: (e, _) => const Text('error occurred'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('error occurred'), findsOneWidget);
    });

    testWidgets('uses default fallback when loading/error not provided',
        (tester) async {
      final query = ZenQuery<String>(
        queryKey: 'test-defaults',
        fetcher: (_) async => 'result',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
            ),
          ),
        ),
      );

      // Should not crash without optional builders
      await tester.pumpAndSettle();
      expect(find.text('result'), findsOneWidget);
    });

    testWidgets('idle builder shown when query is disabled', (tester) async {
      final query = ZenQuery<String>(
        queryKey: 'test-idle',
        fetcher: (_) async => 'data',
        enabled: false, // query never fetches until enabled
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
              idle: () => const Text('idle'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('idle'), findsOneWidget);
    });

    testWidgets('retry callback triggers refetch', (tester) async {
      var fetchCount = 0;
      late VoidCallback capturedRetry;

      final query = ZenQuery<String>(
        queryKey: 'test-retry',
        fetcher: (_) async {
          fetchCount++;
          throw Exception('fail');
        },
        config: const ZenQueryConfig(retryCount: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (d) => Text(d),
              error: (e, retry) {
                capturedRetry = retry;
                return const Text('error');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);
      final countAfterFirst = fetchCount;

      capturedRetry();
      await tester.pumpAndSettle();
      expect(fetchCount, greaterThan(countAfterFirst));
    });
  });
}
