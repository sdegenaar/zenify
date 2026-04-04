import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('InMemoryStorage', () {
    test('write and read round-trips correctly', () async {
      final storage = InMemoryStorage();

      await storage.write('key', {'value': 'test'});
      final result = await storage.read('key');

      expect(result, isNotNull);
      expect(result!['value'], 'test');
    });

    test('read returns null for missing key', () async {
      final storage = InMemoryStorage();
      expect(await storage.read('missing'), isNull);
    });

    test('delete removes the key', () async {
      final storage = InMemoryStorage();
      await storage.write('key', {'data': 1});
      await storage.delete('key');
      expect(await storage.read('key'), isNull);
    });

    test('delete on nonexistent key does not throw', () async {
      final storage = InMemoryStorage();
      await expectLater(storage.delete('never-existed'), completes);
    });

    test('clear removes all entries', () async {
      final storage = InMemoryStorage();
      await storage.write('a', {'data': 1});
      await storage.write('b', {'data': 2});

      storage.clear();

      expect(await storage.read('a'), isNull);
      expect(await storage.read('b'), isNull);
      expect(storage.length, 0);
    });

    test('keys returns all stored keys', () async {
      final storage = InMemoryStorage();
      await storage.write('x', {});
      await storage.write('y', {});

      expect(storage.keys, containsAll(['x', 'y']));
    });

    test('containsKey returns correct result', () async {
      final storage = InMemoryStorage();
      await storage.write('exists', {});

      expect(storage.containsKey('exists'), isTrue);
      expect(storage.containsKey('missing'), isFalse);
    });

    test('returned map is a copy — mutations do not affect stored data',
        () async {
      final storage = InMemoryStorage();
      await storage.write('key', {'count': 0});

      final result = await storage.read('key');
      result!['count'] = 999; // mutate the returned copy

      final result2 = await storage.read('key');
      expect(result2!['count'], 0); // original unchanged
    });

    test('overwrite replaces existing value', () async {
      final storage = InMemoryStorage();
      await storage.write('key', {'v': 1});
      await storage.write('key', {'v': 2});

      expect((await storage.read('key'))!['v'], 2);
    });

    test('length tracks correctly through writes and deletes', () async {
      final storage = InMemoryStorage();
      expect(storage.length, 0);

      await storage.write('a', {});
      expect(storage.length, 1);

      await storage.write('b', {});
      expect(storage.length, 2);

      await storage.delete('a');
      expect(storage.length, 1);
    });

    test('handles nested JSON structures', () async {
      final storage = InMemoryStorage();

      final complex = {
        'data': {
          'users': [
            {'id': 1, 'name': 'Alice', 'active': true},
            {'id': 2, 'name': 'Bob', 'active': false},
          ],
          'meta': {'total': 2, 'page': 1},
        },
        'timestamp': 9999,
        'version': 1,
      };

      await storage.write('complex', complex);
      final result = await storage.read('complex');

      expect(result, isNotNull);
      final users = result!['data']['users'] as List;
      expect(users.length, 2);
      expect(users[0]['name'], 'Alice');
      expect(result['data']['meta']['total'], 2);
    });

    test('two independent instances have separate stores', () async {
      final storage1 = InMemoryStorage();
      final storage2 = InMemoryStorage();

      await storage1.write('key', {'from': 'storage1'});

      expect(await storage1.read('key'), isNotNull);
      expect(await storage2.read('key'), isNull); // storage2 is independent
    });
  });

  group('ZenStorage integration with ZenQuery', () {
    setUp(() {
      Zen.init();
    });

    tearDown(() {
      Zen.reset();
    });

    test('InMemoryStorage persists query data end-to-end', () async {
      final storage = InMemoryStorage();
      ZenQueryCache.instance.setStorage(storage);
      Zen.testMode().clearQueryCache();

      final query = ZenQuery<int>(
        queryKey: 'persist-memory',
        fetcher: (_) async => 42,
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => {'number': data},
          fromJson: (json) => json['number'] as int,
        ),
      );

      await query.fetch();

      expect(storage.containsKey('persist-memory'), isTrue);
      final stored = await storage.read('persist-memory');
      expect(stored!['data']['number'], 42);
    });

    test('hydration from InMemoryStorage pre-populates query data', () async {
      final storage = InMemoryStorage();

      // Pre-populate as if a previous session had stored this
      await storage.write('hydrate-memory', {
        'data': {'value': 'hydrated-from-memory'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      });

      ZenQueryCache.instance.setStorage(storage);
      Zen.testMode().clearQueryCache();

      final query = ZenQuery<String>(
        queryKey: 'hydrate-memory',
        fetcher: (_) async => 'network-value',
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => {'value': data},
          fromJson: (json) => json['value'] as String,
          refetchOnMount: RefetchBehavior.never,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(query.data.value, 'hydrated-from-memory');
      expect(query.status.value, ZenQueryStatus.success);
    });

    test('InMemoryStorage is a valid ZenStorage interface', () {
      // Verify InMemoryStorage satisfies the ZenStorage contract
      final ZenStorage storage = InMemoryStorage();
      expect(storage, isA<ZenStorage>());
    });
  });
}
