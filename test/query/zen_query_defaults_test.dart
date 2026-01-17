import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery QueryClient Defaults', () {
    test('uses standard defaults when no QueryClient is registered', () {
      final query = ZenQuery<String>(
        queryKey: 'test-standard-defaults',
        fetcher: (token) async => 'data',
      );

      // Standard default for retryCount is 3
      expect(query.config.retryCount, 3);
      // Standard default for staleTime is 30 seconds
      expect(query.config.staleTime, const Duration(seconds: 30));
    });

    test('uses QueryClient defaults when registered', () {
      // Create and register QueryClient with custom defaults
      final queryClient = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(
            retryCount: 5,
            staleTime: Duration(seconds: 60),
            refetchOnMount: false,
          ),
        ),
      );
      Zen.put(queryClient);

      final query = ZenQuery<String>(
        queryKey: 'test-client-defaults',
        fetcher: (token) async => 'data',
      );

      expect(query.config.retryCount, 5);
      expect(query.config.staleTime, const Duration(seconds: 60));
      expect(query.config.refetchOnMount, false);
    });

    test(
        'individual query config overrides QueryClient defaults using copyWith',
        () {
      // Register QueryClient with defaults
      final queryClient = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(
            retryCount: 5,
            staleTime: Duration(seconds: 60),
          ),
        ),
      );
      Zen.put(queryClient);

      // Get client defaults and override specific fields using copyWith
      final clientDefaults = queryClient.getQueryDefaults<String>();
      final query = ZenQuery<String>(
        queryKey: 'test-override-client',
        fetcher: (token) async => 'data',
        config: clientDefaults.copyWith(
          retryCount: 1, // Override only retryCount
        ),
      );

      expect(query.config.retryCount, 1); // Should be overridden
      expect(query.config.staleTime,
          const Duration(seconds: 60)); // Should be inherited
    });

    test('copyWith pattern works correctly', () {
      final baseConfig = ZenQueryConfig(
        staleTime: Duration.zero,
        retryCount: 1,
      );

      final withRetries = baseConfig.copyWith(retryCount: 5);

      expect(withRetries.staleTime, Duration.zero);
      expect(withRetries.retryCount, 5);
    });

    test('different QueryClients can be used in different scopes', () {
      // Create two different clients
      final client1 = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(retryCount: 1),
        ),
      );

      final client2 = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(retryCount: 10),
        ),
      );

      // Use client1
      Zen.put(client1);
      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (token) async => 'data1',
      );
      expect(query1.config.retryCount, 1);

      // Replace with client2
      Zen.delete<ZenQueryClient>();
      Zen.put(client2);
      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (token) async => 'data2',
      );
      expect(query2.config.retryCount, 10);
    });

    test('ZenStreamQuery also uses QueryClient defaults', () {
      final queryClient = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(
            retryCount: 7,
            autoPauseOnBackground: true,
          ),
        ),
      );
      Zen.put(queryClient);

      final streamQuery = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => Stream.value(42),
      );

      expect(streamQuery.config.retryCount, 7);
      expect(streamQuery.config.autoPauseOnBackground, true);
    });

    test('direct config without QueryClient still works', () {
      // No QueryClient registered
      final query = ZenQuery<String>(
        queryKey: 'direct-config',
        fetcher: (token) async => 'data',
        config: ZenQueryConfig(
          retryCount: 99,
          staleTime: Duration(hours: 1),
        ),
      );

      expect(query.config.retryCount, 99);
      expect(query.config.staleTime, const Duration(hours: 1));
    });

    test('QueryClient is immutable after creation', () {
      final queryClient = ZenQueryClient(
        defaultOptions: ZenQueryClientOptions(
          queries: ZenQueryConfig(retryCount: 5),
        ),
      );

      // Get defaults
      final defaults1 = queryClient.getQueryDefaults<String>();
      final defaults2 = queryClient.getQueryDefaults<String>();

      // Should return consistent results
      expect(defaults1.retryCount, defaults2.retryCount);
      expect(defaults1.staleTime, defaults2.staleTime);
    });
  });
}
