import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQueryFilter Matching Unit Tests', () {
    test('exact key matching', () {
      final q1 = ZenQuery<String>(
        queryKey: 'users',
        fetcher: (_) async => 'users',
      );
      final q2 = ZenQuery<String>(
        queryKey: 'users:123',
        fetcher: (_) async => 'user-123',
      );

      final filterExact = const ZenQueryFilter(queryKey: 'users', exact: true);
      expect(filterExact.matches(q1), isTrue);
      expect(filterExact.matches(q2), isFalse);

      final filterNonExact =
          const ZenQueryFilter(queryKey: 'users', exact: false);
      expect(filterNonExact.matches(q1), isTrue);
      expect(filterNonExact.matches(q2), isTrue);

      final qSlash = ZenQuery<String>(
        queryKey: 'users/456',
        fetcher: (_) async => 'slash',
      );
      final qDot = ZenQuery<String>(
        queryKey: 'users.profile',
        fetcher: (_) async => 'dot',
      );
      final qOther = ZenQuery<String>(
        queryKey: 'users_extra',
        fetcher: (_) async => 'extra',
      );
      expect(filterNonExact.matches(qSlash), isTrue);
      expect(filterNonExact.matches(qDot), isTrue);
      expect(filterNonExact.matches(qOther), isFalse);
    });

    test('glob pattern wildcard matching (*)', () {
      final qUser = ZenQuery<String>(
        queryKey: 'user:profile:1',
        fetcher: (_) async => 'profile',
      );
      final qPost = ZenQuery<String>(
        queryKey: 'post:comments:99',
        fetcher: (_) async => 'comments',
      );
      final qFeed = ZenQuery<String>(
        queryKey: 'global_feed_items',
        fetcher: (_) async => 'feed',
      );

      final filterUserWildcard = const ZenQueryFilter(queryKey: 'user:*');
      expect(filterUserWildcard.matches(qUser), isTrue);
      expect(filterUserWildcard.matches(qPost), isFalse);
      expect(filterUserWildcard.matches(qFeed), isFalse);

      final filterComments = const ZenQueryFilter(queryKey: '*:comments:*');
      expect(filterComments.matches(qUser), isFalse);
      expect(filterComments.matches(qPost), isTrue);
      expect(filterComments.matches(qFeed), isFalse);

      final filterFeed = const ZenQueryFilter(queryKey: '*feed*');
      expect(filterFeed.matches(qFeed), isTrue);
      expect(filterFeed.matches(qUser), isFalse);
    });

    test('tag matching (any vs all)', () {
      final q = ZenQuery<String>(
        queryKey: 'tagged_item',
        tags: ['auth', 'profile', 'settings'],
        fetcher: (_) async => 'data',
      );

      // Any tag match
      final filterAny = const ZenQueryFilter(
        tags: ['profile', 'notifications'],
        matchAllTags: false,
      );
      expect(filterAny.matches(q), isTrue);

      final filterAnyMiss = const ZenQueryFilter(
        tags: ['billing', 'notifications'],
        matchAllTags: false,
      );
      expect(filterAnyMiss.matches(q), isFalse);

      // All tags match
      final filterAllHit = const ZenQueryFilter(
        tags: ['auth', 'settings'],
        matchAllTags: true,
      );
      expect(filterAllHit.matches(q), isTrue);

      final filterAllMiss = const ZenQueryFilter(
        tags: ['auth', 'billing'],
        matchAllTags: true,
      );
      expect(filterAllMiss.matches(q), isFalse);
    });

    test('QueryTypeFilter filtering (active, inactive, stale, fetching)',
        () async {
      final completer = Completer<String>();
      final qFetching = ZenQuery<String>(
        queryKey: 'fetching_q',
        fetcher: (_) => completer.future,
      );
      qFetching.fetch(); // start in-flight fetch

      final qFresh = ZenQuery<String>(
        queryKey: 'fresh_q',
        fetcher: (_) async => 'fresh',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );
      await qFresh.fetch();

      final qStale = ZenQuery<String>(
        queryKey: 'stale_q',
        fetcher: (_) async => 'stale',
        config: const ZenQueryConfig(staleTime: Duration.zero),
      );
      await qStale.fetch();

      final qDisabled = ZenQuery<String>(
        queryKey: 'disabled_q',
        enabled: false,
        fetcher: (_) async => 'disabled',
      );

      // Fetching
      expect(
          const ZenQueryFilter(type: QueryTypeFilter.fetching)
              .matches(qFetching),
          isTrue);
      expect(
          const ZenQueryFilter(type: QueryTypeFilter.fetching).matches(qFresh),
          isFalse);

      // Active vs Inactive
      expect(const ZenQueryFilter(type: QueryTypeFilter.active).matches(qFresh),
          isTrue);
      expect(
          const ZenQueryFilter(type: QueryTypeFilter.inactive)
              .matches(qDisabled),
          isTrue);
      expect(
          const ZenQueryFilter(type: QueryTypeFilter.active).matches(qDisabled),
          isFalse);

      // Stale
      expect(const ZenQueryFilter(type: QueryTypeFilter.stale).matches(qStale),
          isTrue);
      expect(const ZenQueryFilter(type: QueryTypeFilter.stale).matches(qFresh),
          isFalse);

      completer.complete('done');
    });

    test('custom predicate filtering', () {
      final q1 = ZenQuery<String>(
        queryKey: 'alpha',
        tags: ['groupA'],
        fetcher: (_) async => 'a',
      );
      final q2 = ZenQuery<String>(
        queryKey: 'beta',
        tags: ['groupB'],
        fetcher: (_) async => 'b',
      );

      final filter = ZenQueryFilter(
        predicate: (q) => q.tags.contains('groupA') && q.queryKey == 'alpha',
      );

      expect(filter.matches(q1), isTrue);
      expect(filter.matches(q2), isFalse);
    });

    test('matchesKeyAndTags for cache-only entries', () {
      final filter = const ZenQueryFilter(
        queryKey: 'workspace:*',
        tags: ['active'],
        matchAllTags: true,
      );

      expect(
        filter.matchesKeyAndTags(
          'workspace:456',
          queryTags: ['active', 'enterprise'],
        ),
        isTrue,
      );

      expect(
        filter.matchesKeyAndTags(
          'other:456',
          queryTags: ['active'],
        ),
        isFalse,
      );

      expect(
        filter.matchesKeyAndTags(
          'workspace:456',
          queryTags: ['inactive'],
        ),
        isFalse,
      );
    });
  });

  group('ZenQueryCache Batch Operations', () {
    test('getQueries returns filtered queries', () {
      ZenQuery<int>(queryKey: 'num:1', tags: ['even'], fetcher: (_) async => 2);
      ZenQuery<int>(queryKey: 'num:2', tags: ['even'], fetcher: (_) async => 4);
      ZenQuery<int>(queryKey: 'num:3', tags: ['odd'], fetcher: (_) async => 1);

      final evenQueries =
          Zen.queryCache.getQueries(const ZenQueryFilter(tags: ['even']));
      expect(evenQueries.length, equals(2));

      final allQueries = Zen.queryCache.getQueries();
      expect(allQueries.length, equals(3));
    });

    test('setQueriesData updates matching queries and cache', () async {
      final q1 = ZenQuery<Map<String, dynamic>>(
        queryKey: 'post:1',
        tags: ['posts'],
        fetcher: (_) async => {'id': 1, 'author': 'Old'},
      );
      final q2 = ZenQuery<Map<String, dynamic>>(
        queryKey: 'post:2',
        tags: ['posts'],
        fetcher: (_) async => {'id': 2, 'author': 'Old'},
      );
      final q3 = ZenQuery<Map<String, dynamic>>(
        queryKey: 'user:1',
        tags: ['users'],
        fetcher: (_) async => {'id': 1, 'name': 'User'},
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      expect(q1.data.value?['author'], equals('Old'));
      expect(q2.data.value?['author'], equals('Old'));

      // Batch update all posts
      Zen.setQueriesData<Map<String, dynamic>>(
        const ZenQueryFilter(tags: ['posts']),
        (oldData) => {...?oldData, 'author': 'Sebastian'},
      );

      expect(q1.data.value?['author'], equals('Sebastian'));
      expect(q2.data.value?['author'], equals('Sebastian'));
      expect(q3.data.value?['name'], equals('User')); // Unchanged
    });

    test('cancelQueries cancels in-flight requests on matching queries',
        () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();
      final c3 = Completer<String>();

      final q1 = ZenQuery<String>(
        queryKey: 'search:apple',
        tags: ['search'],
        fetcher: (_) => c1.future,
      );
      final q2 = ZenQuery<String>(
        queryKey: 'search:banana',
        tags: ['search'],
        fetcher: (_) => c2.future,
      );
      final q3 = ZenQuery<String>(
        queryKey: 'profile:user',
        tags: ['profile'],
        fetcher: (_) => c3.future,
      );

      q1.fetch();
      q2.fetch();
      q3.fetch();

      expect(q1.isFetching, isTrue);
      expect(q2.isFetching, isTrue);
      expect(q3.isFetching, isTrue);

      // Cancel only search queries
      Zen.cancelQueries(const ZenQueryFilter(tags: ['search']));

      expect(q1.isFetching, isFalse);
      expect(q2.isFetching, isFalse);
      expect(q3.isFetching, isTrue); // Profile still running

      c3.complete('profile_data');
    });

    test('resetQueries resets multiple queries to idle state', () async {
      final q1 = ZenQuery<String>(
        queryKey: 'item:1',
        tags: ['reset_me'],
        fetcher: (_) async => 'data1',
      );
      final q2 = ZenQuery<String>(
        queryKey: 'item:2',
        tags: ['reset_me'],
        fetcher: (_) async => 'data2',
      );
      final q3 = ZenQuery<String>(
        queryKey: 'keep:1',
        tags: ['keep_me'],
        fetcher: (_) async => 'data3',
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      expect(q1.hasData, isTrue);
      expect(q2.hasData, isTrue);
      expect(q3.hasData, isTrue);

      Zen.resetQueries(const ZenQueryFilter(tags: ['reset_me']));

      expect(q1.status.value, equals(ZenQueryStatus.idle));
      expect(q1.data.value, isNull);
      expect(q2.status.value, equals(ZenQueryStatus.idle));
      expect(q2.data.value, isNull);
      expect(q3.hasData, isTrue);
    });

    test('removeQueries removes entries from cache, query map, and tags',
        () async {
      final q1 = ZenQuery<String>(
        queryKey: 'cache:temp:1',
        tags: ['temp'],
        fetcher: (_) async => 't1',
      );
      final q2 = ZenQuery<String>(
        queryKey: 'cache:temp:2',
        tags: ['temp'],
        fetcher: (_) async => 't2',
      );
      final q3 = ZenQuery<String>(
        queryKey: 'cache:persist:1',
        tags: ['persist'],
        fetcher: (_) async => 'p1',
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      expect(
          Zen.queryCache.getCachedData<String>('cache:temp:1'), equals('t1'));
      expect(
          Zen.queryCache.getCachedData<String>('cache:temp:2'), equals('t2'));
      expect(Zen.queryCache.getCachedData<String>('cache:persist:1'),
          equals('p1'));

      Zen.removeQueries(const ZenQueryFilter(queryKey: 'cache:temp:*'));

      expect(Zen.queryCache.getCachedData<String>('cache:temp:1'), isNull);
      expect(Zen.queryCache.getCachedData<String>('cache:temp:2'), isNull);
      expect(Zen.queryCache.getCachedData<String>('cache:persist:1'),
          equals('p1'));
      expect(Zen.queryCache.getQuery('cache:temp:1'), isNull);
      // Tag index must be cleaned up — removed keys must not appear in tag lookups
      final tempTaggedAfterRemove = Zen.queryCache.getKeysByTag('temp');
      expect(tempTaggedAfterRemove, isEmpty);
      final persistTaggedAfterRemove = Zen.queryCache.getKeysByTag('persist');
      expect(persistTaggedAfterRemove, equals(['cache:persist:1']));
    });

    test('invalidateQueries with ZenQueryFilter invalidates matching queries',
        () async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;
      int fetchCount3 = 0;

      final q1 = ZenQuery<String>(
        queryKey: 'item:a',
        tags: ['alpha'],
        fetcher: (_) async {
          fetchCount1++;
          return 'v1';
        },
      );
      final q2 = ZenQuery<String>(
        queryKey: 'item:b',
        tags: ['alpha'],
        fetcher: (_) async {
          fetchCount2++;
          return 'v2';
        },
      );
      final q3 = ZenQuery<String>(
        queryKey: 'item:c',
        tags: ['beta'],
        fetcher: (_) async {
          fetchCount3++;
          return 'v3';
        },
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
      expect(fetchCount3, equals(1));

      // Invalidate with filter
      Zen.invalidateQueries(const ZenQueryFilter(tags: ['alpha']));

      // Active queries auto-refetch on invalidate
      await pumpEventQueue();

      expect(fetchCount1, equals(2));
      expect(fetchCount2, equals(2));
      expect(fetchCount3, equals(1)); // Untouched
    });

    test('invalidateQueries without arguments invalidates all queries',
        () async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      final q1 = ZenQuery<String>(
        queryKey: 'all_inv:1',
        fetcher: (_) async {
          fetchCount1++;
          return '1';
        },
      );
      final q2 = ZenQuery<String>(
        queryKey: 'all_inv:2',
        fetcher: (_) async {
          fetchCount2++;
          return '2';
        },
      );

      await q1.fetch();
      await q2.fetch();

      Zen.invalidateQueries();
      await pumpEventQueue();

      expect(fetchCount1, equals(2));
      expect(fetchCount2, equals(2));
    });

    test('refetchQueries with ZenQueryFilter refetches matching queries',
        () async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      final q1 = ZenQuery<String>(
        queryKey: 'rf:1',
        tags: ['rf_group'],
        fetcher: (_) async {
          fetchCount1++;
          return 'rf1';
        },
      );
      final q2 = ZenQuery<String>(
        queryKey: 'rf:2',
        tags: ['other_group'],
        fetcher: (_) async {
          fetchCount2++;
          return 'rf2';
        },
      );

      await q1.fetch();
      await q2.fetch();

      await Zen.refetchQueries(const ZenQueryFilter(tags: ['rf_group']));

      expect(fetchCount1, equals(2));
      expect(fetchCount2, equals(1));
    });

    test('isFetching and isFetchingCount with ZenQueryFilter', () {
      final completer = Completer<String>();
      final q1 = ZenQuery<String>(
        queryKey: 'fetch_status:1',
        tags: ['monitored'],
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.never),
        fetcher: (_) => completer.future,
      );
      final q2 = ZenQuery<String>(
        queryKey: 'fetch_status:2',
        tags: ['unmonitored'],
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.never),
        fetcher: (_) => Completer<String>().future,
      );

      expect(
          Zen.queryCache
              .isFetching(filter: const ZenQueryFilter(tags: ['monitored'])),
          isFalse);
      expect(
          Zen.queryCache.isFetchingCount(
              filter: const ZenQueryFilter(tags: ['monitored'])),
          equals(0));

      q1.fetch();

      expect(
          Zen.queryCache
              .isFetching(filter: const ZenQueryFilter(tags: ['monitored'])),
          isTrue);
      expect(
          Zen.queryCache.isFetchingCount(
              filter: const ZenQueryFilter(tags: ['monitored'])),
          equals(1));
      expect(
          Zen.queryCache
              .isFetching(filter: const ZenQueryFilter(tags: ['unmonitored'])),
          isFalse);

      q2.fetch();
      expect(
          Zen.queryCache.isFetchingCount(
              filter: const ZenQueryFilter(type: QueryTypeFilter.fetching)),
          equals(2));

      completer.complete('done');
    });

    test('ZenQuery.cancel cancels active request and resets fetch state',
        () async {
      final completer = Completer<String>();
      final query = ZenQuery<String>(
        queryKey: 'direct_cancel_key',
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.never),
        fetcher: (_) => completer.future,
      );

      final fetchFuture = query.fetch();
      expect(query.isFetching, isTrue);
      expect(query.isLoading.value, isTrue);

      query.cancel('User navigated away');

      expect(query.isFetching, isFalse);
      expect(query.isLoading.value, isFalse);
      expect(query.fetchStatus.value, equals(ZenQueryFetchStatus.idle));

      completer.complete('late_data');
      await fetchFuture.catchError((_) => 'handled');
    });

    test('invalidateQueries with ZenQuery predicate', () async {
      int fetchCount = 0;
      final q = ZenQuery<int>(
        queryKey: 'query_predicate_inv',
        tags: ['important'],
        fetcher: (_) async {
          fetchCount++;
          return fetchCount;
        },
      );
      await q.fetch();
      expect(fetchCount, equals(1));

      Zen.invalidateQueries(
          (ZenQuery query) => query.tags.contains('important'));
      await pumpEventQueue();

      expect(fetchCount, equals(2));
    });

    test('refetchQueries with ZenQuery predicate and parameterless refetchAll',
        () async {
      int c1 = 0;
      int c2 = 0;
      final q1 = ZenQuery<int>(
        queryKey: 'rf_pred:1',
        fetcher: (_) async {
          c1++;
          return c1;
        },
      );
      final q2 = ZenQuery<int>(
        queryKey: 'rf_pred:2',
        fetcher: (_) async {
          c2++;
          return c2;
        },
      );

      await q1.fetch();
      await q2.fetch();

      // Refetch with ZenQuery predicate
      await Zen.refetchQueries((ZenQuery q) => q.queryKey == 'rf_pred:1');
      expect(c1, equals(2));
      expect(c2, equals(1));

      // Refetch all active queries without arguments
      await Zen.refetchQueries();
      expect(c1, equals(3));
      expect(c2, equals(2));
    });

    test('setQueriesData and removeQueries on unmounted cache-only entries',
        () {
      // Populate cache without mounting ZenQuery instances
      Zen.queryCache
          .updateCache('cache_only:user:1', {'name': 'Alice'}, DateTime.now());
      Zen.queryCache
          .updateCache('cache_only:user:2', {'name': 'Bob'}, DateTime.now());
      Zen.queryCache
          .updateCache('cache_only:item:1', {'name': 'Widget'}, DateTime.now());

      expect(
          Zen.queryCache.getCachedData<Map<String, dynamic>>(
              'cache_only:user:1')?['name'],
          equals('Alice'));

      // Batch update all cache_only:user:*
      Zen.setQueriesData<Map<String, dynamic>>(
        const ZenQueryFilter(queryKey: 'cache_only:user:*'),
        (old) => {...?old, 'updated': true},
      );

      expect(
          Zen.queryCache.getCachedData<Map<String, dynamic>>(
              'cache_only:user:1')?['updated'],
          isTrue);
      expect(
          Zen.queryCache.getCachedData<Map<String, dynamic>>(
              'cache_only:user:2')?['updated'],
          isTrue);
      expect(
          Zen.queryCache.getCachedData<Map<String, dynamic>>(
              'cache_only:item:1')?['updated'],
          isNull);

      // Batch remove all cache_only:*
      Zen.removeQueries(const ZenQueryFilter(queryKey: 'cache_only:*'));

      expect(Zen.queryCache.getCachedData('cache_only:user:1'), isNull);
      expect(Zen.queryCache.getCachedData('cache_only:user:2'), isNull);
      expect(Zen.queryCache.getCachedData('cache_only:item:1'), isNull);
    });
  });
}
