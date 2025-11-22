import 'dart:async';

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

  group('ZenInfiniteQuery', () {
    test('initial fetch loads first page', () async {
      final query = ZenInfiniteQuery<String>(
        queryKey: 'infinite',
        initialPageParam: 1,
        infiniteFetcher: (page) async => 'page-$page',
        getNextPageParam: (lastPage, allPages) => null,
      );

      await query.fetch();

      expect(query.data.value, ['page-1']);
      expect(query.hasNextPage.value, false);
    });

    test('fetchNextPage appends data', () async {
      final query = ZenInfiniteQuery<String>(
        queryKey: 'infinite',
        initialPageParam: 1,
        infiniteFetcher: (page) async {
          return 'page-$page';
        },
        getNextPageParam: (lastPage, allPages) {
          if (allPages.length < 3) return allPages.length + 1;
          return null;
        },
      );

      // Load page 1
      await query.fetch();
      expect(query.data.value, ['page-1']);
      expect(query.hasNextPage.value, true);

      // Load page 2
      await query.fetchNextPage();
      expect(query.data.value, ['page-1', 'page-2']);
      expect(query.hasNextPage.value, true);

      // Load page 3
      await query.fetchNextPage();
      expect(query.data.value, ['page-1', 'page-2', 'page-3']);
      expect(query.hasNextPage.value, false);

      // Try loading page 4 (should do nothing)
      await query.fetchNextPage();
      expect(query.data.value, ['page-1', 'page-2', 'page-3']);
    });

    test('refresh resets pagination', () async {
      final query = ZenInfiniteQuery<String>(
        queryKey: 'infinite',
        initialPageParam: 1,
        infiniteFetcher: (page) async => 'page-$page',
        // Fix: Use allPages.length to calculate the next page index
        getNextPageParam: (lastPage, allPages) => allPages.length + 1,
      );

      await query.fetch();
      await query.fetchNextPage(); // Load page 2
      expect(query.data.value!.length, 2);

      // Force refresh (Pull to refresh)
      await query.refetch();

      // Should only have page 1
      expect(query.data.value, ['page-1']);
      // Should reset next page availability
      expect(query.hasNextPage.value, true);
    });

    test('handles fetchNextPage error without clearing data', () async {
      final query = ZenInfiniteQuery<String>(
        queryKey: 'infinite-error',
        initialPageParam: 1,
        infiniteFetcher: (page) async {
          if (page == 2) throw Exception('Network error');
          return 'page-$page';
        },
        getNextPageParam: (lastPage, allPages) => 2,
      );

      // Page 1 succeeds
      await query.fetch();
      expect(query.data.value, ['page-1']);
      expect(query.error.value, null);

      // Page 2 fails
      await query.fetchNextPage();

      // Data should remain
      expect(query.data.value, ['page-1']);
      // Error should be set
      expect(query.error.value, isA<Exception>());
      // Main status should still be success (because we have data)
      expect(query.status.value, ZenQueryStatus.success);
      // Loading state should clear
      expect(query.isFetchingNextPage.value, false);
    });

    test('isFetchingNextPage state management', () async {
      final completer = Completer<String>();

      final query = ZenInfiniteQuery<String>(
        queryKey: 'infinite-loading',
        initialPageParam: 1,
        infiniteFetcher: (page) async {
          if (page == 1) return 'page-1';
          return completer.future;
        },
        getNextPageParam: (lastPage, allPages) => 2,
      );

      await query.fetch();
      expect(query.isFetchingNextPage.value, false);

      // Start fetching next page
      final future = query.fetchNextPage();

      // Should be loading
      expect(query.isFetchingNextPage.value, true);

      // Complete the future
      completer.complete('page-2');
      await future;

      // Should stop loading
      expect(query.isFetchingNextPage.value, false);
      expect(query.data.value, ['page-1', 'page-2']);
    });
  });
}
