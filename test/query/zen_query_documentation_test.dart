import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('Documentation Examples', () {
    test('README battery optimization example works', () async {
      // Example from README
      final query = ZenQuery<String>(
        queryKey: 'user-data',
        fetcher: (token) async => 'user-data',
        config: const ZenQueryConfig(
          autoPauseOnBackground: true,
          refetchOnResume: true,
        ),
      );

      await query.fetch();
      expect(query.hasData, true);

      query.pause(); // Simulates app background
      expect(query.hasData, true);

      query.resume(); // Simulates app foreground
      expect(query.hasData, true);
    });

    test('opt-out example works for real-time features', () async {
      // Example for real-time chat
      final chatQuery = ZenQuery<String>(
        queryKey: 'chat',
        fetcher: (token) async => 'messages',
        config: const ZenQueryConfig(
          autoPauseOnBackground: false, // Keep running
          refetchInterval: Duration(seconds: 5),
          enableBackgroundRefetch: false, // Disabled for test
        ),
      );

      await chatQuery.fetch();
      expect(chatQuery.hasData, true);

      chatQuery.pause(); // Manual pause

      // Should still be able to fetch (not auto-paused)
      final result = await chatQuery.fetch(force: true);
      expect(result, 'messages');
    });

    test('exponential backoff example from docs', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'api-call',
        fetcher: (token) async {
          attempts++;
          if (attempts < 3) throw Exception('API Error');
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 200),
          maxRetryDelay: Duration(seconds: 30),
          retryBackoffMultiplier: 2.0,
          exponentialBackoff: true,
          retryWithJitter: true,
        ),
      );

      final result = await query.fetch();
      expect(result, 'success');
      expect(attempts, 3);
    });

    test('basic query example from getting started', () async {
      // Basic example
      final userQuery = ZenQuery<String>(
        queryKey: 'current-user',
        fetcher: (token) async {
          // Simulate API call
          await Future.delayed(const Duration(milliseconds: 100));
          return 'John Doe';
        },
      );

      // Fetch data
      final user = await userQuery.fetch();
      expect(user, 'John Doe');

      // Data is cached
      expect(userQuery.hasData, true);
      expect(userQuery.data.value, 'John Doe');
    });

    test('stale time configuration example', () async {
      final query = ZenQuery<String>(
        queryKey: 'posts',
        fetcher: (token) async => 'posts-data',
        config: const ZenQueryConfig(
          staleTime: Duration(minutes: 5), // Fresh for 5 minutes
        ),
      );

      await query.fetch();
      expect(query.isStale, false);

      // Data stays fresh
      await Future.delayed(const Duration(milliseconds: 100));
      expect(query.isStale, false);
    });

    test('manual refetch example', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'data',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      // Initial fetch
      await query.fetch();
      expect(query.data.value, 'data-1');

      // Manual refetch
      await query.refetch();
      expect(query.data.value, 'data-2');
      expect(fetchCount, 2);
    });

    test('enabled state example', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'conditional-data',
        fetcher: (token) async {
          fetchCount++;
          return 'data';
        },
        enabled: false, // Initially disabled
      );

      // Enable and fetch
      query.enabled.value = true;
      await query.fetch();
      expect(fetchCount, 1);
    });

    test('placeholder data example', () {
      final query = ZenQuery<String>(
        queryKey: 'user-profile',
        fetcher: (token) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'Real Profile Data';
        },
        config: const ZenQueryConfig(
          placeholderData: 'Loading...',
        ),
      );

      // Placeholder available immediately
      expect(query.data.value, 'Loading...');
      expect(query.hasData, true);
    });

    test('scoped query example', () async {
      final userScope = Zen.createScope(name: 'user-scope');

      final query = ZenQuery<String>(
        queryKey: 'user-settings',
        fetcher: (token) async => 'settings-data',
        scope: userScope,
      );

      await query.fetch();
      expect(query.hasData, true);

      // Dispose scope
      userScope.dispose();
    });

    test('error handling example', () async {
      final query = ZenQuery<String>(
        queryKey: 'failing-api',
        fetcher: (token) async => throw Exception('API Error'),
        config: const ZenQueryConfig(
          retryCount: 0, // No retries for this example
        ),
      );

      try {
        await query.fetch();
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      expect(query.hasError, true);
      expect(query.error.value, isA<Exception>());
    });
  });
}
