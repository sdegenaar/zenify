import 'dart:async';
import 'package:flutter/widgets.dart';
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

  group('Smart Refetching', () {
    test('refetches on app resume (focus)', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'focus-test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        config: const ZenQueryConfig(
          refetchOnFocus: RefetchBehavior.ifStale,
          staleTime: Duration.zero, // Always stale
        ),
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Simulate app resume
      // Since we can't easily trigger actual OS lifecycle in unit test without deeper mocking,
      // we call the observer method directly on the cache instance.
      ZenQueryCache.instance.simulateLifecycleState(AppLifecycleState.resumed);

      // Wait for microtasks
      await Future.delayed(Duration.zero);

      // Should have triggered refetch
      // But refetch is async.
      await Future.delayed(const Duration(milliseconds: 10));

      expect(fetchCount, 2);
    });

    test('refetches on network reconnect', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'network-test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        config: const ZenQueryConfig(
          refetchOnReconnect: RefetchBehavior.ifStale,
          staleTime: Duration.zero,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Simulate network stream
      final controller = StreamController<bool>();
      Zen.setNetworkStream(controller.stream);

      // Go offline
      controller.add(false);
      await Future.delayed(Duration.zero);

      // Back online
      controller.add(true);

      // Wait for listener
      await Future.delayed(const Duration(milliseconds: 10));

      expect(fetchCount, 2);

      controller.close();
    });

    test('does not refetch if disabled', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'disabled-test',
        fetcher: (_) async {
          fetchCount++;
          return 'data';
        },
        config: const ZenQueryConfig(refetchOnFocus: RefetchBehavior.ifStale),
        enabled: false,
      );

      // Manually set data to avoid initial fetch check block (since it's disabled)
      query.setData('initial');
      query.invalidate(); // Make it stale

      // Simulate resume
      ZenQueryCache.instance.simulateLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(fetchCount, 0);
    });
  });
}
