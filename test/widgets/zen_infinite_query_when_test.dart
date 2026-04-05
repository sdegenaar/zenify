import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  group('ZenInfiniteQuery.when extension', () {
    testWidgets('renders loading state initially', (WidgetTester tester) async {
      final query = ZenInfiniteQuery<List<String>>(
        queryKey: 'test_infinite_when_loading',
        infiniteFetcher: (pageParam, cancelToken) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return ['item-${pageParam ?? 0}'];
        },
        getNextPageParam: (lastPage, allPages) => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (pages, hasNextPage, fetchNextPage) => const Text('data'),
              loading: () => const Text('loading'),
              error: (error, retry) => const Text('error'),
            ),
          ),
        ),
      );

      // Initially loading
      expect(find.text('loading'), findsOneWidget);
      query.dispose();
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('renders data state and maps parameters correctly',
        (WidgetTester tester) async {
      final query = ZenInfiniteQuery<List<String>>(
        queryKey: 'test_infinite_when_data',
        infiniteFetcher: (pageParam, cancelToken) async =>
            ['item-${pageParam ?? 0}'],
        getNextPageParam: (lastPage, allPages) =>
            allPages.length < 2 ? allPages.length : null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (pages, hasNextPage, fetchNextPage) {
                final pagesStr = pages.expand((e) => e).join(', ');
                return Column(
                  children: [
                    Text('data: $pagesStr (hasNext: $hasNextPage)'),
                    if (hasNextPage)
                      ElevatedButton(
                        onPressed: fetchNextPage,
                        child: const Text('load more'),
                      ),
                  ],
                );
              },
              loading: () => const Text('loading'),
            ),
          ),
        ),
      );

      // Wait for first fetch
      await tester.pumpAndSettle();
      expect(find.text('data: item-0 (hasNext: true)'), findsOneWidget);
      expect(find.text('load more'), findsOneWidget);

      // Trigger next page fetch
      await tester.tap(find.text('load more'));
      await tester.pumpAndSettle();

      expect(
          find.text('data: item-0, item-1 (hasNext: false)'), findsOneWidget);
      expect(find.text('load more'), findsNothing);

      query.dispose();
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('renders error state', (WidgetTester tester) async {
      bool shouldThrow = true;
      final query = ZenInfiniteQuery<List<String>>(
        queryKey: 'test_infinite_when_error',
        infiniteFetcher: (pageParam, cancelToken) async {
          if (shouldThrow) throw Exception('API Error');
          return ['item'];
        },
        getNextPageParam: (lastPage, allPages) => null,
      );

      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: query.when(
              data: (pages, hasNextPage, fetchNextPage) => const Text('data'),
              error: (error, retry) {
                return ElevatedButton(
                  onPressed: () {
                    retryCalled = true;
                    retry();
                  },
                  child: const Text('retry btn'),
                );
              },
            ),
          ),
        ),
      );

      // Wait for fetch to fail
      await tester.pumpAndSettle();
      expect(find.text('retry btn'), findsOneWidget);

      // Perform retry
      shouldThrow = false;
      await tester.tap(find.text('retry btn'));
      expect(retryCalled, true);

      await tester.pumpAndSettle();
      expect(find.text('data'), findsOneWidget);

      query.dispose();
      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });
}
