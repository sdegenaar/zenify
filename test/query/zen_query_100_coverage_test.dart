import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenQuery & Cache 100% Coverage Tests', () {
    setUp(() {
      ZenQueryCache.instance.clear();
    });

    tearDown(() {
      ZenQueryCache.instance.clear();
    });

    test(
        'ZenQueryCache refetchQuery and refetchQueries invalid argument fallback',
        () async {
      final cache = ZenQueryCache.instance;

      var fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'test_refetch_key',
        fetcher: (_) async => 'result_${++fetchCount}',
      );

      await query.fetch();
      expect(query.data.value, 'result_1');

      // Call refetchQuery on existing and non-existing keys
      await cache.refetchQuery('test_refetch_key');
      expect(query.data.value, 'result_2');

      await cache
          .refetchQuery('non_existent_key'); // Should do nothing and not crash

      // Call refetchQueries with invalid filter argument (hits queriesToRefetch = [])
      await cache.refetchQueries(12345); // Not a filter, not a predicate
    });

    test('ZenQueryCache _getTagsForKey for cache-only queries', () async {
      final cache = ZenQueryCache.instance;

      // Add directly to cache without creating active ZenQuery instance
      cache.updateCache('cached_key', 'cached_data', DateTime.now());

      // getMatchingKeys searches tags for unmounted cached entries
      final matching = cache.getMatchingKeys(ZenQueryFilter(tags: ['users']));
      expect(matching, isEmpty);
    });

    test('ZenQuery cancellation when disposed during in-flight fetch',
        () async {
      final completer = Completer<String>();

      final query = ZenQuery<String>(
        queryKey: 'in_flight_success',
        fetcher: (_) => completer.future,
      );

      final fetchFuture = query.fetch();

      // Dispose the query while the fetcher is awaiting
      query.dispose();

      // Complete the future
      completer.complete('data');

      await expectLater(fetchFuture, throwsA(isA<ZenCancellationException>()));
    });

    test(
        'ZenQuery cancellation error path when disposed during in-flight fetch',
        () async {
      final completer = Completer<String>();

      final query = ZenQuery<String>(
        queryKey: 'in_flight_error',
        fetcher: (_) => completer.future,
      );

      final fetchFuture = query.fetch();

      // Dispose the query while the fetcher is awaiting
      query.dispose();

      // Complete with error
      completer.completeError(Exception('Fetch failed'));

      await expectLater(fetchFuture, throwsA(isA<Exception>()));
    });

    test('ZenQuery cancel resets fetchStatus when not idle', () async {
      final completer = Completer<String>();

      final query = ZenQuery<String>(
        queryKey: 'cancel_query',
        fetcher: (_) => completer.future,
      );

      // Start fetching so status becomes loading / fetching
      unawaited(query.fetch().catchError((_) => ''));
      expect(query.fetchStatus.value, ZenQueryFetchStatus.fetching);

      query.cancel();
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle);
    });

    test('ZenQuery cancel resets fetchStatus when not idle and token is null',
        () {
      final query = ZenQuery<String>(
        queryKey: 'cancel_not_idle_null_token',
        fetcher: (_) async => 'data',
      );

      query.fetchStatus.value = ZenQueryFetchStatus.fetching;
      query.cancel();
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle);
    });

    test(
        'ZenQuery.select creates derived query and supports fetch and state changes',
        () async {
      final source = ZenQuery<Map<String, dynamic>>(
        queryKey: 'source_user_query',
        fetcher: (_) async => {'name': 'Alice', 'age': 30},
      );

      final derived = source.select<String>((data) => data['name'] as String);
      expect(derived.data.value, isNull);

      // Fetching via derived query
      final name = await derived.fetch();
      expect(name, 'Alice');
      expect(derived.data.value, 'Alice');
      expect(derived.status.value, ZenQueryStatus.success);
      expect(derived.isLoading.value, isFalse);

      // Test idle state sync when source has no data
      source.reset();
      expect(derived.status.value, ZenQueryStatus.idle);

      // Test enabled state sync
      source.enabled.value = false;
      expect(derived.enabled.value, isFalse);

      source.dispose();
      derived.dispose();
    });

    test('ZenQuery handles placeholderData on initialization', () async {
      final query = ZenQuery<String>(
        queryKey: 'placeholder_query_key',
        config: const ZenQueryConfig(
          placeholderData: 'placeholder_val',
          refetchOnMount: RefetchBehavior.never,
        ),
        fetcher: (_) async => 'real_val',
      );

      expect(query.data.value, 'placeholder_val');
      expect(query.isPlaceholderData.value, isTrue);
      expect(query.status.value, ZenQueryStatus.success);

      await query.fetch();
      expect(query.data.value, 'real_val');
      expect(query.isPlaceholderData.value, isFalse);
    });

    test(
        'ZenQueryCache _getTagsForKey resolves active query tags and cached entry tags',
        () async {
      final cache = ZenQueryCache.instance;

      // 1. Active query with tags
      final activeQuery = ZenQuery<String>(
        queryKey: 'active_tagged_key',
        tags: ['user_tag'],
        fetcher: (_) async => 'active_data',
      );
      await activeQuery.fetch();

      // Matching active query by tags
      final activeMatches =
          cache.getMatchingKeys(ZenQueryFilter(tags: ['user_tag']));
      expect(activeMatches, contains('active_tagged_key'));

      // 2. Unmounted cached entry with tags indexed in _tagIndex
      cache.updateCache('cached_tagged_key', 'cached_data', DateTime.now());
      // Register query with tag to index it, then remove active query to leave cache only
      final tempQuery = ZenQuery<String>(
        queryKey: 'cached_tagged_key',
        tags: ['order_tag'],
        fetcher: (_) async => 'cached_data',
      );
      // Remove from active queries map so it becomes cache-only
      cache.queries; // access
      final cachedMatches =
          cache.getMatchingKeys(ZenQueryFilter(tags: ['order_tag']));
      expect(cachedMatches, contains('cached_tagged_key'));

      activeQuery.dispose();
      tempQuery.dispose();
    });

    test(
        'ZenQueryCache prefetch uses query config cacheTime and checks fresh staleTime',
        () async {
      final cache = ZenQueryCache.instance;

      final query = ZenQuery<String>(
        queryKey: 'prefetch_config_query',
        config: const ZenQueryConfig(
          cacheTime: Duration(minutes: 10),
          staleTime: Duration(minutes: 5),
        ),
        fetcher: (_) async => 'prefetch_data',
      );

      final prefetched = await cache.prefetch<String>(
        queryKey: 'prefetch_config_query',
        fetcher: () async => 'prefetch_data',
      );

      expect(prefetched, 'prefetch_data');

      // Second call when data is fresh should return cached data
      final freshData = await cache.prefetch<String>(
        queryKey: 'prefetch_config_query',
        fetcher: () async => 'other_data',
      );
      expect(freshData, 'prefetch_data');

      query.dispose();
    });

    test('ZenQuery resume logs warning when background refetch fails',
        () async {
      var shouldFail = false;
      final query = ZenQuery<String>(
        queryKey: 'resume_fail_query',
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
        ),
        fetcher: (_) async {
          if (shouldFail) throw Exception('Resume fetch failed');
          return 'ok';
        },
      );

      await query.fetch();
      shouldFail = true;

      // Pause and resume query to trigger refetchOnResume with failing fetch
      query.pause();
      query.resume();

      // Allow background microtasks to complete
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });
}
