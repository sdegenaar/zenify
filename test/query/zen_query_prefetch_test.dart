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

  group('ZenQueryCache.prefetch', () {
    test('fetches and caches data if cache is empty', () async {
      int fetchCount = 0;

      await ZenQueryCache.instance.prefetch<String>(
        queryKey: 'prefetch-test',
        fetcher: () async {
          fetchCount++;
          return 'prefetched-data';
        },
      );

      expect(fetchCount, 1);

      // Verify it's in cache
      final cached =
          ZenQueryCache.instance.getCachedData<String>('prefetch-test');
      expect(cached, 'prefetched-data');
    });

    test('does NOT fetch if data is fresh', () async {
      // 1. Prime cache
      ZenQueryCache.instance.updateCache(
        'prefetch-test',
        'existing-data',
        DateTime.now(), // Fresh
      );

      int fetchCount = 0;

      await ZenQueryCache.instance.prefetch<String>(
        queryKey: 'prefetch-test',
        fetcher: () async {
          fetchCount++;
          return 'new-data';
        },
        staleTime: const Duration(minutes: 5), // Data is definitely fresh
      );

      expect(fetchCount, 0);
      expect(ZenQueryCache.instance.getCachedData('prefetch-test'),
          'existing-data');
    });

    test('fetches if data is stale', () async {
      // 1. Prime cache with old data
      ZenQueryCache.instance.updateCache(
        'prefetch-test',
        'old-data',
        DateTime.now().subtract(const Duration(minutes: 10)),
      );

      int fetchCount = 0;

      await ZenQueryCache.instance.prefetch<String>(
        queryKey: 'prefetch-test',
        fetcher: () async {
          fetchCount++;
          return 'new-data';
        },
        staleTime: const Duration(minutes: 5), // Data is 10m old, so it's stale
      );

      expect(fetchCount, 1);
      expect(ZenQueryCache.instance.getCachedData('prefetch-test'), 'new-data');
    });

    test('handles errors gracefully', () async {
      // Should not throw
      await ZenQueryCache.instance.prefetch<String>(
        queryKey: 'error-test',
        fetcher: () async => throw Exception('Network error'),
      );

      // Cache should be empty
      expect(ZenQueryCache.instance.getCachedData('error-test'), null);
    });

    test('deduplicates concurrent prefetches', () async {
      int fetchCount = 0;

      final future1 = ZenQueryCache.instance.prefetch<String>(
        queryKey: 'concurrent-test',
        fetcher: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      final future2 = ZenQueryCache.instance.prefetch<String>(
        queryKey: 'concurrent-test',
        fetcher: () async {
          fetchCount++;
          return 'data';
        },
      );

      await Future.wait([future1, future2]);

      expect(fetchCount, 1);
    });
  });
}
