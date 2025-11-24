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

  group('ZenQuery enabled', () {
    test('query does not fetch initially if disabled', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        enabled: false,
      );

      // Initial state should be idle
      expect(query.status.value, ZenQueryStatus.idle);
      expect(query.data.value, null);
      expect(fetchCount, 0);

      // Even calling fetch explicitly should not fetch (unless force)
      try {
        await query.fetch();
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('disabled'));
      }

      expect(fetchCount, 0);
    });

    test('query fetches when enabled becomes true', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        enabled: false,
      );

      expect(fetchCount, 0);

      // Enable query
      query.enabled.value = true;

      // Should trigger fetch automatically because it's stale/idle
      // Wait for microtasks
      await Future.delayed(Duration.zero);

      // Fetch might be async, wait for it
      // We can't await the internal fetch directly easily without hooks,
      // but we can wait for status change

      if (query.status.value == ZenQueryStatus.loading) {
        // wait for completion?
        // In test environment, async fetchers usually need pump or delay
      }

      // Since fetcher is async but returns immediate value in test?
      // Actually fetcher above is async.

      // Let's wait a bit
      await Future.delayed(const Duration(milliseconds: 10));

      expect(fetchCount, 1);
      expect(query.data.value, 'data');
    });

    test('query does NOT fetch when enabled if data is fresh', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
        enabled: true, // Start enabled
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Disable
      query.enabled.value = false;

      // Enable again
      query.enabled.value = true;

      await Future.delayed(Duration.zero);

      // Should NOT have fetched again because data is fresh
      expect(fetchCount, 1);
    });

    test('dependent query pattern works', () async {
      // 1. User Query
      final userQuery = ZenQuery<String>(
        queryKey: 'user',
        fetcher: (_) async => 'user_id_123',
      );

      // 2. Posts Query (dependent)
      int postsFetchCount = 0;
      final postsQuery = ZenQuery<String>(
        queryKey: ['posts', 'dependent'], // Static key for test
        fetcher: (_) async {
          postsFetchCount++;
          return 'posts for ${userQuery.data.value}';
        },
        enabled: false,
      );

      // Wiring
      ZenWorkers.ever(userQuery.data, (user) {
        if (user != null) {
          postsQuery.enabled.value = true;
        }
      });

      // Initial state
      expect(postsFetchCount, 0);
      expect(postsQuery.status.value, ZenQueryStatus.idle);

      // Fetch user
      await userQuery.fetch();

      // Wait for worker and dependent fetch
      await Future.delayed(const Duration(milliseconds: 10));

      expect(postsFetchCount, 1);
      expect(postsQuery.data.value, 'posts for user_id_123');
    });
  });
}
