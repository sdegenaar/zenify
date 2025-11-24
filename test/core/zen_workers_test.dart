// test/core/zen_workers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller with various reactive properties
class TestController extends ZenController {
  final count = 0.obs();
  final text = 'initial'.obs();
  final items = <String>[].obs();

  // An effect for testing effect workers
  late final testEffect = createEffect<String>(name: 'testEffect');

  Future<void> runEffect(String value, {bool shouldFail = false}) async {
    if (testEffect.data.value == value) {
      return; // Prevent re-trigger with duplicate data
    }

    await testEffect.run(() async {
      if (shouldFail) {
        throw Exception('Test error');
      }
      await Future.delayed(const Duration(milliseconds: 10));
      return value;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenWorkers - Clean API Tests', () {
    late TestController controller;

    setUp(() {
      Zen.init();
      controller = TestController();
    });

    tearDown(() {
      controller.dispose();
      Zen.deleteAll(force: true);
    });

    group('Core Worker Types', () {
      test('ever worker executes on every change', () async {
        final calls = <int>[];

        final handle = controller.ever(controller.count, (value) {
          calls.add(value);
        });

        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        controller.count.value = 3;
        await Future.delayed(Duration.zero);

        expect(calls, [1, 2, 3]);

        handle.dispose();
        controller.count.value = 4;
        await Future.delayed(Duration.zero);
        expect(calls, [1, 2, 3]); // No change after dispose
      });

      test('once worker executes only on first change', () async {
        final calls = <int>[];

        final handle = controller.once(controller.count, (value) {
          calls.add(value);
        });

        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        controller.count.value = 2;
        await Future.delayed(Duration.zero);

        expect(calls, [1]); // Only first change
        handle.dispose(); // Safe to call even after auto-dispose
      });

      test('debounce worker waits for inactivity', () async {
        final calls = <String>[];

        final handle = controller.debounce(
          controller.text,
          (value) => calls.add(value),
          const Duration(milliseconds: 50),
        );

        // Rapid changes
        controller.text.value = 'a';
        await Future.delayed(const Duration(milliseconds: 10));
        controller.text.value = 'b';
        await Future.delayed(const Duration(milliseconds: 10));
        controller.text.value = 'c';

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 100));

        expect(calls, ['c']); // Only last value
        handle.dispose();
      });

      test('throttle worker limits execution frequency', () async {
        final calls = <int>[];

        final handle = controller.throttle(
          controller.count,
          (value) => calls.add(value),
          const Duration(milliseconds: 50),
        );

        controller.count.value = 1;
        await Future.delayed(const Duration(milliseconds: 10));
        controller.count.value = 2; // Should be throttled
        await Future.delayed(const Duration(milliseconds: 60));
        controller.count.value = 3; // Should execute
        await Future.delayed(const Duration(milliseconds: 10));

        expect(calls, [1, 3]); // First and after throttle period
        handle.dispose();
      });

      test('interval worker runs periodically', () async {
        final calls = <List<String>>[];

        final handle = controller.interval(
          controller.items,
          (value) => calls.add(List.from(value)),
          const Duration(milliseconds: 50),
        );

        controller.items.add('a');
        controller.items.add('b');

        await Future.delayed(const Duration(milliseconds: 100));

        expect(calls, [
          ['a', 'b']
        ]);
        handle.dispose();
      });

      test('condition worker executes only when condition is met', () async {
        final calls = <int>[];

        final handle = controller.condition(
          controller.count,
          (value) => value.isEven,
          (value) => calls.add(value),
        );

        controller.count.value = 1; // Odd, skip
        await Future.delayed(Duration.zero);
        controller.count.value = 2; // Even, execute
        await Future.delayed(Duration.zero);
        controller.count.value = 3; // Odd, skip
        await Future.delayed(Duration.zero);
        controller.count.value = 4; // Even, execute
        await Future.delayed(Duration.zero);

        expect(calls, [2, 4]); // Only even numbers
        handle.dispose();
      });
    });

    group('Pause/Resume Functionality', () {
      test('individual worker can be paused and resumed', () async {
        final calls = <int>[];

        final handle = controller.ever(controller.count, (value) {
          calls.add(value);
        });

        // Initial state
        expect(handle.isPaused, false);
        expect(handle.isActive, true);

        // Execute normally
        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        expect(calls, [1]);

        // Pause worker
        handle.pause();
        expect(handle.isPaused, true);
        expect(handle.isActive, false);

        // Should not execute while paused
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [1]); // No change

        // Resume worker
        handle.resume();
        expect(handle.isPaused, false);
        expect(handle.isActive, true);

        // Should execute after resume
        controller.count.value = 3;
        await Future.delayed(Duration.zero);
        expect(calls, [1, 3]);

        handle.dispose();
      });

      test('debounce worker respects pause/resume', () async {
        final calls = <String>[];

        final handle = controller.debounce(
          controller.text,
          (value) => calls.add(value),
          const Duration(milliseconds: 50),
        );

        // Start change
        controller.text.value = 'a';

        // Pause before debounce timer fires
        await Future.delayed(const Duration(milliseconds: 10));
        handle.pause();

        // Wait past debounce period
        await Future.delayed(const Duration(milliseconds: 100));
        expect(calls, []); // Should not execute while paused

        // Resume and trigger again
        handle.resume();
        controller.text.value = 'b';
        await Future.delayed(const Duration(milliseconds: 100));
        expect(calls, ['b']);

        handle.dispose();
      });

      test('throttle worker respects pause/resume', () async {
        final calls = <int>[];

        final handle = controller.throttle(
          controller.count,
          (value) => calls.add(value),
          const Duration(milliseconds: 50),
        );

        // First call should execute
        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        expect(calls, [1]);

        // Pause worker
        handle.pause();

        // Should not execute while paused even after throttle period
        await Future.delayed(const Duration(milliseconds: 60));
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [1]);

        // Resume and execute
        handle.resume();
        controller.count.value = 3;
        await Future.delayed(Duration.zero);
        expect(calls, [1, 3]);

        handle.dispose();
      });

      test('interval worker respects pause/resume', () async {
        final calls = <List<String>>[];

        final handle = controller.interval(
          controller.items,
          (value) => calls.add(List.from(value)),
          const Duration(milliseconds: 30),
        );

        // Add item and let interval run once
        controller.items.add('a');
        await Future.delayed(const Duration(milliseconds: 50));
        expect(calls.length, 1);
        expect(calls[0], ['a']);

        // Pause worker
        handle.pause();
        controller.items.add('b');

        // Wait for another interval period
        await Future.delayed(const Duration(milliseconds: 50));
        expect(calls.length, 1); // Should not execute while paused

        // Resume worker
        handle.resume();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(calls.length, 2); // Should execute after resume
        expect(calls[1], ['a', 'b']);

        handle.dispose();
      });

      test('condition worker respects pause/resume', () async {
        final calls = <int>[];

        final handle = controller.condition(
          controller.count,
          (value) => value.isEven,
          (value) => calls.add(value),
        );

        // Should execute (even number)
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [2]);

        // Pause worker
        handle.pause();

        // Should not execute while paused even if condition met
        controller.count.value = 4;
        await Future.delayed(Duration.zero);
        expect(calls, [2]);

        // Resume worker
        handle.resume();
        controller.count.value = 6;
        await Future.delayed(Duration.zero);
        expect(calls, [2, 6]);

        handle.dispose();
      });

      test('once worker can be paused before execution', () async {
        final calls = <int>[];

        final handle = controller.once(controller.count, (value) {
          calls.add(value);
        });

        // Pause immediately
        handle.pause();

        // Should not execute while paused
        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        expect(calls, []);

        // Resume and execute
        handle.resume();
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [2]);

        // Should auto-dispose after execution
        controller.count.value = 3;
        await Future.delayed(Duration.zero);
        expect(calls, [2]); // No additional calls
      });
    });

    group('Worker Group Pause/Resume', () {
      test('worker group can pause and resume all workers', () async {
        final calls = <String>[];

        final group = controller.createWorkerGroup();

        // Add multiple workers to group
        group.add(controller.ever(controller.count, (value) {
          calls.add('count:$value');
        }));

        group.add(controller.ever(controller.text, (value) {
          calls.add('text:$value');
        }));

        expect(group.activeCount, 2);
        expect(group.pausedCount, 0);

        // Test normal execution
        controller.count.value = 1;
        controller.text.value = 'hello';
        await Future.delayed(Duration.zero);
        expect(calls, ['count:1', 'text:hello']);

        // Pause all workers in group
        group.pauseAll();
        expect(group.activeCount, 0);
        expect(group.pausedCount, 2);

        // Should not execute while paused
        controller.count.value = 2;
        controller.text.value = 'world';
        await Future.delayed(Duration.zero);
        expect(calls, ['count:1', 'text:hello']);

        // Resume all workers in group
        group.resumeAll();
        expect(group.activeCount, 2);
        expect(group.pausedCount, 0);

        // Should execute after resume
        controller.count.value = 3;
        controller.text.value = 'test';
        await Future.delayed(Duration.zero);
        expect(calls, ['count:1', 'text:hello', 'count:3', 'text:test']);

        group.dispose();
      });

      test('worker group stats are accurate', () async {
        final group = controller.createWorkerGroup();

        // Add workers
        final worker1 = controller.ever(controller.count, (_) {});
        final worker2 = controller.ever(controller.text, (_) {});
        final worker3 = controller.ever(controller.items, (_) {});

        group.add(worker1);
        group.add(worker2);
        group.add(worker3);

        expect(group.length, 3);
        expect(group.activeCount, 3);
        expect(group.pausedCount, 0);

        // Pause some workers individually
        worker1.pause();
        worker2.pause();

        expect(group.length, 3);
        expect(group.activeCount, 1);
        expect(group.pausedCount, 2);

        // Dispose one worker
        worker3.dispose();

        expect(group.length, 2); // Only non-disposed workers
        expect(group.activeCount, 0);
        expect(group.pausedCount, 2);

        group.dispose();
      });
    });

    group('Controller Integration', () {
      test('controller can pause and resume all managed workers', () async {
        final calls = <String>[];

        // Create various workers through controller
        controller.ever(controller.count, (value) {
          calls.add('count:$value');
        });

        controller.debounce(controller.text, (value) {
          calls.add('text:$value');
        }, const Duration(milliseconds: 50));

        // Test normal execution
        controller.count.value = 1;
        controller.text.value = 'test';
        await Future.delayed(const Duration(milliseconds: 100));
        expect(calls, ['count:1', 'text:test']);

        // Pause all workers
        controller.pauseAllWorkers();

        // Should not execute while paused
        controller.count.value = 2;
        controller.text.value = 'paused';
        await Future.delayed(const Duration(milliseconds: 100));
        expect(calls, ['count:1', 'text:test']);

        // Resume all workers
        controller.resumeAllWorkers();

        // Should execute after resume
        controller.count.value = 3;
        controller.text.value = 'resumed';
        await Future.delayed(const Duration(milliseconds: 100));
        expect(calls, ['count:1', 'text:test', 'count:3', 'text:resumed']);
      });

      test('controller provides accurate worker statistics', () async {
        // Create various workers
        final worker1 = controller.ever(controller.count, (_) {});
        final worker2 = controller.debounce(
            controller.text, (_) {}, const Duration(milliseconds: 50));

        // Create a worker group
        final group = controller.createWorkerGroup();
        group.add(controller.ever(controller.items, (_) {}));

        var stats = controller.getWorkerStats();
        expect(stats['individual_active'], 2);
        expect(stats['group_active'], 1);
        expect(stats['total_active'], 3);
        expect(stats['total_paused'], 0);

        // Pause some workers
        worker1.pause();
        worker2.pause(); // Now using worker2
        group.pauseAll();

        stats = controller.getWorkerStats();
        expect(stats['individual_active'], 0); // No individual workers active
        expect(
            stats['individual_paused'], 2); // Both worker1 and worker2 paused
        expect(stats['group_active'], 0);
        expect(stats['group_paused'], 1);
        expect(stats['total_active'], 0);
        expect(stats['total_paused'], 3);
      });

      test('app lifecycle automatically pauses and resumes workers', () async {
        final calls = <int>[];

        controller.ever(controller.count, (value) {
          calls.add(value);
        });

        // Normal execution
        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        expect(calls, [1]);

        // Simulate app going to background
        controller.onPause();

        // Should not execute while app is paused
        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [1]);

        // Simulate app coming back to foreground
        controller.onResume();

        // Should execute after app resumes
        controller.count.value = 3;
        await Future.delayed(Duration.zero);
        expect(calls, [1, 3]);
      });
    });

    group('Composable Workers', () {
      test('can combine multiple workers', () async {
        final calls = <String>[];

        // Create multiple workers for different observables
        final handle1 = controller.ever(controller.count, (value) {
          calls.add('count:$value');
        });

        final handle2 = controller.ever(controller.text, (value) {
          calls.add('text:$value');
        });

        // Combine them for easy disposal
        final combined = ZenWorkers.combine([handle1, handle2]);

        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        controller.text.value = 'hello';
        await Future.delayed(Duration.zero);

        expect(calls, ['count:1', 'text:hello']);

        // Dispose all at once
        combined.dispose();

        controller.count.value = 2;
        controller.text.value = 'world';
        await Future.delayed(Duration.zero);

        expect(calls, ['count:1', 'text:hello']); // No new calls
      });

      test('worker groups allow batch operations', () async {
        final calls = <String>[];

        final group = controller.createWorkerGroup();

        // Add workers to the group
        group.add(controller.ever(controller.count, (value) {
          calls.add('count:$value');
        }));

        group.add(controller.ever(controller.text, (value) {
          calls.add('text:$value');
        }));

        expect(group.length, 2);

        controller.count.value = 1;
        controller.text.value = 'test';
        await Future.delayed(Duration.zero);

        expect(calls, ['count:1', 'text:test']);

        // Dispose entire group
        group.dispose();
        expect(group.isDisposed, true);
        expect(group.length, 0);
      });
    });

    group('Error Handling', () {
      test('validates duration requirements', () {
        expect(
          () => controller.debounce(
              controller.count, (_) {}, const Duration(milliseconds: -1)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles callback errors gracefully', () async {
        final handle = controller.ever(controller.count, (value) {
          throw Exception('Test error');
        });

        // Should not crash the app
        controller.count.value = 1;
        await Future.delayed(Duration.zero);

        handle.dispose();
      });

      test('paused workers handle errors gracefully', () async {
        final handle = controller.ever(controller.count, (value) {
          throw Exception('Test error');
        });

        handle.pause();

        // Should not crash even when paused
        controller.count.value = 1;
        await Future.delayed(Duration.zero);

        handle.dispose();
      });
    });

    group('Effect Integration', () {
      test('can watch effect data', () async {
        final calls = <String?>[];

        final handle = controller.ever(controller.testEffect.data, (data) {
          calls.add(data);
        });

        expect(calls,
            []); // Changed from [null] - ever workers don't fire immediately

        await controller.runEffect('test');
        expect(calls, ['test']); // Changed from [null, 'test']

        await controller.runEffect('updated');
        expect(calls,
            ['test', 'updated']); // Changed from [null, 'test', 'updated']

        handle.dispose();
      });

      test('can watch effect loading state', () async {
        final calls = <bool>[];

        final handle =
            controller.ever(controller.testEffect.isLoading, (loading) {
          calls.add(loading);
        });

        expect(calls,
            []); // Changed from [false] - ever workers don't fire immediately

        final future = controller.runEffect('test');
        expect(calls, [true]); // Changed from [false, true]

        await future;
        expect(calls, [true, false]); // Changed from [false, true, false]

        handle.dispose();
      });

      test('effect workers can be paused and resumed', () async {
        final calls = <bool>[];

        final handle =
            controller.ever(controller.testEffect.isLoading, (loading) {
          calls.add(loading);
        });

        // Pause the worker
        handle.pause();

        // Effect should run but worker shouldn't respond
        await controller.runEffect('test');
        expect(calls, []); // No calls while paused

        // Resume worker
        handle.resume();

        // Now it should respond to changes
        await controller.runEffect('test2');
        expect(calls, [true, false]); // Loading start and end

        handle.dispose();
      });
    });

    group('Edge Cases', () {
      test('disposing paused worker works correctly', () {
        final handle = controller.ever(controller.count, (_) {});

        handle.pause();
        expect(handle.isPaused, true);

        handle.dispose();
        expect(handle.isDisposed, true);

        // Should not crash
        handle.pause();
        handle.resume();
      });

      test('resuming disposed worker is safe', () {
        final handle = controller.ever(controller.count, (_) {});

        handle.dispose();
        expect(handle.isDisposed, true);

        // Should not crash
        handle.resume();
        handle.pause();
      });

      test('multiple pause/resume calls are safe', () async {
        final calls = <int>[];
        final handle = controller.ever(controller.count, (value) {
          calls.add(value);
        });

        // Multiple pauses
        handle.pause();
        handle.pause();
        handle.pause();
        expect(handle.isPaused, true);

        controller.count.value = 1;
        await Future.delayed(Duration.zero);
        expect(calls, []);

        // Multiple resumes
        handle.resume();
        handle.resume();
        handle.resume();
        expect(handle.isPaused, false);

        controller.count.value = 2;
        await Future.delayed(Duration.zero);
        expect(calls, [2]);

        handle.dispose();
      });
    });
  });
}
