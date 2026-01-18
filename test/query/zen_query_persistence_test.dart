import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Mock Storage
class MockStorage implements ZenStorage {
  Map<String, dynamic> data = {};

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    return data[key];
  }

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    data[key] = json;
  }
}

void main() {
  late MockStorage storage;

  setUp(() async {
    Zen.reset();
    Zen.testMode().clearQueryCache();
    storage = MockStorage();
    await Zen.init(storage: storage);
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery Persistence', () {
    test('persists data to storage', () async {
      final query = ZenQuery<Map<String, dynamic>>(
        queryKey: 'persist-test',
        fetcher: (_) async => {'val': 123},
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => data,
          fromJson: (json) => json,
        ),
      );

      // Fetch to populate data
      await query.fetch();

      // Verify storage
      expect(storage.data.containsKey('persist-test'), true);
      final stored = storage.data['persist-test'];
      expect(stored['data']['val'], 123);
    });

    test('hydrates data from storage', () async {
      // 1. Seed storage
      storage.data['hydrate-test'] = {
        'data': {'val': 999},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      // 2. Create query
      final query = ZenQuery<Map<String, dynamic>>(
        queryKey: 'hydrate-test',
        // Should fetch if stale, but initData happens first
        fetcher: (_) async => {'val': 888},
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => data,
          fromJson: (json) => json,
          staleTime: const Duration(hours: 1), // Fresh enough to use cache
        ),
      );

      // Wait for hydration (it happens in constructor/initData async)
      // Since hydration is async, and we don't await initData in constructor,
      // we need to wait a tick or check fetching state.
      // But query.data is not a Future.
      // We can await query.fetch() which will perform hydration logic steps?
      // No, initData calls hydrate() then fetch().
      // If we wait briefly, data should appear.

      await Future.delayed(const Duration(milliseconds: 50));

      expect(query.data.value, isNotNull);
      expect(query.data.value!['val'], 999);

      // Should NOT have fetched remote (888) because data was fresh
      expect(query.data.value!['val'], 999);
    });
  });
}
