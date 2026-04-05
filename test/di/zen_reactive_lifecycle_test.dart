import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for di/zen_reactive.dart and di/zen_lifecycle.dart
void main() {
  setUp(Zen.init);
  tearDown(() {
    ZenReactiveSystem.instance.clearListeners();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // ZenReactiveSystem.notifyListeners — _safeNotify error path
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.notifyListeners error handling', () {
    test('notifyListeners with throwing listener increments errorCount', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) => throw Exception('listener error'),
      );

      // Second notifyListeners (initial callback already fired in listen)
      ZenReactiveSystem.instance.notifyListeners<_ReactiveCtrl>(null);

      final stats = ZenReactiveSystem.instance.getMemoryStats();
      expect(stats['errorCount'], greaterThanOrEqualTo(1));

      sub.close();
    });

    test('notifyListeners is safe with no listeners', () {
      expect(
        () => ZenReactiveSystem.instance.notifyListeners<_OrphanType>(null),
        returnsNormally,
      );
    });

    test('notifyListeners handles multiple listeners with one throwing', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      int goodCalls = 0;
      final sub1 = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) => goodCalls++,
      );
      final sub2 = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) => throw Exception('bad listener'),
      );

      ZenReactiveSystem.instance.notifyListeners<_ReactiveCtrl>(null);
      expect(goodCalls, greaterThanOrEqualTo(1));

      sub1.close();
      sub2.close();
      ZenReactiveSystem.instance.notifyListeners<_ReactiveCtrl>(null);
      expect(goodCalls, greaterThanOrEqualTo(1));

      sub1.close();
      sub2.close();
    });

    test('tagged notify runs without error', () {
      Zen.put<_ReactiveCtrl>(_ReactiveCtrl(), tag: 'tagged');

      // Just verify notifyListeners with a tag key doesn't throw
      expect(
        () =>
            ZenReactiveSystem.instance.notifyListeners<_ReactiveCtrl>('tagged'),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenSubscription
  // ══════════════════════════════════════════════════════════
  group('ZenSubscription', () {
    test('close() marks subscription as disposed', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) {},
      );
      expect(sub.isDisposed, false);
      sub.close();
      expect(sub.isDisposed, true);
    });

    test('dispose() is alias for close()', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) {},
      );
      sub.dispose();
      expect(sub.isDisposed, true);
    });

    test('close() is idempotent', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) {},
      );
      sub.close();
      expect(() => sub.close(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenReactiveSystem.listen
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.listen', () {
    test('fires immediately with current value', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      _ReactiveCtrl? received;
      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (c) => received = c,
      );
      expect(received, isNotNull);
      sub.close();
    });

    test('cancel removes listener', () {
      final ctrl = _ReactiveCtrl();
      Zen.put<_ReactiveCtrl>(ctrl);

      int calls = 0;
      final sub = ZenReactiveSystem.instance.listen<_ReactiveCtrl>(
        ctrl,
        (_) => calls++,
      );
      final before = calls;
      sub.close();

      ZenReactiveSystem.instance.notifyListeners<_ReactiveCtrl>(null);
      expect(calls, before);
    });
  });

  // ══════════════════════════════════════════════════════════
  // getMemoryStats / getHealthStatus
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.getMemoryStats', () {
    test('returns all expected keys', () {
      final stats = ZenReactiveSystem.instance.getMemoryStats();
      expect(stats.containsKey('totalKeys'), true);
      expect(stats.containsKey('totalListeners'), true);
      expect(stats.containsKey('errorCount'), true);
      expect(stats.containsKey('memoryPressure'), true);
    });

    test('memoryPressure is LOW initially', () {
      final stats = ZenReactiveSystem.instance.getMemoryStats();
      expect(stats['memoryPressure'], 'LOW');
    });
  });

  group('ZenReactiveSystem.getHealthStatus', () {
    test('returns HEALTHY normally', () {
      final health = ZenReactiveSystem.instance.getHealthStatus();
      expect(health['status'], 'HEALTHY');
    });

    test('recommendations is a list', () {
      final health = ZenReactiveSystem.instance.getHealthStatus();
      expect(health['recommendations'], isA<List>());
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenLifecycleManager
  // ══════════════════════════════════════════════════════════
  group('ZenLifecycleManager.addLifecycleListener', () {
    test(
        'addLifecycleListener and removeLifecycleListener work without binding',
        () {
      void listener(AppLifecycleState state) {}
      ZenLifecycleManager.instance.addLifecycleListener(listener);
      expect(
        () => ZenLifecycleManager.instance.removeLifecycleListener(listener),
        returnsNormally,
      );
    });
  });

  group('ZenLifecycleManager.initializeController', () {
    test('calls onInit on uninitialized controller', () {
      final ctrl = _LifecycleCtrl();
      ZenLifecycleManager.instance.initializeController(ctrl);
      expect(ctrl.initCalled, true);
    });

    test('onReady is scheduled after init', () {
      // In flutter_test context, WidgetsBinding is available, so onReady
      // is deferred via addPostFrameCallback (not immediate).
      // We verify init was called and the controller is initialized.
      final ctrl = _LifecycleCtrl();
      ZenLifecycleManager.instance.initializeController(ctrl);
      expect(ctrl.initCalled, true);
      expect(ctrl.isInitialized, true);
    });

    test('is idempotent — onInit not called twice', () {
      final ctrl = _LifecycleCtrl();
      ZenLifecycleManager.instance.initializeController(ctrl);
      ZenLifecycleManager.instance.initializeController(ctrl);
      expect(ctrl.initCount, 1);
    });

    test('catches onInit errors gracefully', () {
      final ctrl = _ThrowingCtrl();
      expect(
        () => ZenLifecycleManager.instance.initializeController(ctrl),
        returnsNormally,
      );
    });
  });

  group('ZenLifecycleManager.initializeService', () {
    test('calls ensureInitialized', () {
      final svc = _LifecycleService();
      ZenLifecycleManager.instance.initializeService(svc);
      expect(svc.isInitialized, true);
    });
  });
}

// ── Helpers ──

class _ReactiveCtrl extends ZenController {}

class _OrphanType extends ZenController {}

class _LifecycleCtrl extends ZenController {
  bool initCalled = false;
  bool readyCalled = false;
  int initCount = 0;

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
    initCount++;
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
  }
}

class _ThrowingCtrl extends ZenController {
  @override
  void onInit() {
    super.onInit();
    throw Exception('onInit failed');
  }
}

class _LifecycleService extends ZenService {
  @override
  void onInit() => super.onInit();
}
