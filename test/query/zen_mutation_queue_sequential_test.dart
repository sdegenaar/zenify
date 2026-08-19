// test/query/zen_mutation_queue_sequential_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  late StreamController<bool> networkController;

  setUp(() {
    Zen.init();
    networkController = StreamController<bool>.broadcast();
    Zen.setNetworkStream(networkController.stream);
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() async {
    final queue = ZenMutationQueue.instance;
    final jobs = List.of(queue.pendingJobs);
    for (final job in jobs) {
      queue.remove(job.id);
    }
    await networkController.close();
    Zen.reset();
  });

  ZenMutationJob makeJob(String id, String key, Map<String, dynamic> payload) {
    return ZenMutationJob(
      id: id,
      mutationKey: key,
      action: ZenMutationAction.custom,
      payload: payload,
      createdAt: DateTime.now(),
    );
  }

  group('ZenMutationQueue sequential replay', () {
    test('replays multiple queued mutations in strict sequential FIFO order',
        () async {
      final executionOrder = <String>[];
      final queue = ZenMutationQueue.instance;

      queue.registerHandlers({
        'chat': (payload) async {
          final msg = payload['text'] as String;
          await Future.delayed(const Duration(milliseconds: 10));
          executionOrder.add(msg);
        },
      });

      queue.add(makeJob('1', 'chat', {'text': 'msg1'}));
      queue.add(makeJob('2', 'chat', {'text': 'msg2'}));
      queue.add(makeJob('3', 'chat', {'text': 'msg3'}));

      expect(queue.pendingCount, 3);

      // Trigger process
      networkController.add(true);
      await queue.process();

      expect(executionOrder, ['msg1', 'msg2', 'msg3']);
      expect(queue.pendingCount, 0);
    });

    test('stops processing on error and keeps remaining jobs in FIFO order',
        () async {
      final executionOrder = <String>[];
      final queue = ZenMutationQueue.instance;
      bool failMsg2 = true;

      queue.registerHandlers({
        'chat': (payload) async {
          final msg = payload['text'] as String;
          if (msg == 'msg2' && failMsg2) {
            throw Exception('network error while sending msg2');
          }
          executionOrder.add(msg);
        },
      });

      queue.add(makeJob('1', 'chat', {'text': 'msg1'}));
      queue.add(makeJob('2', 'chat', {'text': 'msg2'}));
      queue.add(makeJob('3', 'chat', {'text': 'msg3'}));

      // Process with failure on msg2
      networkController.add(true);
      await queue.process();

      // msg1 succeeded, msg2 failed, msg3 was NOT attempted out of order
      expect(executionOrder, ['msg1']);
      expect(queue.pendingCount, 2);
      expect(queue.pendingJobs.map((j) => j.id).toList(), ['2', '3']);

      // Now fix failure and process again
      failMsg2 = false;
      await queue.process();

      expect(executionOrder, ['msg1', 'msg2', 'msg3']);
      expect(queue.pendingCount, 0);
    });

    test(
        'silently drops job with unregistered handler and continues processing subsequent valid jobs',
        () async {
      final executed = <String>[];
      final queue = ZenMutationQueue.instance;

      queue.registerHandlers({
        'known': (payload) async => executed.add(payload['id'] as String),
      });

      // First job has no registered handler — should be dropped with a warning,
      // NOT halt the queue (unlike a network failure).
      queue.add(makeJob('1', 'UNKNOWN_KEY', {'id': 'ghost'}));
      queue.add(makeJob('2', 'known', {'id': 'msg2'}));
      queue.add(makeJob('3', 'known', {'id': 'msg3'}));

      networkController.add(true);
      await queue.process();

      // Unregistered job is dropped, subsequent known jobs run in order
      expect(executed, ['msg2', 'msg3']);
      expect(queue.pendingCount, 0);
    });
  });
}
