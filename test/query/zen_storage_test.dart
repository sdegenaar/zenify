import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Mock storage implementation
class MockZenStorage implements ZenStorage {
  final Map<String, Map<String, dynamic>> storage = {};

  @override
  Future<void> write(String key, Map<String, dynamic> json) async {
    storage[key] = json;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    return storage[key];
  }

  @override
  Future<void> delete(String key) async {
    storage.remove(key);
  }
}

void main() {
  late MockZenStorage mockStorage;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    mockStorage = MockZenStorage();
    // Inject storage into cache
    ZenQueryCache.instance.setStorage(mockStorage);
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenStorage Persistence', () {
    test('persists data on successful fetch', () async {
      final query = ZenQuery<String>(
        queryKey: 'persist-test',
        fetcher: (_) async => 'persisted-data',
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => {'value': data},
          fromJson: (json) => json['value'] as String,
        ),
      );

      await query.fetch();

      // Check storage
      final stored = await mockStorage.read('persist-test');
      expect(stored, isNotNull);
      expect(stored!['data']['value'], 'persisted-data');
      expect(stored['version'], 1);
    });

    test('hydrates data on init', () async {
      // Pre-populate storage
      await mockStorage.write('hydrate-test', {
        'data': {'value': 'hydrated-data'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      });

      final query = ZenQuery<String>(
        queryKey: 'hydrate-test',
        fetcher: (_) async => 'network-data',
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => {'value': data},
          fromJson: (json) => json['value'] as String,
          // Disable auto-fetch to verify hydration specifically
          refetchOnMount: false,
        ),
      );

      // Wait for async hydration
      await Future.delayed(const Duration(milliseconds: 50));

      expect(query.data.value, 'hydrated-data');
      expect(query.status.value, ZenQueryStatus.success);
    });

    test('does not hydrate expired data', () async {
      // Pre-populate storage with OLD data
      await mockStorage.write('expired-test', {
        'data': {'value': 'old-data'},
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
        'version': 1,
      });

      final query = ZenQuery<String>(
        queryKey: 'expired-test',
        fetcher: (_) async => 'network-data',
        config: ZenQueryConfig(
          persist: true,
          cacheTime: const Duration(minutes: 5), // Expired
          toJson: (data) => {'value': data},
          fromJson: (json) => json['value'] as String,
          refetchOnMount: false,
        ),
      );

      // Wait for hydration check
      await Future.delayed(const Duration(milliseconds: 50));

      expect(query.data.value, null);
      // Should also have deleted from storage
      expect(await mockStorage.read('expired-test'), null);
    });

    test('handles hydration failure gracefully', () async {
      // Malformed data
      await mockStorage.write('malformed-test', {
        'data': 'not-a-map',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final query = ZenQuery<String>(
        queryKey: 'malformed-test',
        fetcher: (_) async => 'network-data',
        config: ZenQueryConfig(
          persist: true,
          toJson: (data) => {'value': data},
          fromJson: (json) => json['value'] as String, // Will crash on String
          refetchOnMount: false,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Should not crash, just no data
      expect(query.data.value, null);
    });
  });
}
