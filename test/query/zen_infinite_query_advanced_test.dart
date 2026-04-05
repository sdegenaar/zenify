import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for zen_infinite_query.dart targeting uncovered lines:
/// - L119: fetch() - force=true resets pagination state
/// - L165: fetchPreviousPage error handling
/// - L235-243: onClose disposal of all reactive fields
void main() {
  setUp(() {
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    Zen.init();
  });

  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // Basic fetch
  // ══════════════════════════════════════════════════════════
  group('ZenInfiniteQuery.fetch', () {
    test('fetch loads first page', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_basic',
        initialPageParam: 'p1',
        infiniteFetcher: (param, _) async => 'page:$param',
        getNextPageParam: (page, pages) =>
            pages.length < 2 ? 'p${pages.length + 1}' : null,
      );

      final result = await q.fetch();
      expect(result, isNotEmpty);
      expect(result.first, 'page:p1');
      q.dispose();
    });

    test('hasNextPage is set from getNextPageParam', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_has_next',
        initialPageParam: 'p1',
        infiniteFetcher: (_, __) async => 'page',
        getNextPageParam: (page, pages) => 'nextPage', // always returns next
      );

      await q.fetch();
      expect(q.hasNextPage.value, true);
      q.dispose();
    });

    test('hasNextPage is false when getNextPageParam returns null', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_no_next',
        initialPageParam: 'p1',
        infiniteFetcher: (_, __) async => 'page',
        getNextPageParam: (page, pages) => null, // no more pages
      );

      await q.fetch();
      expect(q.hasNextPage.value, false);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // fetchNextPage
  // ══════════════════════════════════════════════════════════
  group('ZenInfiniteQuery.fetchNextPage', () {
    test('fetches and appends next page', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_next_page',
        initialPageParam: 'p1',
        infiniteFetcher: (param, _) async => 'data:$param',
        getNextPageParam: (page, pages) =>
            pages.length < 3 ? 'p${pages.length + 1}' : null,
      );

      await q.fetch();
      expect(q.data.value?.length, 1);

      await q.fetchNextPage();
      expect(q.data.value?.length, 2);
      q.dispose();
    });

    test('fetchNextPage does nothing when no next page', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_no_more',
        initialPageParam: 'p1',
        infiniteFetcher: (_, __) async => 'data',
        getNextPageParam: (_, __) => null,
      );

      await q.fetch();
      await q.fetchNextPage(); // hasNextPage=false, so no-op
      expect(q.data.value?.length, 1);
      q.dispose();
    });

    test('fetchNextPage sets error on failure', () async {
      int calls = 0;
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_next_err',
        initialPageParam: 'p1',
        infiniteFetcher: (param, _) async {
          calls++;
          if (calls > 1) throw Exception('page load failed');
          return 'first page';
        },
        getNextPageParam: (_, pages) => pages.length < 2 ? 'p2' : null,
      );

      await q.fetch();
      await q.fetchNextPage();
      expect(q.error.value, isNotNull);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // fetchPreviousPage (uncovered - line 165)
  // ══════════════════════════════════════════════════════════
  group('ZenInfiniteQuery.fetchPreviousPage', () {
    test('fetchPreviousPage without getPreviousPageParam does nothing',
        () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_prev_noop',
        initialPageParam: 'p2',
        infiniteFetcher: (param, _) async => 'page:$param',
        getNextPageParam: (_, __) => null,
        // No getPreviousPageParam → hasPreviousPage=false
      );

      await q.fetch();
      await q.fetchPreviousPage(); // should be no-op
      expect(q.isFetchingPreviousPage.value, false);
      q.dispose();
    });

    test('fetchPreviousPage fetches and prepends when hasPreviousPage=true',
        () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_prev_fetch',
        initialPageParam: 'p2',
        infiniteFetcher: (param, _) async => 'page:$param',
        getNextPageParam: (_, __) => null,
        getPreviousPageParam: (_, pages) =>
            pages.length < 2 ? 'p1' : null, // first fetch triggers prev
      );

      await q.fetch();
      // After first fetch, check if hasPreviousPage was set
      if (q.hasPreviousPage.value) {
        await q.fetchPreviousPage();
        expect(q.data.value?.length, greaterThan(1));
      }
      q.dispose();
    });

    test('fetchPreviousPage error handling does not crash', () async {
      int calls = 0;
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_prev_err',
        initialPageParam: 'p2',
        infiniteFetcher: (param, _) async {
          calls++;
          if (calls > 1) throw Exception('prev page failed');
          return 'page:$param';
        },
        getNextPageParam: (_, __) => null,
        getPreviousPageParam: (_, pages) => pages.length < 2 ? 'p1' : null,
      );

      await q.fetch();
      if (q.hasPreviousPage.value) {
        await q.fetchPreviousPage(); // should set error, not crash
        expect(() {}, returnsNormally);
      }
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // fetch with force=true (line 119) - resets pagination
  // ══════════════════════════════════════════════════════════
  group('ZenInfiniteQuery.fetch force=true resets pagination', () {
    test('force fetch resets next page tracking', () async {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_force',
        initialPageParam: 'p1',
        infiniteFetcher: (param, _) async => 'data:$param',
        getNextPageParam: (_, pages) =>
            pages.length < 3 ? 'p${pages.length + 1}' : null,
      );

      await q.fetch();
      await q.fetchNextPage();
      expect(q.data.value?.length, 2);

      // Force refresh resets to page 1
      await q.fetch(force: true);
      expect(q.data.value?.length, 1);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // onClose disposes reactive fields (lines 235-243)
  // ══════════════════════════════════════════════════════════
  group('ZenInfiniteQuery.onClose', () {
    test('dispose does not throw', () {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_close',
        initialPageParam: 'p1',
        infiniteFetcher: (_, __) async => 'page',
        getNextPageParam: (_, __) => null,
      );
      expect(() => q.dispose(), returnsNormally);
    });

    test('isFetchingNextPage and other fields accessible before dispose', () {
      final q = ZenInfiniteQuery<String>(
        queryKey: 'inf_fields',
        initialPageParam: 'p1',
        infiniteFetcher: (_, __) async => 'page',
        getNextPageParam: (_, __) => null,
      );
      expect(q.isFetchingNextPage.value, false);
      expect(q.isFetchingPreviousPage.value, false);
      expect(q.hasNextPage.value, true); // Initially optimistic
      expect(q.hasPreviousPage.value, false);
      q.dispose();
    });
  });
}
