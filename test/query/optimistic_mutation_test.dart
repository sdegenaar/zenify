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

  group('ZenMutation.listPut', () {
    test('adds item to list optimistically', () async {
      // Setup initial query
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['item1'],
      );

      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return item;
        },
      );

      // Trigger mutation
      final future = mutation.mutate('item2');

      // Verify optimistic update happened immediately
      final cached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(cached, ['item2', 'item1']); // Added to start

      await future;

      // Still in cache after success
      final finalCached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(finalCached, ['item2', 'item1']);
    });

    test('adds item to end when addToStart is false', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['item1'],
      );

      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async => item,
        addToStart: false,
      );

      await mutation.mutate('item2');

      final cached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(cached, ['item1', 'item2']); // Added to end
    });

    test('rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['item1'],
      );

      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async => throw Exception('Network error'),
      );

      await mutation.mutate('item2');

      // Should have rolled back to original
      final cached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(cached, ['item1']);
    });

    test('calls onSuccess callback', () async {
      var successCalled = false;
      String? successData;

      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async => item,
        onSuccess: (data, item, context) {
          successCalled = true;
          successData = data;
        },
      );

      await mutation.mutate('item2');

      expect(successCalled, true);
      expect(successData, 'item2');
    });

    test('calls onError callback', () async {
      var errorCalled = false;
      Object? capturedError;

      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async => throw Exception('Test error'),
        onError: (error, item) {
          errorCalled = true;
          capturedError = error;
        },
      );

      await mutation.mutate('item2');

      expect(errorCalled, true);
      expect(capturedError, isA<Exception>());
    });
  });

  group('ZenMutation.listRemove', () {
    test('removes item from list optimistically', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['item1', 'item2', 'item3'],
      );

      final mutation = ZenMutation.listRemove<String>(
        queryKey: 'items',
        mutationKey: 'remove_item',
        mutationFn: (item) async {},
        where: (item, toRemove) => item == toRemove,
      );

      await mutation.mutate('item2');

      final cached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(cached, ['item1', 'item3']);
    });

    test('rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['item1', 'item2'],
      );

      final mutation = ZenMutation.listRemove<String>(
        queryKey: 'items',
        mutationKey: 'remove_item',
        mutationFn: (item) async => throw Exception('Failed'),
        where: (item, toRemove) => item == toRemove,
      );

      await mutation.mutate('item2');

      // Should have rolled back
      final cached =
          ZenQueryCache.instance.getCachedData<List<String>>('items');
      expect(cached, ['item1', 'item2']);
    });
  });

  group('ZenMutation.listSet', () {
    test('updates item in list optimistically', () async {
      ZenQueryCache.instance.setQueryData<List<Map<String, dynamic>>>(
        'items',
        (_) => [
          {'id': '1', 'name': 'Item 1'},
          {'id': '2', 'name': 'Item 2'},
        ],
      );

      final mutation = ZenMutation.listSet<Map<String, dynamic>>(
        queryKey: 'items',
        mutationKey: 'update_item',
        mutationFn: (item) async => item,
        where: (item, updated) => item['id'] == updated['id'],
      );

      await mutation.mutate({'id': '2', 'name': 'Updated Item 2'});

      final cached = ZenQueryCache.instance
          .getCachedData<List<Map<String, dynamic>>>('items');
      expect(cached?[1]['name'], 'Updated Item 2');
    });

    test('rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<List<Map<String, dynamic>>>(
        'items',
        (_) => [
          {'id': '1', 'name': 'Item 1'},
        ],
      );

      final mutation = ZenMutation.listSet<Map<String, dynamic>>(
        queryKey: 'items',
        mutationKey: 'update_item',
        mutationFn: (item) async => throw Exception('Failed'),
        where: (item, updated) => item['id'] == updated['id'],
      );

      await mutation.mutate({'id': '1', 'name': 'Updated'});

      final cached = ZenQueryCache.instance
          .getCachedData<List<Map<String, dynamic>>>('items');
      expect(cached?[0]['name'], 'Item 1'); // Rolled back
    });
  });

  group('ZenMutation.put (single value)', () {
    test('sets single value optimistically', () async {
      final mutation = ZenMutation.put<String>(
        queryKey: 'user',
        mutationKey: 'create_user',
        mutationFn: (user) async => user,
      );

      await mutation.mutate('John');

      final cached = ZenQueryCache.instance.getCachedData<String>('user');
      expect(cached, 'John');
    });

    test('is alias for update', () {
      // Verify add and update have same signature
      final add = ZenMutation.put<String>(
        queryKey: 'user',
        mutationKey: 'create_user',
        mutationFn: (user) async => user,
      );

      final update = ZenMutation.set<String>(
        queryKey: 'user',
        mutationKey: 'update_user',
        mutationFn: (user) async => user,
      );

      expect(add.runtimeType, update.runtimeType);
    });
  });

  group('ZenMutation.set (single value)', () {
    test('updates single value optimistically', () async {
      ZenQueryCache.instance.setQueryData<String>('user', (_) => 'John');

      final mutation = ZenMutation.set<String>(
        queryKey: 'user',
        mutationKey: 'update_user',
        mutationFn: (user) async => user,
      );

      await mutation.mutate('Jane');

      final cached = ZenQueryCache.instance.getCachedData<String>('user');
      expect(cached, 'Jane');
    });

    test('rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<String>('user', (_) => 'John');

      final mutation = ZenMutation.set<String>(
        queryKey: 'user',
        mutationKey: 'update_user',
        mutationFn: (user) async => throw Exception('Failed'),
      );

      await mutation.mutate('Jane');

      final cached = ZenQueryCache.instance.getCachedData<String>('user');
      expect(cached, 'John'); // Rolled back
    });
  });

  group('ZenMutation.remove (single value)', () {
    test('removes single value from cache', () async {
      ZenQueryCache.instance.setQueryData<String>('user', (_) => 'John');

      final mutation = ZenMutation.remove(
        queryKey: 'user',
        mutationKey: 'logout',
        mutationFn: () async {},
      );

      await mutation.mutate(null);

      final cached = ZenQueryCache.instance.getCachedData<String>('user');
      expect(cached, null); // Removed
    });

    test('rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<String>('user', (_) => 'John');

      final mutation = ZenMutation.remove(
        queryKey: 'user',
        mutationKey: 'logout',
        mutationFn: () async => throw Exception('Failed'),
      );

      await mutation.mutate(null);

      final cached = ZenQueryCache.instance.getCachedData<String>('user');
      expect(cached, 'John'); // Rolled back
    });
  });

  group('ZenMutation offline support', () {
    test('helpers work with offline mutation queue', () async {
      // This test verifies that helpers properly set mutationKey
      // which is required for offline queueing
      final mutation = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationKey: 'add_item',
        mutationFn: (item) async => item,
      );

      expect(mutation.mutationKey, 'add_item');
    });
  });
}
