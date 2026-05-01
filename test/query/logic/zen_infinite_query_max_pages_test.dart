import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.init();
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() => Zen.reset());

  group('ZenInfiniteQuery.maxPages — memory page eviction', () {
    test('limits pages when scrolling forward (evicts oldest from head)',
        () async {
      final query = ZenInfiniteQuery<int>(
        queryKey: 'fwd_limit_test',
        maxPages: 2,
        initialPageParam: 0,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) => lastPage + 1,
      );

      await query.fetch(); // [0]
      expect(query.data.value, [0]);

      await query.fetchNextPage(); // [0, 1]
      expect(query.data.value, [0, 1]);

      await query.fetchNextPage(); // evict 0 → [1, 2]
      expect(query.data.value, [1, 2]);

      await query.fetchNextPage(); // evict 1 → [2, 3]
      expect(query.data.value, [2, 3]);

      query.dispose();
    });

    test('limits pages when scrolling backward (evicts newest from tail)',
        () async {
      final query = ZenInfiniteQuery<int>(
        queryKey: 'bwd_limit_test',
        maxPages: 2,
        initialPageParam: 5,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) => lastPage + 1,
        getPreviousPageParam: (firstPage, pages) =>
            firstPage > 0 ? firstPage - 1 : null,
      );

      await query.fetch(); // [5]
      await query.fetchNextPage(); // [5, 6]
      expect(query.data.value, [5, 6]);

      await query.fetchPreviousPage(); // prepend 4, evict 6 → [4, 5]
      expect(query.data.value, [4, 5]);

      await query.fetchPreviousPage(); // prepend 3, evict 5 → [3, 4]
      expect(query.data.value, [3, 4]);

      query.dispose();
    });

    test('null maxPages keeps all pages (no eviction)', () async {
      final query = ZenInfiniteQuery<int>(
        queryKey: 'null_limit_test',
        maxPages: null,
        initialPageParam: 0,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) => lastPage + 1,
      );

      await query.fetch();
      for (var i = 0; i < 5; i++) {
        await query.fetchNextPage();
      }

      expect(query.data.value, [0, 1, 2, 3, 4, 5]);
      query.dispose();
    });

    test('maxPages: 1 keeps only the latest page', () async {
      final query = ZenInfiniteQuery<int>(
        queryKey: 'single_page_test',
        maxPages: 1,
        initialPageParam: 0,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) => lastPage + 1,
      );

      await query.fetch(); // [0]
      await query.fetchNextPage(); // evict 0 → [1]
      expect(query.data.value, [1]);
      await query.fetchNextPage(); // evict 1 → [2]
      expect(query.data.value, [2]);

      query.dispose();
    });

    test('hasNextPage is correctly updated after forward eviction', () async {
      int pageCount = 0;
      final query = ZenInfiniteQuery<int>(
        queryKey: 'cursor_test',
        maxPages: 2,
        initialPageParam: 0,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) {
          // Only 3 pages available total
          pageCount = lastPage + 1;
          return pageCount < 3 ? pageCount : null;
        },
      );

      await query.fetch(); // [0]
      expect(query.hasNextPage.value, true);

      await query.fetchNextPage(); // [0, 1], eviction N/A
      expect(query.hasNextPage.value, true);

      await query.fetchNextPage(); // page 2 is last → evict 0 → [1, 2]
      expect(query.data.value, [1, 2]);
      expect(query.hasNextPage.value, false); // no more pages

      query.dispose();
    });

    test('throws AssertionError when maxPages is 0', () {
      expect(
        () => ZenInfiniteQuery<int>(
          queryKey: 'assert_test',
          maxPages: 0,
          initialPageParam: 0,
          infiniteFetcher: (page, token) async => page as int,
          getNextPageParam: (lastPage, pages) => null,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('maxPages: 3 evicts correctly after several bidirectional fetches',
        () async {
      final query = ZenInfiniteQuery<int>(
        queryKey: 'bidir_test',
        maxPages: 3,
        initialPageParam: 10,
        infiniteFetcher: (page, token) async => page as int,
        getNextPageParam: (lastPage, pages) => lastPage + 1,
        getPreviousPageParam: (firstPage, pages) =>
            firstPage > 0 ? firstPage - 1 : null,
      );

      await query.fetch(); // [10]
      await query.fetchNextPage(); // [10, 11]
      await query.fetchNextPage(); // [10, 11, 12]
      expect(query.data.value, [10, 11, 12]);

      await query.fetchNextPage(); // evict 10 → [11, 12, 13]
      expect(query.data.value, [11, 12, 13]);

      await query.fetchPreviousPage(); // prepend 10, evict 13 → [10, 11, 12]
      expect(query.data.value, [10, 11, 12]);

      query.dispose();
    });
  });
}
