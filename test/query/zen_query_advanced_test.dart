import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered lines in zen_query.dart:
/// - L309: _fetchWithRetry disposed before fetch starts
/// - L340: disposed during fetch (after await)
/// - L370: disposed during catch block
/// - L526-528: resume() triggers refetch when stale
/// - L607-609: background refetch error handler
/// - L631-633: _initData cache hit from memory cache
/// - L640-642: _initData placeholder data branch
/// - L716,718: toString() output
/// - L733,736,737: _SelectedZenQuery error propagation (_computeState)
/// - L804-805: _SelectedZenQuery selector throws
/// - L819,821,822: _SelectedZenQuery.refetch()
/// - L825,827: _SelectedZenQuery.invalidate()
void main() {
  setUp(() {
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    Zen.init();
  });
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // Disposed-query safety (L309)
  // ══════════════════════════════════════════════════════════
  group('ZenQuery fetch on disposed query', () {
    test('fetch(force:true) on disposed query throws StateError', () async {
      final q = ZenQuery<int>(
        queryKey: 'disposed_fetch',
        fetcher: (_) async => 42,
        enabled: false, // disabled so it doesn't auto-fetch
      );
      q.dispose();
      // force:true bypasses the enabled check and hits _fetchWithRetry disposed guard
      await expectLater(
        q.fetch(force: true),
        throwsA(isA<StateError>()),
      );
    });

    test('refetch on disposed query propagates StateError', () async {
      final q = ZenQuery<int>(
        queryKey: 'disposed_refetch',
        fetcher: (_) async => 1,
        enabled: false,
      );
      q.dispose();
      // refetch() calls fetch(force:true) internally
      await expectLater(
        q.refetch(),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // toString (L716,718)
  // ══════════════════════════════════════════════════════════
  group('ZenQuery.toString', () {
    test('toString contains queryKey and status', () {
      final q = ZenQuery<int>(
        queryKey: 'tostring_test',
        fetcher: (_) async => 1,
        enabled: false,
      );
      final str = q.toString();
      expect(str, contains('tostring_test'));
      expect(str, contains('ZenQuery'));
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Cache hit in _initData (L631-633)
  // ══════════════════════════════════════════════════════════
  group('ZenQuery._initData cache hit', () {
    test('query loads from memory cache instead of fetching', () async {
      // Prepopulate cache
      ZenQueryCache.instance.updateCache<int>(
        'cached_query',
        99,
        DateTime.now(),
      );

      int fetchCount = 0;
      final q = ZenQuery<int>(
        queryKey: 'cached_query',
        fetcher: (_) async {
          fetchCount++;
          return 1;
        },
        config: const ZenQueryConfig(
          staleTime: Duration(hours: 1),
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(q.data.value, 99); // from cache
      expect(q.status.value, ZenQueryStatus.success);
      expect(fetchCount, 0); // no fetch needed
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Placeholder data (L640-642)
  // ══════════════════════════════════════════════════════════
  group('ZenQuery placeholder data', () {
    test('placeholder data shown while fetching real data', () async {
      final completer = Completer<int>();
      final q = ZenQuery<int>(
        queryKey: 'placeholder_query',
        fetcher: (_) => completer.future,
        config: ZenQueryConfig<int>(
          placeholderData: -1,
          refetchOnMount: RefetchBehavior.always,
        ),
      );

      await Future.delayed(Duration.zero);
      // Should have placeholder data while real fetch is pending
      expect(q.data.value, -1);
      expect(q.status.value, ZenQueryStatus.success);
      expect(q.isPlaceholderData.value, true);

      completer.complete(42);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(q.data.value, 42);
      expect(q.isPlaceholderData.value, false);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // resume() refetch-on-resume (L526-528)
  // ══════════════════════════════════════════════════════════
  group('ZenQuery.resume refetch when stale', () {
    test('resume refetches when data is stale and enabled', () async {
      int fetchCount = 0;
      final q = ZenQuery<int>(
        queryKey: 'resume_stale',
        fetcher: (_) async {
          fetchCount++;
          return fetchCount;
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero, // always stale
          refetchOnResume: true,
          refetchOnMount: RefetchBehavior.always,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final initialFetchCount = fetchCount;

      q.pause();
      q.resume(); // should trigger refetch because stale

      await Future.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, greaterThan(initialFetchCount));
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // select() — _SelectedZenQuery
  // ══════════════════════════════════════════════════════════
  group('ZenQuery.select — _SelectedZenQuery', () {
    test('select transforms source data', () async {
      final q = ZenQuery<int>(
        queryKey: 'select_source',
        fetcher: (_) async => 10,
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select((v) => v * 2);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(selected.data.value, 20);
      expect(selected.status.value, ZenQueryStatus.success);

      selected.dispose();
      q.dispose();
    });

    test('select propagates loading status', () {
      final completer = Completer<String>();
      final q = ZenQuery<String>(
        queryKey: 'select_loading',
        fetcher: (_) => completer.future,
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select((v) => v.length);

      // Source is loading — selected should also show loading
      expect(selected.status.value, ZenQueryStatus.loading);

      completer.complete('hello');
      selected.dispose();
      q.dispose();
    });

    test('select propagates error from source (L733,736)', () async {
      final q = ZenQuery<int>(
        queryKey: 'select_error_source',
        fetcher: (_) async => throw Exception('source boom'),
        config: const ZenQueryConfig(
          retryCount: 0,
          refetchOnMount: RefetchBehavior.always,
        ),
      );
      final selected = q.select((v) => v.toString());

      await Future.delayed(const Duration(milliseconds: 50));
      expect(selected.status.value, ZenQueryStatus.error);
      expect(selected.error.value, isNotNull);

      selected.dispose();
      q.dispose();
    });

    test('select handles selector throwing (L804-805)', () async {
      final q = ZenQuery<int>(
        queryKey: 'select_selector_error',
        fetcher: (_) async => 5,
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select<String>((v) {
        if (v == 5) throw Exception('selector error');
        return v.toString();
      });

      await Future.delayed(const Duration(milliseconds: 50));
      // Selector threw — should be in error state
      expect(selected.status.value, ZenQueryStatus.error);

      selected.dispose();
      q.dispose();
    });

    test('select.refetch() delegates to source (L819-822)', () async {
      int fetchCount = 0;
      final q = ZenQuery<int>(
        queryKey: 'select_refetch',
        fetcher: (_) async {
          fetchCount++;
          return fetchCount * 10;
        },
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select((v) => v + 1);

      await Future.delayed(const Duration(milliseconds: 50));
      final firstCount = fetchCount;

      await selected.refetch();
      expect(fetchCount, greaterThan(firstCount));

      selected.dispose();
      q.dispose();
    });

    test('select.invalidate() delegates to source (L825-827)', () async {
      int fetchCount = 0;
      final q = ZenQuery<int>(
        queryKey: 'select_invalidate',
        fetcher: (_) async {
          fetchCount++;
          return 1;
        },
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select((v) => v.toString());

      await Future.delayed(const Duration(milliseconds: 50));
      final countBefore = fetchCount;

      selected.invalidate(); // should delegate to source.invalidate()
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetchCount, greaterThan(countBefore));
      selected.dispose();
      q.dispose();
    });

    test('select.isLoading delegates to source', () {
      final completer = Completer<int>();
      final q = ZenQuery<int>(
        queryKey: 'select_loading_rx',
        fetcher: (_) => completer.future,
        config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.always),
      );
      final selected = q.select((v) => v * 2);

      // When source is loading, selected.isLoading should reflect source.isLoading
      expect(selected.isLoading.value, q.isLoading.value);

      completer.complete(1);
      selected.dispose();
      q.dispose();
    });
  });
}
