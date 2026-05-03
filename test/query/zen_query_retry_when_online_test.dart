import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  StreamController<bool>? networkController;

  setUp(() {
    Zen.reset();
    Zen.testMode().clearQueryCache();
    networkController = StreamController<bool>.broadcast();
    Zen.setNetworkStream(networkController!.stream);
  });

  tearDown(() {
    networkController?.close();
    Zen.reset();
  });

  // ---------------------------------------------------------------------------
  // Helper: bring network online/offline with a short settle delay.
  // ---------------------------------------------------------------------------
  Future<void> goOnline() async {
    networkController!.add(true);
    await Future.delayed(const Duration(milliseconds: 30));
  }

  Future<void> goOffline() async {
    networkController!.add(false);
    await Future.delayed(const Duration(milliseconds: 30));
  }

  // ---------------------------------------------------------------------------
  group('retryWhenOnline=false (default) — normal error path', () {
    test('exhausted retries → error state, not paused', () async {
      await goOnline();

      int attempts = 0;
      final query = ZenQuery<String>(
        queryKey: 'rwol-false',
        fetcher: (_) async {
          attempts++;
          throw Exception('always fails');
        },
        config: const ZenQueryConfig(
          retryCount: 1,
          retryDelay: Duration(milliseconds: 10),
          retryWithJitter: false,
          retryWhenOnline: false, // default
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await expectLater(query.fetch(), throwsA(isA<Exception>()));

      expect(query.status.value, ZenQueryStatus.error);
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle);
      expect(attempts, 2); // initial + 1 retry
    });
  });

  // ---------------------------------------------------------------------------
  group('retryWhenOnline=true', () {
    test('query enters paused state when retries exhausted while offline',
        () async {
      await goOffline();

      int attempts = 0;
      final query = ZenQuery<String>(
        queryKey: 'rwol-paused',
        fetcher: (_) async {
          attempts++;
          throw Exception('network error');
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always, // bypass offline gate so fetch runs
          retryCount: 1,
          retryDelay: Duration(milliseconds: 10),
          retryWithJitter: false,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await expectLater(query.fetch(), throwsA(isA<ZenOfflineException>()));

      // Should be PAUSED, not ERROR
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(query.status.value, isNot(ZenQueryStatus.error));
      expect(attempts, 2); // initial + 1 retry
    });

    test('query automatically retries full cycle when connectivity returns',
        () async {
      await goOffline();

      int attempts = 0;
      // Phase 1: always fail (while offline)
      // Phase 2: succeed on reconnect
      bool succeedNow = false;

      final query = ZenQuery<String>(
        queryKey: 'rwol-reconnect',
        fetcher: (_) async {
          attempts++;
          if (!succeedNow) throw Exception('offline');
          return 'online data';
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0, // exhaust immediately
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      // Fetch while offline → should pause
      await expectLater(query.fetch(), throwsA(isA<ZenOfflineException>()));
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      final attemptsAfterOffline = attempts;

      // Reconnect → drain queue → fresh retry cycle
      succeedNow = true;
      await goOnline();

      // Allow the async retry to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(query.status.value, ZenQueryStatus.success);
      expect(query.data.value, 'online data');
      expect(attempts, greaterThan(attemptsAfterOffline));
    });

    test('returns stale data while paused (does not enter error state)',
        () async {
      await goOnline();

      final query = ZenQuery<String>(
        queryKey: 'rwol-stale',
        fetcher: (_) async => 'initial',
        config: const ZenQueryConfig(
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.ifStale,
        ),
      );

      // Seed with data
      await query.fetch();
      expect(query.data.value, 'initial');

      // Now go offline and fail
      await goOffline();

      int failCount = 0; // ignore: unused_local_variable — side-effect counter
      final failingQuery = ZenQuery<String>(
        queryKey: 'rwol-stale-2',
        initialData: 'cached',
        fetcher: (_) async {
          failCount++;
          throw Exception('fail');
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await failingQuery.fetch().catchError((_) => 'cached');

      // Stale data was returned, not an error
      expect(failingQuery.data.value, 'cached');
      // Status is paused, NOT error
      expect(failingQuery.fetchStatus.value, ZenQueryFetchStatus.paused);
    });

    test('multiple queries all queue and retry on reconnect', () async {
      await goOffline();

      bool succeedNow = false;

      ZenQuery<String> makeQuery(String key) => ZenQuery<String>(
            queryKey: key,
            fetcher: (_) async {
              if (!succeedNow) throw Exception('offline');
              return 'data-$key';
            },
            config: const ZenQueryConfig(
              networkMode: NetworkMode.always,
              retryCount: 0,
              retryWhenOnline: true,
              refetchOnMount: RefetchBehavior.never,
            ),
          );

      final q1 = makeQuery('rwol-multi-1');
      final q2 = makeQuery('rwol-multi-2');
      final q3 = makeQuery('rwol-multi-3');

      // All fail offline
      await Future.wait([
        q1.fetch().catchError((_) => ''),
        q2.fetch().catchError((_) => ''),
        q3.fetch().catchError((_) => ''),
      ]);

      expect(q1.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(q2.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(q3.fetchStatus.value, ZenQueryFetchStatus.paused);

      // Reconnect
      succeedNow = true;
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(q1.status.value, ZenQueryStatus.success);
      expect(q2.status.value, ZenQueryStatus.success);
      expect(q3.status.value, ZenQueryStatus.success);
    });

    test('disabled query is skipped when draining retry queue', () async {
      await goOffline();

      bool succeedNow = false;
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'rwol-disabled',
        fetcher: (_) async {
          attempts++;
          if (!succeedNow) throw Exception('fail');
          return 'data';
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      final attemptsAtPause = attempts;

      // Disable the query before reconnect
      query.enabled.value = false;
      succeedNow = true;
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      // Should NOT have retried (query was disabled)
      expect(attempts, attemptsAtPause);
      // Status stays paused (not retried, not succeeded)
      expect(query.status.value, isNot(ZenQueryStatus.success));
    });

    test('disposed query is cleaned up from retry queue on dispose', () async {
      await goOffline();

      final query = ZenQuery<String>(
        queryKey: 'rwol-dispose',
        fetcher: (_) async => throw Exception('fail'),
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);

      // Dispose before reconnect
      query.dispose();
      expect(query.isDisposed, true);

      // Reconnect — should not throw or crash on the disposed query
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));
      // If we got here without error, the queue correctly skipped the disposed query.
    });

    test('queue is drained only once per reconnect cycle', () async {
      await goOffline();

      int retryCount = 0;
      bool succeedNow = false;

      final query = ZenQuery<String>(
        queryKey: 'rwol-once',
        fetcher: (_) async {
          retryCount++;
          if (!succeedNow) throw Exception('fail');
          return 'ok';
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      final attemptsBeforeReconnect = retryCount;

      succeedNow = true;
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      // Query should have been retried exactly once on reconnect
      expect(retryCount, attemptsBeforeReconnect + 1);
      expect(query.status.value, ZenQueryStatus.success);

      // Go offline again and back online — queue is empty now, no extra retries
      await goOffline();
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      // No additional retries should have happened
      expect(retryCount, attemptsBeforeReconnect + 1);
    });

    test('retryWhenOnline with exponential backoff restarts full cycle',
        () async {
      await goOffline();

      int attempts = 0;
      bool succeed = false;

      final query = ZenQuery<String>(
        queryKey: 'rwol-backoff',
        fetcher: (_) async {
          attempts++;
          if (!succeed) throw Exception('fail');
          return 'backoff-data';
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 2,
          retryDelay: Duration(milliseconds: 10),
          retryWithJitter: false,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(attempts, 3); // initial + 2 retries
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);

      // Reconnect with success
      succeed = true;
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(query.status.value, ZenQueryStatus.success);
      expect(query.data.value, 'backoff-data');
      expect(attempts, 4); // 1 successful attempt after reconnect
    });
  });

  // ---------------------------------------------------------------------------
  // CRITICAL: retryWhenOnline=true, device IS online, server fails → must ERROR
  // ---------------------------------------------------------------------------
  group('retryWhenOnline=true + device online → error state (not paused)', () {
    test('server errors with device online → ZenQueryStatus.error, not paused',
        () async {
      await goOnline(); // Device is ONLINE

      int attempts = 0;
      final query = ZenQuery<String>(
        queryKey: 'rwol-online-error',
        fetcher: (_) async {
          attempts++;
          throw Exception('500 Server Error');
        },
        config: const ZenQueryConfig(
          retryCount: 1,
          retryDelay: Duration(milliseconds: 10),
          retryWithJitter: false,
          retryWhenOnline: true, // enabled, but device IS online
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await expectLater(query.fetch(), throwsA(isA<Exception>()));

      // Must be ERROR — device is online, so we don't enter paused state
      expect(query.status.value, ZenQueryStatus.error,
          reason: 'Should be error, not paused — device is online');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.idle,
          reason: 'fetchStatus should be idle after error (not paused)');
      expect(attempts, 2); // initial + 1 retry
    });

    test('retryWhenOnline=true does NOT defer to queue when device is online',
        () async {
      await goOnline();

      final query = ZenQuery<String>(
        queryKey: 'rwol-no-queue-online',
        fetcher: (_) async => throw Exception('server down'),
        config: const ZenQueryConfig(
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await expectLater(query.fetch(), throwsA(isA<Exception>()));

      // Status must be error — the retry queue should be empty
      expect(query.status.value, ZenQueryStatus.error);
      // The query's refetchOnReconnect is 'ifStale' by default — it may refetch,
      // but that's expected behaviour, not the retryWhenOnline queue.
    });
  });

  // ---------------------------------------------------------------------------
  // Config: retryWhenOnline preserved through copyWith and merge
  // ---------------------------------------------------------------------------
  group('ZenQueryConfig.retryWhenOnline — config preservation', () {
    test('copyWith preserves retryWhenOnline when not overridden', () {
      const base = ZenQueryConfig(retryWhenOnline: true, retryCount: 3);
      final copied = base.copyWith(retryDelay: Duration(milliseconds: 500));

      expect(copied.retryWhenOnline, true);
      expect(copied.retryCount, 3);
    });

    test('copyWith can override retryWhenOnline', () {
      const base = ZenQueryConfig(retryWhenOnline: true);
      final copied = base.copyWith(retryWhenOnline: false);

      expect(copied.retryWhenOnline, false);
    });

    test('merge propagates retryWhenOnline from other config', () {
      const base = ZenQueryConfig(retryWhenOnline: false);
      const override = ZenQueryConfig(retryWhenOnline: true);
      final merged = base.merge(override);

      expect(merged.retryWhenOnline, true);
    });

    test('cast preserves retryWhenOnline', () {
      const config =
          ZenQueryConfig<String>(retryWhenOnline: true, retryCount: 5);
      final casted = config.cast<int>();

      expect(casted.retryWhenOnline, true);
      expect(casted.retryCount, 5);
    });

    test('defaults to false', () {
      const config = ZenQueryConfig<String>();
      expect(config.retryWhenOnline, false);
    });
  });

  // ---------------------------------------------------------------------------
  // ZenQueryCache.clear() must drain the retry queue (memory-leak regression)
  // ---------------------------------------------------------------------------
  group('ZenQueryCache.clear() cleans up retry queue', () {
    test('clear() removes queries from retry queue — no crash on reconnect',
        () async {
      await goOffline();

      int attempts = 0;
      final query = ZenQuery<String>(
        queryKey: 'rwol-clear',
        fetcher: (_) async {
          attempts++;
          throw Exception('fail');
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      final attemptsBeforeClear = attempts;

      // Simulate logout / full reset
      ZenQueryCache.instance.clear();

      // Reconnect — the queue should be empty, no retry fired
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      // No additional attempts should have happened
      expect(attempts, attemptsBeforeClear,
          reason: 'clear() must have emptied the retry queue');
    });
  });

  // ---------------------------------------------------------------------------
  // resume() must remove from retry queue to prevent double-fetch
  // ---------------------------------------------------------------------------
  group('resume() removes from retry queue', () {
    test('manual resume() prevents duplicate fetch when device reconnects',
        () async {
      await goOffline();

      int attempts = 0;
      bool succeed = false;

      final query = ZenQuery<String>(
        queryKey: 'rwol-resume-dedup',
        fetcher: (_) async {
          attempts++;
          if (!succeed) throw Exception('fail');
          return 'resumed-data';
        },
        config: const ZenQueryConfig(
          networkMode: NetworkMode.always,
          retryCount: 0,
          retryWhenOnline: true,
          refetchOnResume: false, // don't auto-fetch on resume
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await query.fetch().catchError((_) => '');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(attempts, 1);

      // User manually resumes → should remove from queue
      succeed = true;
      query.resume();
      await query.fetch();
      expect(attempts, 2);
      expect(query.status.value, ZenQueryStatus.success);

      // Connectivity also returns — should NOT trigger a third fetch
      await goOnline();
      await Future.delayed(const Duration(milliseconds: 50));

      // Still only 2 attempts total (resume() removed it from the queue)
      expect(attempts, 2,
          reason:
              'resume() should have unregistered from retry queue — no extra fetch on reconnect');
    });
  });
}
