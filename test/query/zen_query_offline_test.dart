import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  StreamController<bool>? networkController;

  setUp(() {
    Zen.reset();
    Zen.testMode().clearQueryCache();
    // Setup network stream
    networkController = StreamController<bool>.broadcast();
    Zen.setNetworkStream(networkController!.stream);
    // Start as online by default
    networkController!.add(true);
  });

  tearDown(() {
    networkController?.close();
    Zen.reset();
  });

  group('ZenQuery Offline Logic', () {
    test('pauses fetch when offline (NetworkMode.online)', () async {
      // 1. Go offline
      networkController!.add(false);
      await Future.delayed(const Duration(milliseconds: 50)); // Process stream

      final query = ZenQuery<String>(
        queryKey: 'offline-test',
        fetcher: (_) async => 'success',
        config: const ZenQueryConfig(
          refetchOnMount: RefetchBehavior.never, // Prevent auto-fetch
        ),
      );

      // 2. Attempt fetch
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle);

      // Should throw ZenOfflineException
      expect(
        () => query.fetch(),
        throwsA(isA<ZenOfflineException>()),
      );

      // 3. Status should be paused
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(query.status.value, ZenQueryStatus.idle); // No data yet
    });

    test('fetches anyway when offline if NetworkMode.always', () async {
      networkController!.add(false);
      await Future.delayed(const Duration(milliseconds: 50));

      final query = ZenQuery<String>(
        queryKey: 'always-test',
        fetcher: (_) async => 'success',
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      // Should succeed
      await query.fetch();
      expect(query.data.value, 'success');
    });

    test('returns cache if offline and NetworkMode.offlineFirst', () async {
      networkController!.add(true); // Online first
      await Future.delayed(const Duration(milliseconds: 50));

      final query = ZenQuery<String>(
        queryKey: 'offline-first-test',
        fetcher: (_) async => 'remote data',
        config: const ZenQueryConfig(
          networkMode: NetworkMode.offlineFirst,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      // Seed cache
      query.setData('cached data');

      // Go offline
      networkController!.add(false);
      await Future.delayed(const Duration(milliseconds: 50));

      // Check precondition
      expect(ZenQueryCache.instance.isOnline, false);

      // Fetch
      final result = await query.fetch();

      // Should return cached data and NOT throw
      expect(result, 'cached data');
      // Should NOT be paused because we satisfied the request
      expect(query.fetchStatus.value, isNot(ZenQueryFetchStatus.paused));
    });

    test('pauses if offline, offlineFirst, and NO cache', () async {
      networkController!.add(false);
      await Future.delayed(const Duration(milliseconds: 50));

      final query = ZenQuery<String>(
        queryKey: 'offline-first-empty',
        fetcher: (_) async => 'remote',
        config: const ZenQueryConfig(
          networkMode: NetworkMode.offlineFirst,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      expect(
        () => query.fetch(),
        throwsA(isA<ZenOfflineException>()),
      );
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
    });

    test('resumes automatically when back user calls resume() (simulation)',
        () async {
      // Note: ZenQueryCache handles global reconnect logic,
      // but here we test the query's ability to transition states.

      final query = ZenQuery<String>(
        queryKey: 'resume-test',
        fetcher: (_) async => 'data',
      );

      // Force pause
      query.pause();
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);

      // Resume
      query.resume();
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle);
    });
  });
}
