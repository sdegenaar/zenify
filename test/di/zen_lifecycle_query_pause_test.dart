import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
    Zen.init();
    // Configure for testing to avoid pending timer issues
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() {
    Zen.reset();
  });

  group('Query Lifecycle Integration', () {
    testWidgets('queries pause when app goes to background', (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-lifecycle-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          autoPauseOnBackground: true,
        ),
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Try to fetch while paused - should return cached data
      final result = await query.fetch();
      expect(result, 'data-1'); // Same cached data
      expect(fetchCount, 1); // No new fetch occurred
    });

    testWidgets('queries resume when app returns to foreground',
        (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-lifecycle-resume',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Verify paused - fetch returns cached data
      final pausedResult = await query.fetch();
      expect(pausedResult, 'data-1');
      expect(fetchCount, 1);

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Verify resumed - can fetch new data
      final resumedResult = await query.fetch(force: true);
      expect(resumedResult, 'data-2');
      expect(fetchCount, 2, reason: 'Should be able to fetch after resume');
    });

    testWidgets('queries pause on inactive state (web tab switch)',
        (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-lifecycle-inactive',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Simulate inactive state (web tab switch)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Try to fetch - should return cached data (paused)
      final result = await query.fetch();
      expect(result, 'data-1');
      expect(fetchCount, 1, reason: 'Should pause on inactive state');
    });

    testWidgets('queries pause on hidden state (web/desktop)', (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-lifecycle-hidden',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Simulate hidden state
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      // Try to fetch - should return cached data (paused)
      final result = await query.fetch();
      expect(result, 'data-1');
      expect(fetchCount, 1, reason: 'Should pause on hidden state');
    });

    testWidgets('multiple queries pause/resume together', (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount1 = 0;
      int fetchCount2 = 0;
      int fetchCount3 = 0;

      final query1 = ZenQuery<String>(
        queryKey: 'test-multi-1',
        fetcher: (token) async {
          fetchCount1++;
          return 'data1-$fetchCount1';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      final query2 = ZenQuery<String>(
        queryKey: 'test-multi-2',
        fetcher: (token) async {
          fetchCount2++;
          return 'data2-$fetchCount2';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      final query3 = ZenQuery<String>(
        queryKey: 'test-multi-3',
        fetcher: (token) async {
          fetchCount3++;
          return 'data3-$fetchCount3';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      // Initial fetches
      await query1.fetch();
      await query2.fetch();
      await query3.fetch();
      expect(fetchCount1, 1);
      expect(fetchCount2, 1);
      expect(fetchCount3, 1);

      // Pause all
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Resume all
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Wait for refetches
      await tester.pump(const Duration(milliseconds: 100));

      // All should have refetched
      expect(fetchCount1, 2);
      expect(fetchCount2, 2);
      expect(fetchCount3, 2);
    });

    testWidgets('autoPauseOnBackground: false prevents auto-pause',
        (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-no-auto-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          autoPauseOnBackground: false, // Don't auto-pause
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Should still be able to fetch (not paused)
      await query.fetch(force: true);
      expect(fetchCount, 2,
          reason:
              'Should continue fetching when autoPauseOnBackground is false');
    });

    testWidgets('scoped queries pause/resume with lifecycle', (tester) async {
      await tester.pumpWidget(Container());

      final scope = Zen.createScope(name: 'test-scope');
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-scoped',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        scope: scope,
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      expect(fetchCount, 2, reason: 'Scoped query should refetch on resume');
    });

    testWidgets('global queries pause/resume with lifecycle', (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-global',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      expect(fetchCount, 2, reason: 'Global query should refetch on resume');
    });

    testWidgets('lifecycle pause/resume works with query cache',
        (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount1 = 0;
      int fetchCount2 = 0;

      final query1 = ZenQuery<String>(
        queryKey: 'cache-test-1',
        fetcher: (token) async {
          fetchCount1++;
          return 'data1-$fetchCount1';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      final query2 = ZenQuery<String>(
        queryKey: 'cache-test-2',
        fetcher: (token) async {
          fetchCount2++;
          return 'data2-$fetchCount2';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      await query1.fetch();
      await query2.fetch();

      // Verify queries are in cache
      final cachedQuery1 =
          ZenQueryCache.instance.getQuery<String>('cache-test-1');
      final cachedQuery2 =
          ZenQueryCache.instance.getQuery<String>('cache-test-2');
      expect(cachedQuery1, isNotNull);
      expect(cachedQuery2, isNotNull);

      // Lifecycle pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Lifecycle resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));

      // Both should have refetched
      expect(fetchCount1, 2);
      expect(fetchCount2, 2);
    });

    testWidgets('detached state does not pause queries', (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-detached',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Detached state should NOT pause queries
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();

      // Should still be able to fetch
      await query.fetch(force: true);
      expect(fetchCount, 2, reason: 'Detached state should not pause queries');
    });

    testWidgets('rapid lifecycle changes are handled correctly',
        (tester) async {
      await tester.pumpWidget(Container());

      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-rapid-changes',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
          autoPauseOnBackground: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Rapid state changes
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));

      // Should handle rapid changes gracefully
      expect(fetchCount, greaterThan(1));
    });
  });

  group('Lifecycle Integration Edge Cases', () {
    testWidgets('disposed query does not crash on lifecycle change',
        (tester) async {
      await tester.pumpWidget(Container());

      final query = ZenQuery<String>(
        queryKey: 'test-disposed',
        fetcher: (token) async => 'data',
      );

      await query.fetch();
      query.dispose();

      // Should not crash
      expect(() {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }, returnsNormally);
    });

    testWidgets('query created during pause state works correctly',
        (tester) async {
      await tester.pumpWidget(Container());

      // Pause app first
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Create query while paused
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'test-created-while-paused',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          enableBackgroundRefetch: false, // Disable to avoid timer issues
        ),
      );

      // Should still be able to fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Should work normally
      expect(query.data.value, 'data-1');

      // Clean up
      query.dispose();
    });
  });
}
