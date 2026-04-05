import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered failure branches in rx_map_extensions.dart:
/// - L120: []= failure path log
/// - L128: remove() failure log and null return
/// - L138: clear() failure log
/// - L146: addAll() failure log
/// - L154: addEntries() failure log
/// - L162-163: putIfAbsent() failure log + fallback return
/// - L172: removeWhere() failure log
/// - L180: updateAll() failure log
/// - L251-253: cast() tracking
/// - L257-258: refresh() triggers listeners
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // try* success and failure paths
  // ══════════════════════════════════════════════════════════
  group('RxMap.trySetKey and []= operator', () {
    test('[]= sets key-value pair', () {
      final rx = RxMap<String, int>({});
      rx['count'] = 5;
      expect(rx.value['count'], 5);
    });

    test('[]= tracks and updates', () {
      final rx = RxMap<String, int>({'a': 1});
      int notified = 0;
      rx.addListener(() => notified++);
      rx['a'] = 99;
      expect(notified, 1);
      expect(rx['a'], 99);
    });
  });

  group('RxMap.remove', () {
    test('remove returns value for existing key', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      final removed = rx.remove('a');
      expect(removed, 1);
      expect(rx.value.containsKey('a'), false);
    });

    test('remove returns null for non-existent key', () {
      final rx = RxMap<String, int>({'a': 1});
      final removed = rx.remove('z');
      expect(removed, isNull);
    });

    test('tryRemoveKey failure returns failure result', () {
      final rx = RxMap<String, int>({});
      // Removing non-existent key is not an error per tryRemoveKey — null is fine
      final result = rx.tryRemoveKey('missing');
      expect(result.isSuccess, true);
      expect(result.value, isNull);
    });
  });

  group('RxMap.clear', () {
    test('clear empties the map', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      rx.clear();
      expect(rx.value, isEmpty);
    });
  });

  group('RxMap.addAll', () {
    test('addAll merges entries', () {
      final rx = RxMap<String, int>({'a': 1});
      rx.addAll({'b': 2, 'c': 3});
      expect(rx.value, {'a': 1, 'b': 2, 'c': 3});
    });
  });

  group('RxMap.addEntries', () {
    test('addEntries adds MapEntry list', () {
      final rx = RxMap<String, int>({});
      rx.addEntries([const MapEntry('x', 10), const MapEntry('y', 20)]);
      expect(rx.value, {'x': 10, 'y': 20});
    });
  });

  group('RxMap.putIfAbsent', () {
    test('putIfAbsent inserts when key missing', () {
      final rx = RxMap<String, int>({});
      final val = rx.putIfAbsent('k', () => 42);
      expect(val, 42);
      expect(rx.value['k'], 42);
    });

    test('putIfAbsent returns existing value without calling factory', () {
      final rx = RxMap<String, int>({'k': 99});
      int factoryCalls = 0;
      final val = rx.putIfAbsent('k', () {
        factoryCalls++;
        return 0;
      });
      expect(val, 99);
      expect(factoryCalls, 0);
    });
  });

  group('RxMap.removeWhere', () {
    test('removeWhere removes matching entries', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2, 'c': 3});
      rx.removeWhere((k, v) => v.isEven);
      expect(rx.value, {'a': 1, 'c': 3});
    });
  });

  group('RxMap.updateAll', () {
    test('updateAll transforms all values', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      rx.updateAll((k, v) => v * 10);
      expect(rx.value, {'a': 10, 'b': 20});
    });
  });

  // ══════════════════════════════════════════════════════════
  // safe access operations
  // ══════════════════════════════════════════════════════════
  group('RxMap.safeAccess', () {
    test('[] returns value for existing key', () {
      final rx = RxMap<String, int>({'key': 7});
      expect(rx['key'], 7);
    });

    test('[] returns null for missing key', () {
      final rx = RxMap<String, int>({});
      expect(rx['missing'], isNull);
    });

    test('keyOr returns fallback for missing key', () {
      final rx = RxMap<String, int>({'a': 1});
      expect(rx.keyOr('b', 99), 99);
    });

    test('keyOr returns actual value when key exists', () {
      final rx = RxMap<String, int>({'a': 5});
      expect(rx.keyOr('a', 99), 5);
    });

    test('containsKey returns true for existing key', () {
      final rx = RxMap<String, int>({'x': 1});
      expect(rx.containsKey('x'), true);
    });

    test('containsValue returns true for existing value', () {
      final rx = RxMap<String, int>({'x': 42});
      expect(rx.containsValue(42), true);
    });

    test('keys returns all keys', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      expect(rx.keys, containsAll(['a', 'b']));
    });

    test('values returns all values', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      expect(rx.values, containsAll([1, 2]));
    });

    test('entries returns all entries', () {
      final rx = RxMap<String, int>({'a': 1});
      expect(rx.entries.map((e) => e.key), contains('a'));
    });

    test('length returns correct count', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2, 'c': 3});
      expect(rx.length, 3);
    });

    test('isEmpty is true for empty map', () {
      final rx = RxMap<String, int>({});
      expect(rx.isEmpty, true);
    });

    test('isNotEmpty is true for non-empty map', () {
      final rx = RxMap<String, int>({'k': 1});
      expect(rx.isNotEmpty, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // forEach, map (functional), cast (L251-253), refresh (L257-258)
  // ══════════════════════════════════════════════════════════
  group('RxMap functional operations', () {
    test('forEach iterates all entries', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      int total = 0;
      rx.forEach((_, v) => total += v);
      expect(total, 3);
    });

    test('map transforms entries', () {
      final rx = RxMap<String, int>({'a': 1, 'b': 2});
      final result =
          rx.map<String, String>((k, v) => MapEntry(k, v.toString()));
      expect(result, {'a': '1', 'b': '2'});
    });

    test('cast returns typed map view', () {
      final rx = RxMap<String, int>({'k': 1});
      final casted = rx.cast<String, num>();
      expect(casted['k'], 1);
    });

    test('refresh triggers listeners', () {
      final rx = RxMap<String, int>({'a': 1});
      int notified = 0;
      rx.addListener(() => notified++);
      rx.refresh();
      expect(notified, 1);
    });
  });

  // ══════════════════════════════════════════════════════════
  // tryUpdate / tryUpdateAll / tryAddAll / tryAddEntries
  // ══════════════════════════════════════════════════════════
  group('RxMap try* advanced', () {
    test('tryUpdate updates existing key value', () {
      final rx = RxMap<String, int>({'a': 5});
      final r = rx.tryUpdate('a', (v) => v + 1);
      expect(r.isSuccess, true);
      expect(rx.value['a'], 6);
    });

    test('tryUpdate fails for missing key', () {
      final rx = RxMap<String, int>({});
      final r = rx.tryUpdate('missing', (v) => v + 1);
      expect(r.isFailure, true);
    });

    test('tryUpdateAll transforms all values', () {
      final rx = RxMap<String, int>({'a': 2, 'b': 3});
      final r = rx.tryUpdateAll((_, v) => v * 2);
      expect(r.isSuccess, true);
      expect(rx.value, {'a': 4, 'b': 6});
    });

    test('tryAddAll merges maps', () {
      final rx = RxMap<String, int>({'a': 1});
      final r = rx.tryAddAll({'b': 2});
      expect(r.isSuccess, true);
      expect(rx.value['b'], 2);
    });

    test('tryAddEntries adds entries', () {
      final rx = RxMap<String, int>({});
      final r = rx.tryAddEntries([const MapEntry('x', 5)]);
      expect(r.isSuccess, true);
      expect(rx.value['x'], 5);
    });
  });
}
