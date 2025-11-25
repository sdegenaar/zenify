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

    test('callbacks are executed in order (definition time)', () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          log.add('execute');
          return 'success';
        },
        onMutate: (val) {
          log.add('onMutate');
          return 'context';
        },
        onSuccess: (data, val, context) {
          log.add('onSuccess:$context');
        },
        onSettled: (data, error, val, context) {
          log.add('onSettled:$context');
        },
      );

      await mutation.mutate(1);

      expect(log,
          ['onMutate', 'execute', 'onSuccess:context', 'onSettled:context']);
    });

    test('call-time callbacks are executed after definition-time callbacks',
        () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async => 'success',
        onSuccess: (data, val, context) => log.add('def:onSuccess'),
        onSettled: (data, error, val, context) => log.add('def:onSettled'),
        onError: (error, val, context) => log.add('def:onError'),
      );

      await mutation.mutate(
        1,
        onSuccess: (data, val) => log.add('call:onSuccess'),
        onSettled: (data, error, val) => log.add('call:onSettled'),
      );

      expect(log, [
        'def:onSuccess',
        'call:onSuccess',
        'def:onSettled',
        'call:onSettled'
      ]);
    });

    test('callbacks executed on error', () async {
      final log = <String>[];
      final mutation = ZenMutation<String, int>(
        mutationFn: (val) async {
          log.add('execute');
          throw Exception('fail');
        },
        onMutate: (val) {
          log.add('onMutate');
          return 'errContext';
        },
        onError: (error, val, context) => log.add('onError:$context'),
        onSettled: (data, error, val, context) => log.add('onSettled:$context'),
      );

      await mutation.mutate(1);

      expect(log, [
        'onMutate',
        'execute',
        'onError:errContext',
        'onSettled:errContext'
      ]);
    });

    test('optimistic updates and rollback simulation', () async {
      // Setup a query with initial data
      final query = ZenQuery<List<String>>(
        queryKey: 'todos',
        fetcher: (_) async => ['item1'],
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
          return current; // Return old list as context for rollback
        },
        onError: (error, newItem, context) {
          // Rollback: restore the old list from context
          if (context is List<String>) {
            query.setData(context);
          }
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
        fetcher: (_) async {
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
        onSettled: (_, __, ___, ____) {
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
          return null;
        },
      );

      await mutation.mutate(1);

      // Ensure onMutate finished before execution
      expect(log, ['asyncOnMutate', 'execute']);
    });
  });
}
