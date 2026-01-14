import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  late List<String> logs;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();

    // Mock lifecycle and timers
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);

    // Ensure the lifecycle observer is attached for these tests
    ZenLifecycleManager.instance.initLifecycleObserver();

    // Capture logs to verify debug output
    logs = [];
    ZenLogger.init(logHandler: (msg, level) {
      logs.add(msg);
    });
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

  group('ZenStreamQuery Lifecycle', () {
    test('pauses stream subscription on AppLifecycleState.paused', () async {
      bool isPaused = false;
      final controller = StreamController<String>(
        onPause: () => isPaused = true,
        onResume: () => isPaused = false,
      );

      final query = ZenStreamQuery<String>(
        queryKey: 'lifecycle-test',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(
          autoPauseOnBackground: true, // Opt-in to auto-pause
        ),
      );

      // Wait for subscription
      await Future.delayed(Duration.zero);
      expect(isPaused, false);

      // Trigger pause via Flutter binding
      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future.delayed(Duration.zero);

      expect(isPaused, true,
          reason: 'Stream should be paused when app is paused');
      expect(
          logs.any(
              (l) => l.contains('Controller ZenStreamQuery<String> paused')),
          true,
          reason: 'Should log pause event');

      controller.close();
      query.dispose();
    });

    test('resumes stream subscription on AppLifecycleState.resumed', () async {
      bool isPaused = false;
      final controller = StreamController<String>(
        onPause: () => isPaused = true,
        onResume: () => isPaused = false,
      );

      final query = ZenStreamQuery<String>(
        queryKey: 'lifecycle-resume-test',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(
          autoPauseOnBackground: true, // Opt-in to auto-pause
        ),
      );

      // Start paused
      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future.delayed(Duration.zero);
      expect(isPaused, true);

      // Resume
      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future.delayed(Duration.zero);
      expect(isPaused, false,
          reason: 'Stream should be resumed when app resumes');

      controller.close();
      query.dispose();
    });

    test('pauses stream on AppLifecycleState.inactive (Web behavior)',
        () async {
      bool isPaused = false;
      final controller = StreamController<String>(
        onPause: () => isPaused = true,
        onResume: () => isPaused = false,
      );

      final query = ZenStreamQuery<String>(
        queryKey: 'lifecycle-inactive-test',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(
          autoPauseOnBackground: true, // Opt-in to auto-pause
        ),
      );

      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future.delayed(Duration.zero);

      expect(isPaused, true,
          reason: 'Stream should pause on inactive state (Web tab switch)');
      expect(
          logs.any((l) =>
              l.contains('StreamQuery lifecycle-inactive-test inactive')),
          true,
          reason: 'Should explicitly log inactive state');

      controller.close();
      query.dispose();
    });

    test('pauses stream on AppLifecycleState.hidden (Web/Desktop behavior)',
        () async {
      bool isPaused = false;
      final controller = StreamController<String>(
        onPause: () => isPaused = true,
        onResume: () => isPaused = false,
      );

      final query = ZenStreamQuery<String>(
        queryKey: 'lifecycle-hidden-test',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(
          autoPauseOnBackground: true, // Opt-in to auto-pause
        ),
      );

      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await Future.delayed(Duration.zero);

      expect(isPaused, true, reason: 'Stream should pause on hidden state');
      expect(
          logs.any(
              (l) => l.contains('StreamQuery lifecycle-hidden-test hidden')),
          true,
          reason: 'Should explicitly log hidden state');

      controller.close();
      query.dispose();
    });

    test('does NOT pause when enableBackgroundRefetch is true', () async {
      bool isPaused = false;
      final controller = StreamController<String>(
        onPause: () => isPaused = true,
        onResume: () => isPaused = false,
      );

      final query = ZenStreamQuery<String>(
        queryKey: 'background-test',
        streamFn: () => controller.stream,
        config: const ZenQueryConfig(enableBackgroundRefetch: true),
      );

      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future.delayed(Duration.zero);

      expect(isPaused, false,
          reason: 'Stream should stay active in background when configured');

      controller.close();
      query.dispose();
    });
  });
}
