import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxMap try* methods', () {
    test('trySetKey sets a value and notifies', () {
      final map = <String, int>{}.obs();
      final result = map.trySetKey('a', 1);
      expect(result.isSuccess, true);
      expect(map.value['a'], 1);
    });

    test('trySetKey overwrites existing key', () {
      final map = {'a': 1}.obs();
      map.trySetKey('a', 99);
      expect(map.value['a'], 99);
    });

    test('tryRemoveKey removes existing key', () {
      final map = {'a': 1, 'b': 2}.obs();
      final result = map.tryRemoveKey('a');
      expect(result.isSuccess, true);
      expect(result.value, 1);
      expect(map.value.containsKey('a'), false);
    });

    test('tryRemoveKey returns null for missing key', () {
      final map = <String, int>{}.obs();
      final result = map.tryRemoveKey('x');
      expect(result.isSuccess, true);
      expect(result.value, isNull);
    });

    test('tryClear empties a non-empty map', () {
      final map = {'a': 1, 'b': 2}.obs();
      final result = map.tryClear();
      expect(result.isSuccess, true);
      expect(map.value.isEmpty, true);
    });

    test('tryClear on empty map is a no-op', () {
      final map = <String, int>{}.obs();
      var notifications = 0;
      map.addListener(() => notifications++);
      map.tryClear();
      expect(notifications, 0);
    });

    test('tryAddAll merges entries', () {
      final map = {'a': 1}.obs();
      final result = map.tryAddAll({'b': 2, 'c': 3});
      expect(result.isSuccess, true);
      expect(map.value, {'a': 1, 'b': 2, 'c': 3});
    });

    test('tryAddAll with empty map is a no-op', () {
      final map = {'a': 1}.obs();
      var notifications = 0;
      map.addListener(() => notifications++);
      map.tryAddAll({});
      expect(notifications, 0);
    });

    test('tryAddEntries adds entries', () {
      final map = <String, int>{}.obs();
      map.tryAddEntries([const MapEntry('x', 10), const MapEntry('y', 20)]);
      expect(map.value, {'x': 10, 'y': 20});
    });

    test('tryPutIfAbsent adds when missing', () {
      final map = <String, int>{}.obs();
      final result = map.tryPutIfAbsent('k', () => 42);
      expect(result.isSuccess, true);
      expect(result.value, 42);
      expect(map.value['k'], 42);
    });

    test('tryPutIfAbsent does not overwrite existing key', () {
      final map = {'k': 7}.obs();
      final result = map.tryPutIfAbsent('k', () => 99);
      expect(result.value, 7);
      expect(map.value['k'], 7);
    });

    test('tryRemoveWhere removes matching entries', () {
      final map = {'a': 1, 'b': 2, 'c': 3}.obs();
      map.tryRemoveWhere((k, v) => v.isEven);
      expect(map.value, {'a': 1, 'c': 3});
    });

    test('tryRemoveWhere with no match is a no-op', () {
      final map = {'a': 1}.obs();
      var notifications = 0;
      map.addListener(() => notifications++);
      map.tryRemoveWhere((k, v) => v > 100);
      expect(notifications, 0);
    });

    test('tryUpdate updates existing value', () {
      final map = {'a': 5}.obs();
      final result = map.tryUpdate('a', (v) => v * 2);
      expect(result.isSuccess, true);
      expect(result.value, 10);
      expect(map.value['a'], 10);
    });

    test('tryUpdate uses ifAbsent when key missing', () {
      final map = <String, int>{}.obs();
      final result = map.tryUpdate('x', (v) => v + 1, ifAbsent: () => 0);
      expect(result.isSuccess, true);
      expect(result.value, 0);
    });

    test('tryUpdateAll updates every value', () {
      final map = {'a': 1, 'b': 2}.obs();
      map.tryUpdateAll((k, v) => v * 10);
      expect(map.value, {'a': 10, 'b': 20});
    });

    test('tryGetKey returns value for existing key', () {
      final map = {'key': 42}.obs();
      final result = map.tryGetKey('key');
      expect(result.isSuccess, true);
      expect(result.value, 42);
    });

    test('tryGetKey fails for missing key', () {
      final map = <String, int>{}.obs();
      final result = map.tryGetKey('missing');
      expect(result.isFailure, true);
    });
  });

  group('RxMap convenience methods', () {
    test('operator []= sets a key', () {
      final map = <String, int>{}.obs();
      map['name'] = 100;
      expect(map.value['name'], 100);
    });

    test('remove deletes a key and returns value', () {
      final map = {'a': 1, 'b': 2}.obs();
      final removed = map.remove('a');
      expect(removed, 1);
      expect(map.value.containsKey('a'), false);
    });

    test('remove missing key returns null', () {
      final map = <String, int>{}.obs();
      expect(map.remove('x'), isNull);
    });

    test('clear empties the map', () {
      final map = {'a': 1, 'b': 2}.obs();
      map.clear();
      expect(map.isEmpty, true);
    });

    test('addAll merges another map', () {
      final map = {'a': 1}.obs();
      map.addAll({'b': 2, 'c': 3});
      expect(map.value.length, 3);
    });

    test('addEntries adds from iterable', () {
      final map = <String, int>{}.obs();
      map.addEntries([const MapEntry('p', 1), const MapEntry('q', 2)]);
      expect(map.value, {'p': 1, 'q': 2});
    });

    test('putIfAbsent returns and inserts missing key', () {
      final map = <String, int>{}.obs();
      final val = map.putIfAbsent('z', () => 99);
      expect(val, 99);
      expect(map.value['z'], 99);
    });

    test('removeWhere removes matching entries', () {
      final map = {'a': 1, 'b': 2, 'c': 3}.obs();
      map.removeWhere((k, v) => v > 1);
      expect(map.value, {'a': 1});
    });

    test('tryUpdate updates existing value', () {
      final map = {'score': 10}.obs();
      final result = map.tryUpdate('score', (v) => v + 5);
      expect(result.isSuccess, true);
      expect(result.value, 15);
      expect(map.value['score'], 15);
    });

    test('tryUpdate with ifAbsent inserts missing key', () {
      final map = <String, int>{}.obs();
      final result = map.tryUpdate('x', (v) => v, ifAbsent: () => 0);
      expect(result.isSuccess, true);
      expect(result.value, 0);
    });

    test('updateAll updates every entry', () {
      final map = {'a': 1, 'b': 2}.obs();
      map.updateAll((k, v) => v + 100);
      expect(map.value, {'a': 101, 'b': 102});
    });
  });

  group('RxMap access operators', () {
    test('operator [] reads value', () {
      final map = {'x': 42}.obs();
      expect(map['x'], 42);
    });

    test('operator [] returns null for missing key', () {
      final map = <String, int>{}.obs();
      expect(map['missing'], isNull);
    });

    test('keyOr returns value when key exists', () {
      final map = {'a': 1}.obs();
      expect(map.keyOr('a', 99), 1);
    });

    test('keyOr returns fallback when key missing', () {
      final map = <String, int>{}.obs();
      expect(map.keyOr('missing', 42), 42);
    });

    test('containsKey returns correct result', () {
      final map = {'a': 1}.obs();
      expect(map.containsKey('a'), true);
      expect(map.containsKey('b'), false);
    });

    test('containsValue returns correct result', () {
      final map = {'a': 1}.obs();
      expect(map.containsValue(1), true);
      expect(map.containsValue(99), false);
    });

    test('keys returns all keys', () {
      final map = {'a': 1, 'b': 2}.obs();
      expect(map.keys.toList()..sort(), ['a', 'b']);
    });

    test('values returns all values', () {
      final map = {'a': 1, 'b': 2}.obs();
      expect(map.values.toList()..sort(), [1, 2]);
    });

    test('entries returns all entries', () {
      final map = {'a': 1}.obs();
      final entries = map.entries.toList();
      expect(entries.length, 1);
      expect(entries.first.key, 'a');
    });

    test('length returns entry count', () {
      final map = {'a': 1, 'b': 2, 'c': 3}.obs();
      expect(map.length, 3);
    });

    test('isEmpty is true for empty map', () {
      expect(<String, int>{}.obs().isEmpty, true);
    });

    test('isNotEmpty is true for non-empty map', () {
      expect({'a': 1}.obs().isNotEmpty, true);
    });
  });

  group('RxMap functional operations', () {
    test('forEach iterates entries', () {
      final map = {'a': 1, 'b': 2}.obs();
      final collected = <String>[];
      map.forEach((k, v) => collected.add('$k=$v'));
      expect(collected.length, 2);
    });

    test('map transforms entries', () {
      final map = {'a': 1}.obs();
      final result = map.map((k, v) => MapEntry(k.toUpperCase(), v * 10));
      expect(result, {'A': 10});
    });

    test('refresh notifies listeners without change', () {
      final map = {'a': 1}.obs();
      var notifications = 0;
      map.addListener(() => notifications++);
      map.refresh();
      expect(notifications, 1);
    });
  });

  group('RxMap reactivity', () {
    test('notifies listener on key set', () {
      final map = <String, int>{}.obs();
      var count = 0;
      map.addListener(() => count++);
      map['x'] = 1;
      expect(count, 1);
    });

    test('notifies listener on remove', () {
      final map = {'a': 1}.obs();
      var count = 0;
      map.addListener(() => count++);
      map.remove('a');
      expect(count, 1);
    });

    test('notifies listener on clear', () {
      final map = {'a': 1}.obs();
      var count = 0;
      map.addListener(() => count++);
      map.clear();
      expect(count, 1);
    });
  });
}
