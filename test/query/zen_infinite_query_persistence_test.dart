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

  group('ZenInfiniteQuery Persistence', () {
    test('hydrates and restores pagination cursors', () async {
      // 1. Seed storage with 2 pages of data [1, 2]
      // Assume page param is int. next param is last + 1.
      storage.data['feed'] = {
        'data': {
          'data': [1, 2]
        }, // Wraps list in Map to match toJson
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      // 2. Create Infinite Query
      final query = ZenInfiniteQuery<int>(
        queryKey: 'feed',
        infiniteFetcher: (param, _) async {
          // Should fetch page 3 if hydrated correctly (cursor should be 3)
          if (param == 3) return 3;
          return 999; // Error signal
        },
        getNextPageParam: (lastPage, allPages) {
          // If last page is 2, next is 3.
          // If last page is 3, next is 4.
          return lastPage + 1;
        },
        initialPageParam: 1,
        config: ZenQueryConfig(
          persist: true,
          // Simple serialization for List<int>
          toJson: (data) => {'data': data},
          fromJson: (json) => List<int>.from(json['data']),
          staleTime: const Duration(hours: 1), // Use cache
        ),
      );

      // 3. Wait for hydration (async)
      await Future.delayed(const Duration(milliseconds: 50));

      // 4. Verify Data Restoration
      expect(query.data.value, [1, 2]);

      // 5. Verify Cursor Restoration
      // Logic: loaded [1, 2]. Last page is 2. getNextPageParam(2) -> 3.
      // So hasNextPage should be true. Next param should be 3.
      expect(query.hasNextPage.value, true);

      // 6. Fetch Next Page
      // This verifies that _nextPageParam was correctly updated via the listener
      await query.fetchNextPage();

      // 7. Verify New State
      expect(query.data.value, [1, 2, 3]); // Appended page 3
      expect(query.hasNextPage.value, true); // Next is 4
    });
  });
}
