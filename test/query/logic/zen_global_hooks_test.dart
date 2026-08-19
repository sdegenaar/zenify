import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.init();
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() {
    Zen.reset();
  });

  group('Zen.isFetching & Zen.activeFetches — Global Query Status', () {
    test('initial state is false and 0', () {
      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));
      expect(ZenQuery.anyFetching, isFalse);
      expect(ZenQuery.activeFetches.value, equals(0));
    });

    test('tracks single in-flight query fetch', () async {
      final completer = Completer<String>();
      final query = ZenQuery<String>(
        queryKey: 'fetch_test_single',
        fetcher: (_) => completer.future,
        config: const ZenQueryConfig(staleTime: Duration.zero),
      );

      final fetchFuture = query.fetch();
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      completer.complete('data');
      await fetchFuture;

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));
      query.dispose();
    });

    test('tracks multiple concurrent query fetches', () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();

      final q1 = ZenQuery<String>(
        queryKey: 'fetch_test_multi_1',
        fetcher: (_) => c1.future,
        config: const ZenQueryConfig(staleTime: Duration.zero),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'fetch_test_multi_2',
        fetcher: (_) => c2.future,
        config: const ZenQueryConfig(staleTime: Duration.zero),
      );

      final f1 = q1.fetch();
      final f2 = q2.fetch();
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(2));

      c1.complete('d1');
      await f1;

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      c2.complete('d2');
      await f2;

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));

      q1.dispose();
      q2.dispose();
    });

    test('decrements activeFetches even when query fetcher throws', () async {
      final query = ZenQuery<String>(
        queryKey: 'fetch_test_error',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw Exception('network failure');
        },
        config: const ZenQueryConfig(
          retryCount: 0,
          staleTime: Duration.zero,
        ),
      );

      final future = query.fetch();
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      try {
        await future;
      } catch (_) {}

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));
      query.dispose();
    });

    test(
        'tracks fetch during ZenInfiniteQuery fetchNextPage and fetchPreviousPage',
        () async {
      final nextCompleter = Completer<int>();
      final prevCompleter = Completer<int>();

      final infiniteQuery = ZenInfiniteQuery<int>(
        queryKey: 'infinite_global_fetch_test',
        initialPageParam: 1,
        infiniteFetcher: (param, token) {
          if (param == 1) return Future.value(1);
          if (param == 2) return nextCompleter.future;
          if (param == 0) return prevCompleter.future;
          return Future.value(param as int);
        },
        getNextPageParam: (last, all) => last == 1 ? 2 : null,
        getPreviousPageParam: (first, all) => first == 1 ? 0 : null,
      );

      await infiniteQuery.fetch();
      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));

      // Fetch next page
      final nextFuture = infiniteQuery.fetchNextPage();
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      nextCompleter.complete(2);
      await nextFuture;

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));

      // Fetch previous page
      final prevFuture = infiniteQuery.fetchPreviousPage();
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      prevCompleter.complete(0);
      await prevFuture;

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));

      infiniteQuery.dispose();
    });

    test('tracks fetch during ZenQueryCache prefetch', () async {
      final completer = Completer<String>();

      final prefetchFuture = Zen.queryCache.prefetch<String>(
        queryKey: 'prefetch_global_test',
        fetcher: () => completer.future,
      );
      await Future.delayed(Duration.zero);

      expect(Zen.isFetching, isTrue);
      expect(Zen.activeFetches.value, equals(1));

      completer.complete('prefetched_data');
      final result = await prefetchFuture;

      expect(result, equals('prefetched_data'));
      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));
    });
  });

  group('Zen.isMutating & Zen.activeMutations — Global Mutation Status', () {
    test('initial state is false and 0', () {
      expect(Zen.isMutating, isFalse);
      expect(Zen.activeMutations.value, equals(0));
      expect(ZenMutation.anyMutating, isFalse);
      expect(ZenMutation.activeMutations.value, equals(0));
    });

    test('tracks single in-flight mutation', () async {
      final completer = Completer<String>();
      final mutation = ZenMutation<String, void>(
        mutationFn: (_) => completer.future,
      );

      final mutateFuture = mutation.mutate(null);
      await Future.delayed(Duration.zero);

      expect(Zen.isMutating, isTrue);
      expect(Zen.activeMutations.value, equals(1));

      completer.complete('saved');
      await mutateFuture;

      expect(Zen.isMutating, isFalse);
      expect(Zen.activeMutations.value, equals(0));
      mutation.dispose();
    });

    test('tracks multiple concurrent mutations', () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();

      final m1 = ZenMutation<String, void>(mutationFn: (_) => c1.future);
      final m2 = ZenMutation<String, void>(mutationFn: (_) => c2.future);

      final f1 = m1.mutate(null);
      final f2 = m2.mutate(null);
      await Future.delayed(Duration.zero);

      expect(Zen.isMutating, isTrue);
      expect(Zen.activeMutations.value, equals(2));

      c1.complete('res1');
      await f1;

      expect(Zen.isMutating, isTrue);
      expect(Zen.activeMutations.value, equals(1));

      c2.complete('res2');
      await f2;

      expect(Zen.isMutating, isFalse);
      expect(Zen.activeMutations.value, equals(0));

      m1.dispose();
      m2.dispose();
    });

    test('tracks keyed mutations via isMutatingKey & activeMutationsForKey',
        () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();

      final userMutation = ZenMutation<String, void>(
        mutationKey: 'user_update',
        mutationFn: (_) => c1.future,
      );
      final cartMutation = ZenMutation<String, void>(
        mutationKey: 'cart_checkout',
        mutationFn: (_) => c2.future,
      );

      expect(ZenMutation.isMutatingKey('user_update'), isFalse);
      expect(ZenMutation.activeMutationsForKey('user_update'), equals(0));

      final f1 = userMutation.mutate(null);
      final f2 = cartMutation.mutate(null);
      await Future.delayed(Duration.zero);

      expect(ZenMutation.isMutatingKey('user_update'), isTrue);
      expect(ZenMutation.activeMutationsForKey('user_update'), equals(1));
      expect(ZenMutation.isMutatingKey('cart_checkout'), isTrue);
      expect(ZenMutation.activeMutationsForKey('cart_checkout'), equals(1));
      expect(ZenMutation.isMutatingKey('other_key'), isFalse);

      c1.complete('ok1');
      await f1;

      expect(ZenMutation.isMutatingKey('user_update'), isFalse);
      expect(ZenMutation.activeMutationsForKey('user_update'), equals(0));
      expect(ZenMutation.isMutatingKey('cart_checkout'), isTrue);

      c2.complete('ok2');
      await f2;

      expect(ZenMutation.isMutatingKey('cart_checkout'), isFalse);
      expect(ZenMutation.activeMutationsForKey('cart_checkout'), equals(0));

      userMutation.dispose();
      cartMutation.dispose();
    });

    test('tracks multiple concurrent mutations sharing the same mutationKey',
        () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();

      final m1 = ZenMutation<String, void>(
        mutationKey: 'batch_item',
        mutationFn: (_) => c1.future,
      );
      final m2 = ZenMutation<String, void>(
        mutationKey: 'batch_item',
        mutationFn: (_) => c2.future,
      );

      final f1 = m1.mutate(null);
      final f2 = m2.mutate(null);
      await Future.delayed(Duration.zero);

      expect(ZenMutation.isMutatingKey('batch_item'), isTrue);
      expect(ZenMutation.activeMutationsForKey('batch_item'), equals(2));

      c1.complete('item1');
      await f1;

      // 1 still in-flight under the same key
      expect(ZenMutation.isMutatingKey('batch_item'), isTrue);
      expect(ZenMutation.activeMutationsForKey('batch_item'), equals(1));

      c2.complete('item2');
      await f2;

      expect(ZenMutation.isMutatingKey('batch_item'), isFalse);
      expect(ZenMutation.activeMutationsForKey('batch_item'), equals(0));

      m1.dispose();
      m2.dispose();
    });

    test('resetActiveCounters clears both global count and keyed map',
        () async {
      final c = Completer<String>();
      final mutation = ZenMutation<String, void>(
        mutationKey: 'to_reset',
        mutationFn: (_) => c.future,
      );

      final f = mutation.mutate(null);
      await Future.delayed(Duration.zero);

      expect(ZenMutation.anyMutating, isTrue);
      expect(ZenMutation.isMutatingKey('to_reset'), isTrue);

      ZenMutation.resetActiveCounters();

      expect(ZenMutation.anyMutating, isFalse);
      expect(ZenMutation.activeMutations.value, equals(0));
      expect(ZenMutation.isMutatingKey('to_reset'), isFalse);
      expect(ZenMutation.activeMutationsForKey('to_reset'), equals(0));

      c.complete('ok');
      await f;
      mutation.dispose();
    });
  });

  group('ZenQueryCache.isFetching & isFetchingCount (Filtered Queries)', () {
    test('filters by queryKey, tag, and custom predicate', () async {
      final c1 = Completer<String>();
      final c2 = Completer<String>();

      final q1 = ZenQuery<String>(
        queryKey: 'users:list',
        tags: ['users', 'dashboard'],
        fetcher: (_) => c1.future,
        config: const ZenQueryConfig(
          refetchOnMount: RefetchBehavior.never,
          staleTime: Duration.zero,
        ),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'posts:list',
        tags: ['posts', 'dashboard'],
        fetcher: (_) => c2.future,
        config: const ZenQueryConfig(
          refetchOnMount: RefetchBehavior.never,
          staleTime: Duration.zero,
        ),
      );

      final f1 = q1.fetch();
      await Future.delayed(Duration.zero);

      // Only q1 is fetching
      expect(Zen.queryCache.isFetching(queryKey: 'users:list'), isTrue);
      expect(Zen.queryCache.isFetchingCount(queryKey: 'users:list'), equals(1));
      expect(Zen.queryCache.isFetching(queryKey: 'posts:list'), isFalse);
      expect(Zen.queryCache.isFetchingCount(queryKey: 'posts:list'), equals(0));

      expect(Zen.queryCache.isFetching(tag: 'users'), isTrue);
      expect(Zen.queryCache.isFetching(tag: 'posts'), isFalse);
      expect(Zen.queryCache.isFetching(tag: 'dashboard'), isTrue);
      expect(Zen.queryCache.isFetchingCount(tag: 'dashboard'), equals(1));

      // Start q2 fetching
      final f2 = q2.fetch();
      await Future.delayed(Duration.zero);

      expect(Zen.queryCache.isFetching(tag: 'posts'), isTrue);
      expect(Zen.queryCache.isFetchingCount(tag: 'dashboard'), equals(2));

      // Custom predicate filter
      expect(
        Zen.queryCache
            .isFetching(predicate: (q) => q.queryKey.startsWith('users')),
        isTrue,
      );
      expect(
        Zen.queryCache
            .isFetching(predicate: (q) => q.queryKey.startsWith('comments')),
        isFalse,
      );
      expect(
        Zen.queryCache
            .isFetchingCount(predicate: (q) => q.tags.contains('dashboard')),
        equals(2),
      );

      c1.complete('u');
      c2.complete('p');
      await f1;
      await f2;

      expect(Zen.queryCache.isFetching(tag: 'dashboard'), isFalse);
      expect(Zen.queryCache.isFetchingCount(tag: 'dashboard'), equals(0));

      q1.dispose();
      q2.dispose();
    });

    test(
        'isFetching and isFetchingCount default to global fetch status when no filter is provided',
        () async {
      expect(Zen.queryCache.isFetching(), isFalse);
      expect(Zen.queryCache.isFetchingCount(), equals(0));

      final c = Completer<String>();
      final q = ZenQuery<String>(
        queryKey: 'no_filter_fetch_test',
        fetcher: (_) => c.future,
        config: const ZenQueryConfig(
          refetchOnMount: RefetchBehavior.never,
          staleTime: Duration.zero,
        ),
      );

      final f = q.fetch();
      await Future.delayed(Duration.zero);

      expect(Zen.queryCache.isFetching(), isTrue);
      expect(Zen.queryCache.isFetchingCount(), equals(1));

      c.complete('done');
      await f;

      expect(Zen.queryCache.isFetching(), isFalse);
      expect(Zen.queryCache.isFetchingCount(), equals(0));

      q.dispose();
    });
  });

  group('Reactive UI integration with ZenObserver', () {
    testWidgets('ZenObserver rebuilds when Zen.isFetching changes',
        (tester) async {
      final completer = Completer<String>();
      final query = ZenQuery<String>(
        queryKey: 'widget_fetch_test',
        fetcher: (_) => completer.future,
        config: const ZenQueryConfig(
          refetchOnMount: RefetchBehavior.never,
          staleTime: Duration.zero,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenObserver(
              () => Text(
                Zen.isFetching ? 'Status: Fetching' : 'Status: Idle',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Status: Idle'), findsOneWidget);

      final future = query.fetch();
      await tester.pump();

      expect(find.text('Status: Fetching'), findsOneWidget);

      completer.complete('done');
      await future;
      await tester.pump();

      expect(find.text('Status: Idle'), findsOneWidget);
      query.dispose();
    });

    testWidgets('ZenObserver rebuilds when Zen.isMutating changes',
        (tester) async {
      final completer = Completer<String>();
      final mutation = ZenMutation<String, void>(
        mutationFn: (_) => completer.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZenObserver(
              () => Text(
                Zen.isMutating ? 'Status: Mutating' : 'Status: Idle',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Status: Idle'), findsOneWidget);

      final future = mutation.mutate(null);
      await tester.pump();

      expect(find.text('Status: Mutating'), findsOneWidget);

      completer.complete('done');
      await future;
      await tester.pump();

      expect(find.text('Status: Idle'), findsOneWidget);
      mutation.dispose();
    });
  });

  group('Zen.reset() teardown cleanliness', () {
    test('resets all global counters to 0', () {
      ZenQuery.activeFetches.value = 5;
      ZenMutation.activeMutations.value = 3;

      Zen.reset();

      expect(Zen.isFetching, isFalse);
      expect(Zen.activeFetches.value, equals(0));
      expect(Zen.isMutating, isFalse);
      expect(Zen.activeMutations.value, equals(0));
    });
  });
}
