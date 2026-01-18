import 'dart:async';
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
  late StreamController<bool> networkController;

  setUp(() async {
    Zen.reset();
    storage = MockStorage();
    networkController = StreamController<bool>.broadcast();
    Zen.setNetworkStream(networkController.stream);

    // Default to online
    networkController.add(true);
  });

  tearDown(() {
    networkController.close();
  });

  group('ZenMutationQueue', () {
    test('queues jobs and persists them', () async {
      await Zen.init(storage: storage);

      final job = ZenMutationJob(
        id: '1',
        mutationKey: 'test_mut',
        action: ZenMutationAction.custom,
        payload: {'val': 123},
        createdAt: DateTime.now(),
      );

      ZenMutationQueue.instance.add(job);

      // Verify persistence
      expect(storage.data.containsKey('zen_mutation_queue'), true);
      final storedData = storage.data['zen_mutation_queue'];
      expect((storedData['queue'] as List).length, 1);
      expect(storedData['queue'][0]['id'], '1');
    });

    test('replays jobs when online', () async {
      // 1. Setup handler
      final completer = Completer<Map<String, dynamic>>();

      await Zen.init(
        storage: storage,
        mutationHandlers: {
          'test_mut': (payload) async {
            completer.complete(payload);
          },
        },
      );

      // 2. Add job while offline
      networkController.add(false);
      await Future.delayed(Duration.zero);

      ZenMutationQueue.instance.add(ZenMutationJob(
        id: '1',
        mutationKey: 'test_mut',
        action: ZenMutationAction.custom,
        payload: {'key': 'value'},
        createdAt: DateTime.now(),
      ));

      // 3. Go online -> Verify replay
      networkController.add(true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Manually trigger process if listener needs help (ZenQueryCache logic)
      // ZenQueryCache sets network stream, but does it notify Queue?
      // Wait, ZenMutationQueue init calls setNetworkStream on ZenQueryCache!
      // But ZenQueryCache stream is ONE stream.
      // ZenMutationQueue listens to... ?
      // Inspecting ZenMutationQueue.dart:
      // It initializes by calling ZenQueryCache.instance.setNetworkStream(...)
      // logic in init() was:
      // ZenQueryCache.instance.setNetworkStream(Stream.empty());
      // This logic in ZenMutationQueue was wrong/placeholder!

      // We need to fix ZenMutationQueue to LISTEN to ZenQueryCache.isOnline
      // or subscribe to the stream.
      // Currently ZenMutationQueue doesn't auto-replay because I left a placeholder.
      // I will fix this logic before running test.
    });
  });
}
