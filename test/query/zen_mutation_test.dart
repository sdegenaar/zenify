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

  group('ZenMutation', () {
    test('initial state is idle', () {
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async => 'result: $val',
      );

      expect(mutation.status.value, ZenMutationStatus.idle);
      expect(mutation.data.value, null);
      expect(mutation.error.value, null);
      expect(mutation.isLoading.value, false);
      expect(mutation.isSuccess, false);
      expect(mutation.isError, false);
    });

    test('executes mutation successfully', () async {
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result: $val';
        },
      );

      final future = mutation.mutate(42);

      // Should be loading immediately
      expect(mutation.status.value, ZenMutationStatus.loading);
      expect(mutation.isLoading.value, true);

      final result = await future;

      expect(result, 'result: 42');
      expect(mutation.status.value, ZenMutationStatus.success);
      expect(mutation.data.value, 'result: 42');
      expect(mutation.isLoading.value, false);
      expect(mutation.isSuccess, true);
    });

    test('handles errors correctly', () async {
      final exception = Exception('Failure');
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async => throw exception,
      );

      final result = await mutation.mutate(42);

      expect(result, null);
      expect(mutation.status.value, ZenMutationStatus.error);
      expect(mutation.error.value, exception);
      expect(mutation.isLoading.value, false);
      expect(mutation.isError, true);
    });

    test('callbacks are executed in order', () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          log.add('execute');
          return 'success';
        },
        onMutate: (val) => log.add('onMutate'),
        onSuccess: (data, val) => log.add('onSuccess'),
        onSettled: (data, error, val) => log.add('onSettled'),
      );

      await mutation.mutate(1);

      expect(log, ['onMutate', 'execute', 'onSuccess', 'onSettled']);
    });

    test('callbacks executed on error', () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          log.add('execute');
          throw Exception('fail');
        },
        onMutate: (val) => log.add('onMutate'),
        onError: (error, val) => log.add('onError'),
        onSettled: (data, error, val) => log.add('onSettled'),
      );

      await mutation.mutate(1);

      expect(log, ['onMutate', 'execute', 'onError', 'onSettled']);
    });

    test('optimistic updates and rollback simulation', () async {
      // Setup a query with initial data
      final query = ZenQuery<List<String>>(
        queryKey: 'todos',
        fetcher: () async => ['item1'],
        initialData: ['item1'],
      );

      // Mutation that adds an item
      final mutation = ZenMutation<String, String>(
        mutationFn: (item) async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Network Error'); // Simulate failure
        },
        onMutate: (newItem) {
          // Optimistically add item
          final current = query.data.value ?? [];
          query.setData([...current, newItem]);
        },
        onError: (error, newItem) {
          // Rollback: remove the optimistically added item
          final current = query.data.value ?? [];
          query.setData(current.where((item) => item != newItem).toList());
        },
      );

      // Initial state
      expect(query.data.value, ['item1']);

      // Trigger mutation
      final future = mutation.mutate('item2');

      // Verify optimistic update happened
      expect(query.data.value, ['item1', 'item2']);

      // Wait for failure
      await future;

      // Verify rollback happened
      expect(query.data.value, ['item1']);
    });

    test('cache invalidation on success', () async {
      int fetchCount = 0;
      final query = ZenQuery<String>(
        queryKey: 'user-data',
        fetcher: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(staleTime: Duration(minutes: 1)),
      );

      // First fetch
      await query.fetch();
      expect(query.data.value, 'data-1');
      expect(query.isStale, false);

      final mutation = ZenMutation<void, void>(
        mutationFn: (_) async {},
        onSettled: (_, __, ___) {
          ZenQueryCache.instance.invalidateQuery('user-data');
        },
      );

      // Run mutation
      await mutation.mutate(null);

      // Query should now be stale
      expect(query.isStale, true);

      // Refetch should hit network again
      await query.fetch();
      expect(query.data.value, 'data-2');
    });

    test('reset clears state', () async {
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async => 'result',
      );

      await mutation.mutate(1);
      expect(mutation.isSuccess, true);

      mutation.reset();

      expect(mutation.status.value, ZenMutationStatus.idle);
      expect(mutation.data.value, null);
      expect(mutation.error.value, null);
    });

    test('prevents mutation if disposed', () async {
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async => 'result',
      );

      mutation.dispose();

      expect(
        () => mutation.mutate(1),
        throwsA(isA<StateError>()),
      );
    });

    test('handles async onMutate', () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          log.add('execute');
          return 'success';
        },
        onMutate: (val) async {
          await Future.delayed(const Duration(milliseconds: 10));
          log.add('asyncOnMutate');
        },
      );

      await mutation.mutate(1);

      // Ensure onMutate finished before execution
      expect(log, ['asyncOnMutate', 'execute']);
    });
  });
}
