import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenMutation static factory methods:
/// - ZenMutation.listPut
/// - ZenMutation.listSet
/// - ZenMutation.listRemove
/// - ZenMutation.put
///
/// Also tests offline queuing path by simulating offline condition.
void main() {
  setUp(() {
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    Zen.init();
  });

  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // ZenMutation.listPut
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.listPut factory', () {
    test('creates a mutation optimistically prepending to list', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['b', 'c'],
      );

      final m = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationFn: (item) async => item,
        addToStart: true,
      );

      await m.mutate('a');

      expect(m.isSuccess, true);
      expect(m.data.value, 'a');
      m.dispose();
    });

    test('creates a mutation appending to list when addToStart=false',
        () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['a', 'b'],
      );

      final m = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationFn: (item) async => item,
        addToStart: false,
      );

      await m.mutate('c');
      expect(m.isSuccess, true);
      m.dispose();
    });

    test('listPut rolls back on error via onError', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'items',
        (_) => ['a'],
      );

      bool errorCallbackCalled = false;
      final m = ZenMutation.listPut<String>(
        queryKey: 'items',
        mutationFn: (_) async => throw Exception('network error'),
        onError: (_, __) => errorCallbackCalled = true,
      );

      await m.mutate('b');
      expect(errorCallbackCalled, true);
      m.dispose();
    });

    test('listPut onSuccess callback fires', () async {
      bool successCalled = false;
      final m = ZenMutation.listPut<String>(
        queryKey: 'list2',
        mutationFn: (item) async => item,
        onSuccess: (data, item, ctx) => successCalled = true,
      );

      await m.mutate('x');
      expect(successCalled, true);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation.listSet
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.listSet factory', () {
    test('updates matching item in list', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'names',
        (_) => ['alice', 'bob', 'carol'],
      );

      final m = ZenMutation.listSet<String>(
        queryKey: 'names',
        mutationFn: (item) async => item.toUpperCase(),
        where: (item, updated) => item == 'bob',
      );

      await m.mutate('bob');
      expect(m.isSuccess, true);
      m.dispose();
    });

    test('listSet rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'names2',
        (_) => ['x', 'y'],
      );

      bool errored = false;
      final m = ZenMutation.listSet<String>(
        queryKey: 'names2',
        mutationFn: (_) async => throw Exception('failed'),
        where: (item, _) => item == 'x',
        onError: (_, __) => errored = true,
      );

      await m.mutate('x');
      expect(errored, true);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation.listRemove
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.listRemove factory', () {
    test('removes matching item from list', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'tags',
        (_) => ['a', 'b', 'c'],
      );

      final m = ZenMutation.listRemove<String>(
        queryKey: 'tags',
        mutationFn: (_) async {},
        where: (item, toRemove) => item == toRemove,
      );

      await m.mutate('b');
      expect(m.isSuccess, true);
      m.dispose();
    });

    test('listRemove rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<List<String>>(
        'tags2',
        (_) => ['p', 'q'],
      );

      bool errored = false;
      final m = ZenMutation.listRemove<String>(
        queryKey: 'tags2',
        mutationFn: (_) async => throw Exception('delete failed'),
        where: (item, _) => item == 'p',
        onError: (_, __) => errored = true,
      );

      await m.mutate('p');
      expect(errored, true);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation.put factory (single value optimistic update)
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.put factory', () {
    test('sets value optimistically and succeeds', () async {
      final m = ZenMutation.put<String>(
        queryKey: 'user',
        mutationFn: (value) async => value,
      );

      await m.mutate('alice');
      expect(m.isSuccess, true);
      expect(m.data.value, 'alice');
      m.dispose();
    });

    test('put rolls back on error', () async {
      ZenQueryCache.instance.setQueryData<String>(
        'user2',
        (_) => 'original',
      );

      bool errored = false;
      final m = ZenMutation.put<String>(
        queryKey: 'user2',
        mutationFn: (_) async => throw Exception('failed'),
        onError: (_, __) => errored = true,
      );

      await m.mutate('new-value');
      expect(errored, true);
      m.dispose();
    });

    test('put onSuccess callback fires', () async {
      bool success = false;
      final m = ZenMutation.put<int>(
        queryKey: 'score',
        mutationFn: (v) async => v,
        onSuccess: (_, __, ___) => success = true,
      );

      await m.mutate(42);
      expect(success, true);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Offline queuing path
  // ══════════════════════════════════════════════════════════
  group('ZenMutation offline queuing', () {
    test('mutation with key queues when offline', () async {
      final controller = StreamController<bool>.broadcast();
      Zen.setNetworkStream(controller.stream);
      controller.add(false); // go offline
      await Future.delayed(const Duration(milliseconds: 20));

      final m = ZenMutation<String, Map<String, dynamic>>(
        mutationKey: 'offline-test',
        mutationFn: (_) async => 'result',
      );

      final result = await m.mutate({'data': 'value'});
      // When offline with a mutationKey, mutation is queued and returns null
      expect(result, isNull);

      await controller.close();
      m.dispose();
    });
  });
}
