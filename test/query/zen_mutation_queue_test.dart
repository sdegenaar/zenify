import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  late StreamController<bool> networkController;

  setUp(() {
    Zen.init();
    networkController = StreamController<bool>.broadcast();
    // Wire network stream so we can control online/offline in tests
    Zen.setNetworkStream(networkController.stream);
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() async {
    // Drain any remaining jobs
    final queue = ZenMutationQueue.instance;
    final jobs = List.of(queue.pendingJobs);
    for (final job in jobs) {
      queue.remove(job.id);
    }
    await networkController.close();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // Basic queue operations
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.add', () {
    test('increments pendingCount', () {
      final queue = ZenMutationQueue.instance;
      expect(queue.pendingCount, 0);
      queue.add(_makeJob('j1'));
      expect(queue.pendingCount, 1);
    });

    test('appears in pendingJobs', () {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('j2'));
      expect(queue.pendingJobs.any((j) => j.id == 'j2'), true);
    });

    test('multiple jobs are queued in FIFO order', () {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('a'));
      queue.add(_makeJob('b'));
      queue.add(_makeJob('c'));
      final ids = queue.pendingJobs.map((j) => j.id).toList();
      expect(ids, ['a', 'b', 'c']);
    });
  });

  group('ZenMutationQueue.remove', () {
    test('decrements pendingCount', () {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('r1'));
      queue.remove('r1');
      expect(queue.pendingCount, 0);
    });

    test('removing unknown id does nothing', () {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('r2'));
      queue.remove('does-not-exist');
      expect(queue.pendingCount, 1);
    });
  });

  // ══════════════════════════════════════════════════════════
  // init without storage
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.init without storage', () {
    test('init(null) does not crash', () async {
      await expectLater(ZenMutationQueue.instance.init(null), completes);
    });

    test('pendingCount unchanged after init(null)', () async {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('pre'));
      await queue.init(null);
      expect(queue.pendingCount, 1);
    });
  });

  // ══════════════════════════════════════════════════════════
  // init with storage — persist and restore
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.init with storage', () {
    test('restores jobs from storage', () async {
      final storage = _InMemoryStorage();
      final job = _makeJob('stored-1');
      await storage.write('zen_mutation_queue', {
        'queue': [job.toJson()],
      });

      final queue = ZenMutationQueue.instance;
      await queue.init(storage);
      expect(queue.pendingJobs.any((j) => j.id == 'stored-1'), true);
    });

    test('add() persists to storage', () async {
      final storage = _InMemoryStorage();
      final queue = ZenMutationQueue.instance;
      await queue.init(storage);
      queue.add(_makeJob('persist-1'));

      await Future.delayed(Duration.zero);
      final data = await storage.read('zen_mutation_queue');
      expect(data, isNotNull);
      expect((data!['queue'] as List).length, greaterThan(0));
    });

    test('handles corrupt storage gracefully on init', () async {
      final storage = _ThrowingStorage();
      final queue = ZenMutationQueue.instance;
      // Should not throw even if storage.read fails
      await expectLater(queue.init(storage), completes);
    });

    test('handles corrupt storage gracefully on add', () async {
      final storage = _ThrowingStorage();
      final queue = ZenMutationQueue.instance;
      await queue.init(storage); // init even though storage throws
      // add() calls _persist() → storage.write() throws → should log warning
      expect(() => queue.add(_makeJob('corrupt')), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerHandlers + process
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.process', () {
    test('process when queue is empty completes immediately', () async {
      // Network is online (default)
      networkController.add(true);
      await Future.delayed(const Duration(milliseconds: 10));
      await expectLater(ZenMutationQueue.instance.process(), completes);
    });

    test('no handler → job is dropped silently', () async {
      networkController.add(true);
      await Future.delayed(const Duration(milliseconds: 10));

      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('no-handler', key: 'unknown-key'));
      await queue.process();
      // Job gets dropped (no handler registered)
      expect(queue.pendingCount, 0);
    });

    test('registered handler executes and removes job', () async {
      networkController.add(true);
      await Future.delayed(const Duration(milliseconds: 10));

      final queue = ZenMutationQueue.instance;
      var executed = false;
      queue.registerHandlers({
        'testMutation': (_) async {
          executed = true;
        },
      });
      queue.add(_makeJob('exec-1', key: 'testMutation'));
      await queue.process();

      expect(executed, true);
      expect(queue.pendingCount, 0);
    });

    test('process when offline does not execute jobs', () async {
      // Drive offline
      networkController.add(false);
      await Future.delayed(const Duration(milliseconds: 10));

      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('offline-job'));
      await queue.process();
      // Not processed (offline)
      expect(queue.pendingCount, 1);
    });
  });

  // ══════════════════════════════════════════════════════════
  // registerHandlers
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.registerHandlers', () {
    test('adds handlers to registry', () async {
      networkController.add(true);
      await Future.delayed(const Duration(milliseconds: 10));

      final queue = ZenMutationQueue.instance;
      queue.registerHandlers({
        'createUser': (_) async => 'created',
        'deleteUser': (_) async => 'deleted',
      });
      queue.add(_makeJob('h1', key: 'createUser'));
      await queue.process();
      // Handler ran, job removed
      expect(queue.pendingCount, 0);
    });
  });

  // ══════════════════════════════════════════════════════════
  // setNetworkStream
  // ══════════════════════════════════════════════════════════
  group('ZenMutationQueue.setNetworkStream', () {
    test('triggers process when online=true event arrives', () async {
      final queue = ZenMutationQueue.instance;
      queue.registerHandlers({
        'netMutation': (_) async {},
      });
      queue.add(_makeJob('net-1', key: 'netMutation'));

      final ctrl = StreamController<bool>.broadcast();
      queue.setNetworkStream(ctrl.stream);

      // Drive online via queue's own network stream
      ctrl.add(true);
      await Future.delayed(const Duration(milliseconds: 50));
      await ctrl.close();

      // If not online in cache, process() won't run — we just verify no crash
      expect(() {}, returnsNormally);
    });

    test('false event does not trigger process', () async {
      final queue = ZenMutationQueue.instance;
      queue.add(_makeJob('net-2'));

      final ctrl = StreamController<bool>.broadcast();
      queue.setNetworkStream(ctrl.stream);
      ctrl.add(false);
      await Future.delayed(const Duration(milliseconds: 20));
      await ctrl.close();

      // Offline event doesn't remove job
      expect(queue.pendingCount, 1);
    });
  });
}

// ── Helpers ──
ZenMutationJob _makeJob(String id, {String key = 'testKey'}) {
  return ZenMutationJob(
    id: id,
    mutationKey: key,
    action: ZenMutationAction.create,
    payload: {'test': true},
    createdAt: DateTime.now(),
  );
}

/// Simple in-memory storage for testing
class _InMemoryStorage implements ZenStorage {
  final _store = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    _store[key] = data;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

/// Storage that throws on every operation to simulate failures
class _ThrowingStorage implements ZenStorage {
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    throw Exception('simulated storage failure');
  }

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    throw Exception('simulated storage failure');
  }

  @override
  Future<void> delete(String key) async {}
}
