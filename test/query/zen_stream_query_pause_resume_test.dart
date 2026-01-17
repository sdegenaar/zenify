import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenStreamQuery Pause/Resume', () {
    test('manual pause() stops receiving events', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Emit events
      controller.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 1);

      // Pause
      query.pause();

      // Emit more events - should not be received while paused
      controller.add(2);
      controller.add(3);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 1,
          reason: 'Should not receive events while paused');

      controller.close();
      query.dispose();
    });

    test('manual resume() continues receiving events', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Pause immediately
      query.pause();

      // Emit events - should not be received
      controller.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, null);

      // Resume
      query.resume();

      // Emit more events - should be received
      controller.add(2);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 2);

      controller.close();
      query.dispose();
    });

    test('pause() is idempotent', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Multiple pause calls should be safe
      query.pause();
      query.pause();
      query.pause();

      // Should still work
      query.resume();

      controller.close();
      query.dispose();
    });

    test('resume() is idempotent', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      query.pause();

      // Multiple resume calls should be safe
      query.resume();
      query.resume();
      query.resume();

      controller.close();
      query.dispose();
    });

    test('autoPauseOnBackground defaults to false', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Should default to false (opt-in)
      expect(query.config.autoPauseOnBackground, false);

      controller.close();
      query.dispose();
    });

    test('autoPauseOnBackground: true can be enabled', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(
          autoPauseOnBackground: true, // Opt-in
        ),
      );

      expect(query.config.autoPauseOnBackground, true);

      controller.close();
      query.dispose();
    });

    test('pause() before subscription does nothing', () {
      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => Stream.value(1),
        autoSubscribe: false, // Don't auto-subscribe
      );

      // Should not crash
      query.pause();

      query.dispose();
    });

    test('resume() before subscription does nothing', () {
      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => Stream.value(1),
        autoSubscribe: false,
      );

      // Should not crash
      query.resume();

      query.dispose();
    });

    test('multiple pause/resume cycles work correctly', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Cycle 1: Active
      controller.add(1);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 1);

      // Cycle 2: Paused
      query.pause();
      controller.add(2);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 1); // Should not receive 2

      // Cycle 3: Resumed
      query.resume();
      controller.add(3);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 3); // Should receive 3 (2 was missed)

      // Cycle 4: Paused again
      query.pause();
      controller.add(4);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 3); // Should not receive 4

      // Cycle 5: Resumed again
      query.resume();
      controller.add(5);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 5); // Should receive 5

      controller.close();
      query.dispose();
    });

    test('dispose while paused cleans up correctly', () async {
      final controller = StreamController<int>();

      final query = ZenStreamQuery<int>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      query.pause();
      query.dispose();

      expect(query.isDisposed, true);

      controller.close();
    });

    test('pause/resume preserves data', () async {
      final controller = StreamController<String>();

      final query = ZenStreamQuery<String>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      // Receive initial data
      controller.add('initial');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 'initial');

      // Pause
      query.pause();
      expect(query.data.value, 'initial', reason: 'Data should be preserved');

      // Resume
      query.resume();
      expect(query.data.value, 'initial',
          reason: 'Data should still be preserved');

      // Receive new data
      controller.add('updated');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(query.data.value, 'updated');

      controller.close();
      query.dispose();
    });
  });
}
