import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();
    // Mock lifecycle
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenStreamQuery Logic', () {
    test('initializes with correct default state', () {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
        autoSubscribe: false,
      );

      expect(query.status.value, ZenQueryStatus.idle);
      expect(query.data.value, isNull);
      expect(query.isLoading.value, false);
      expect(query.hasData, false);

      controller.close();
      query.dispose();
    });

    test('updates state on stream events', () async {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'test-stream',
        streamFn: () => controller.stream,
      );

      expect(query.status.value, ZenQueryStatus.loading);

      controller.add('event 1');
      await Future.delayed(Duration.zero);

      expect(query.data.value, 'event 1');
      expect(query.status.value, ZenQueryStatus.success);
      expect(query.isLoading.value, false);

      controller.close();
      query.dispose();
    });

    test('handles stream errors', () async {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'error-stream',
        streamFn: () => controller.stream,
      );

      controller.addError(Exception('Stream failed'));
      await Future.delayed(Duration.zero);

      expect(query.status.value, ZenQueryStatus.error);
      expect(query.hasError, true);
      expect(query.data.value, isNull);

      controller.close();
      query.dispose();
    });

    test('setData updates state manually (optimistic update)', () {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'optimistic-stream',
        streamFn: () => controller.stream,
        autoSubscribe: false,
      );

      query.setData('optimistic');

      expect(query.data.value, 'optimistic');
      expect(query.status.value, ZenQueryStatus.success);

      controller.close();
      query.dispose();
    });
  });
}
